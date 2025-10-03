#include "databasemanager.h"
#include <QFile>
#include <QRegularExpression>
#include <QSqlRecord>
// Pricing JSON & containers
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QtConcurrent/QtConcurrent>
#include <QThread>
#include <QMetaType>
#include <QRandomGenerator>
#include <algorithm>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTextStream>
#include <QPainter>
#include <QPageSize>
#include <QFont>
#include <QFontMetrics>
#include <QUrl>
#include <QStringConverter>
#if QT_CONFIG(pdf)
#include <QPdfWriter>
#endif

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent)
{
    DB_Connection = QSqlDatabase::addDatabase("QSQLITE");
    const QString dbPath = QCoreApplication::applicationDirPath() + "/../../database/parking.db";
    dbFilePath_ = dbPath;
    qDebug() << "[DB] Expected database path:" << dbPath;
    {
        QFileInfo fi(dbPath);
        QDir dir(fi.path());
        if (!dir.exists())
            dir.mkpath(".");
    }
    DB_Connection.setDatabaseName(dbPath);
    if (DB_Connection.open())
    {
        qDebug() << "Database Is Connected";
        // Improve concurrency to reduce UI stalls from reads vs writes
        QSqlQuery prag(DB_Connection);
        prag.exec("PRAGMA journal_mode=WAL");
        prag.exec("PRAGMA synchronous=NORMAL");
    }
    else
    {
        qDebug() << "Database Is Not Connected";
        qDebug() << "Error : " << DB_Connection.lastError();
    }
}

bool DatabaseManager::initialize()
{
    if (!DB_Connection.isOpen() && !DB_Connection.open())
    {
        qWarning() << "Không thể mở cơ sở dữ liệu:" << DB_Connection.lastError().text();
        return false;
    }
    qDebug() << "[DB] initialize() using file:" << DB_Connection.databaseName();
    const bool ok = ensureSchema();
    if (ok)
    {
        // Defensive: ensure new indexes added in future versions are present (idempotent)
        QSqlQuery qi(DB_Connection);
        qi.exec("CREATE INDEX IF NOT EXISTS idx_users_fullname ON users(full_name)");
        qi.exec("CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)");
        qi.exec("CREATE INDEX IF NOT EXISTS idx_users_plate ON users(plate)");
        qi.exec("CREATE INDEX IF NOT EXISTS idx_subs_status ON subscriptions(status)");
        qi.exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_subs_active_user_plate ON subscriptions(user_id, plate) WHERE status='active' AND plate IS NOT NULL");
        qi.exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_subs_active_user_rfid ON subscriptions(user_id, rfid) WHERE status='active' AND rfid IS NOT NULL");
        qi.exec("CREATE INDEX IF NOT EXISTS idx_rfid_cards_user_phone ON rfid_cards(user_phone)");
    }
    return ok;
}

bool DatabaseManager::ensureSchema()
{
    QSqlQuery q(DB_Connection);
    // Ensure SQLite enforces foreign keys
    q.exec("PRAGMA foreign_keys=ON");
    DB_Connection.transaction();
    // 1) users
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            phone TEXT NOT NULL UNIQUE,
            rfid TEXT UNIQUE,
            plate TEXT UNIQUE,
            vehicle_type TEXT NOT NULL,
            created_at TEXT,
            status TEXT DEFAULT 'active'
        )
    )"))
    {
        qWarning() << "DDL users:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    // Helpful lookup indexes for users (name filtering & active plates)
    q.exec("CREATE INDEX IF NOT EXISTS idx_users_fullname ON users(full_name)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_users_plate ON users(plate)");

    // 2) parking_sessions (pricing_id NOT NULL; user_id nullable; FKs: user ON DELETE SET NULL)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS parking_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            pricing_id INTEGER NOT NULL,
            rfid TEXT,
            plate TEXT,
            checkin_time TEXT NOT NULL,
            checkout_time TEXT,
            checkin_image1 BLOB,
            checkin_image2 BLOB,
            checkout_image1 BLOB,
            checkout_image2 BLOB,
            duration_minutes INTEGER,
            fee INTEGER,
            status TEXT CHECK (status IN ('checked_in','checked_out','pending')),
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
            FOREIGN KEY(pricing_id) REFERENCES pricing(id) ON DELETE RESTRICT,
            FOREIGN KEY (rfid) REFERENCES rfid_cards(rfid) ON DELETE SET NULL
        )
    )"))
    {
        qWarning() << "DDL parking_sessions:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }

    // Note: legacy table 'parking_log' migration removed as not used in app

    // Legacy DBs may have parking_sessions without user_id/pricing_id. Add columns if missing, then backfill.
    auto columnExists = [&](const QString &table, const QString &column) -> bool
    {
        QSqlQuery qi(DB_Connection);
        if (!qi.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table)))
            return false;
        while (qi.next())
        {
            if (qi.value(1).toString() == column)
                return true;
        }
        return false;
    };
    const bool hasUserIdCol = columnExists("parking_sessions", "user_id");
    const bool hasPricingIdCol = columnExists("parking_sessions", "pricing_id");
    if (!hasUserIdCol)
    {
        // Add as nullable first for existing rows, we'll backfill right after.
        q.exec("ALTER TABLE parking_sessions ADD COLUMN user_id INTEGER");
    }
    if (!hasPricingIdCol)
    {
        q.exec("ALTER TABLE parking_sessions ADD COLUMN pricing_id INTEGER");
    }

    // Create helpful indexes (safe if columns were just added; creation will be skipped if not possible)
    if (!hasUserIdCol)
        q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_user ON parking_sessions(user_id)");
    if (!hasPricingIdCol)
        q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_pricing ON parking_sessions(pricing_id)");

    // Indexes cho truy vấn nhanh
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_rfid_open ON parking_sessions(rfid, checkout_time)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_plate ON parking_sessions(plate)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_time ON parking_sessions(checkin_time, checkout_time)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_status ON parking_sessions(status)");

    // Migrate: add checkout images columns if missing (ignore errors if already exist)
    q.exec("ALTER TABLE parking_sessions ADD COLUMN checkout_image1 BLOB");
    q.exec("ALTER TABLE parking_sessions ADD COLUMN checkout_image2 BLOB");

    // 3) pricing (new normalized schema)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS pricing (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('car','bike','truck')),
            ticket_type TEXT NOT NULL CHECK (ticket_type IN ('hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly')),
            base_fee INTEGER NOT NULL,
            duration_minutes INTEGER,
            incremental_fee INTEGER,
            max_daily_fee INTEGER,
            discount_percentage REAL DEFAULT 0,
            grace_period INTEGER DEFAULT 0,
            description TEXT,
            start_time TEXT,
            end_time TEXT
        )
    )"))
    {
        qWarning() << "DDL pricing:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    q.exec("CREATE INDEX IF NOT EXISTS idx_pricing_vt_tt ON pricing(vehicle_type, ticket_type)");
    // Ensure vehicle_type+ticket_type unique for FK reference from rfid_cards
    q.exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_pricing_vt_tt ON pricing(vehicle_type, ticket_type)");

    // 4) subscriptions (link pricing_id)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            pricing_id INTEGER NOT NULL,
            plate TEXT,
            rfid TEXT,
            plan_type TEXT NOT NULL CHECK (plan_type IN ('monthly','quarterly','yearly')),
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            payment_mode TEXT NOT NULL CHECK (payment_mode IN ('prepaid','postpaid')),
            price INTEGER NOT NULL,
            status TEXT DEFAULT 'active' CHECK (status IN ('active','expired','canceled')),
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(pricing_id) REFERENCES pricing(id) ON DELETE CASCADE,
            FOREIGN KEY(rfid) REFERENCES rfid_cards(rfid) ON DELETE SET NULL
        )
    )"))
    {
        qWarning() << "DDL subscriptions:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    q.exec("CREATE INDEX IF NOT EXISTS idx_subs_user ON subscriptions(user_id)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_subs_dates ON subscriptions(start_date, end_date)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_subs_plate_rfid ON subscriptions(plate, rfid)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_subs_status ON subscriptions(status)");
    // Enforce at most one active overlapping subscription per user + (plate or rfid)
    q.exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_subs_active_user_plate ON subscriptions(user_id, plate) WHERE status='active' AND plate IS NOT NULL");
    q.exec("CREATE UNIQUE INDEX IF NOT EXISTS uq_subs_active_user_rfid ON subscriptions(user_id, rfid) WHERE status='active' AND rfid IS NOT NULL");

    // 5) revenues (link pricing_id and stricter enums)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS revenues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER,
            subscription_id INTEGER,
            user_id INTEGER,
            pricing_id INTEGER,
            amount INTEGER NOT NULL,
            payment_type TEXT NOT NULL CHECK (payment_type IN ('cash','card','transfer','prepaid','postpaid')),
            revenue_type TEXT NOT NULL CHECK (revenue_type IN ('parking_session','subscription','other')),
            created_at TEXT,
            note TEXT,
            FOREIGN KEY(session_id) REFERENCES parking_sessions(id) ON DELETE SET NULL,
            FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
            FOREIGN KEY(pricing_id) REFERENCES pricing(id) ON DELETE SET NULL
        )
    )"))
    {
        qWarning() << "DDL revenues:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    q.exec("CREATE INDEX IF NOT EXISTS idx_rev_dates ON revenues(created_at)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_rev_types ON revenues(revenue_type, payment_type)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_rev_user ON revenues(user_id)");
    // Helpful for ticket-type aggregation and faster range + join
    q.exec("CREATE INDEX IF NOT EXISTS idx_rev_pricing ON revenues(pricing_id)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_rev_created_pricing ON revenues(created_at, pricing_id)");

    DB_Connection.commit();
    // Create rfid_cards table and triggers outside the above transaction to avoid interfering with existing DB creation
    {
        QSqlQuery qr(DB_Connection);
        if (!qr.exec(R"(
            CREATE TABLE IF NOT EXISTS rfid_cards (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                rfid TEXT NOT NULL UNIQUE,
                vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('car','bike')),
                ticket_type TEXT NOT NULL CHECK (ticket_type IN ('hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly')),
                user_phone TEXT,
                status TEXT NOT NULL CHECK (status IN ('available','assigned','lost','damaged')),
                created_at TEXT NOT NULL,
                assigned_at TEXT,
                description TEXT,
                FOREIGN KEY (user_phone) REFERENCES users(phone) ON UPDATE CASCADE ON DELETE SET NULL,
                FOREIGN KEY (vehicle_type, ticket_type) REFERENCES pricing(vehicle_type, ticket_type) ON UPDATE CASCADE ON DELETE RESTRICT
            )
        )"))
        {
            qWarning() << "DDL rfid_cards:" << qr.lastError().text();
        }
        qr.exec("CREATE INDEX IF NOT EXISTS idx_rfid_cards_status ON rfid_cards(status)");
        qr.exec("CREATE INDEX IF NOT EXISTS idx_rfid_cards_vt_tt ON rfid_cards(vehicle_type, ticket_type)");
        qr.exec("CREATE INDEX IF NOT EXISTS idx_rfid_cards_user_phone ON rfid_cards(user_phone)");

        // Triggers to enforce rfid in users/subscriptions/parking_sessions must exist in rfid_cards if not NULL
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_users_rfid_fk_ins
            BEFORE INSERT ON users FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_users_rfid_fk_upd
            BEFORE UPDATE OF rfid ON users FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_subs_rfid_fk_ins
            BEFORE INSERT ON subscriptions FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_subs_rfid_fk_upd
            BEFORE UPDATE OF rfid ON subscriptions FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_sessions_rfid_fk_ins
            BEFORE INSERT ON parking_sessions FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
        qr.exec(R"(
            CREATE TRIGGER IF NOT EXISTS trg_sessions_rfid_fk_upd
            BEFORE UPDATE OF rfid ON parking_sessions FOR EACH ROW
            WHEN NEW.rfid IS NOT NULL AND NEW.rfid <> '' AND NOT EXISTS (
                SELECT 1 FROM rfid_cards rc WHERE rc.rfid = NEW.rfid AND rc.status NOT IN ('lost','damaged')
            )
            BEGIN
                SELECT RAISE(ABORT, 'RFID invalid or not found in rfid_cards');
            END;
        )");
    }
    // 6. Employee
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            phone TEXT UNIQUE,
            role TEXT,
            created_at TEXT
        )
    )"))
    {
        qWarning() << "DDL employees:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }

    // Seed default pricing if table is empty
    ensureDefaultPricing();

    // Backfill legacy columns just added (outside of transaction to avoid long locks)
    // No longer force a default Guest user; leave user_id as NULL when unknown.

    // If an older DB has NULL pricing_id in parking_sessions, migrate/backfill it now
    migrateParkingSessionsPricingNotNull();
    return true;
}

QList<QVariantMap> DatabaseManager::listEmployees()
{
    QList<QVariantMap> out;
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT id, full_name, phone, role FROM employees ORDER BY id DESC");
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("id", q.value(0));
            m.insert("full_name", q.value(1));
            m.insert("phone", q.value(2));
            m.insert("role", q.value(3));
            out.append(m);
        }
    }
    else
    {
        qWarning() << "listEmployees:" << q.lastError().text();
    }
    return out;
}

bool DatabaseManager::addEmployee(const QString &fullName, const QString &phone, const QString &role)
{
    QSqlQuery q(DB_Connection);
    q.prepare("INSERT INTO employees (full_name, phone, role, created_at) VALUES (:name, :phone, :role, :created)");
    q.bindValue(":name", fullName);
    q.bindValue(":phone", phone);
    q.bindValue(":role", role);
    q.bindValue(":created", nowIso8601());
    if (!q.exec())
    {
        qWarning() << "addEmployee:" << q.lastError().text();
        return false;
    }
    return true;
}

bool DatabaseManager::updateEmployee(int id, const QString &fullName, const QString &phone, const QString &role)
{
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE employees SET full_name = :name, phone = :phone, role = :role WHERE id = :id");
    q.bindValue(":name", fullName);
    q.bindValue(":phone", phone);
    q.bindValue(":role", role);
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "updateEmployee:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}
bool DatabaseManager::deleteEmployee(int id)
{
    QSqlQuery q(DB_Connection);
    q.prepare("DELETE FROM employees WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "deleteEmployee:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool DatabaseManager::ensureDefaultPricing()
{
    QSqlQuery q(DB_Connection);
    if (q.exec("SELECT COUNT(1) FROM pricing") && q.next() && q.value(0).toInt() > 0)
        return true;
    // Insert the provided defaults
    const char *sql = R"SQL(
INSERT INTO pricing (vehicle_type, ticket_type, base_fee, duration_minutes, incremental_fee, max_daily_fee, discount_percentage, grace_period, description, start_time, end_time) VALUES
('bike','hourly',5000,60,5000,30000,0,15,'Phí giờ xe máy',NULL,NULL),
('bike','daily_day',20000,720,NULL,30000,0,15,'Vé ngày ban ngày xe máy','06:00','18:00'),
('bike','daily_night',25000,720,NULL,40000,0,15,'Vé ngày ban đêm xe máy','18:00','06:00'),
('bike','overnight',30000,NULL,NULL,NULL,0,0,'Vé qua đêm xe máy','18:00','06:00'),
('bike','monthly',200000,NULL,NULL,NULL,0,0,'Vé tháng xe máy',NULL,NULL),
('bike','quarterly',540000,NULL,NULL,NULL,10,0,'Vé quý xe máy',NULL,NULL),
('bike','yearly',1920000,NULL,NULL,NULL,20,0,'Vé năm xe máy',NULL,NULL),
('car','hourly',20000,60,20000,240000,0,15,'Phí giờ ô tô',NULL,NULL),
('car','daily_day',150000,720,NULL,240000,0,15,'Vé ngày ban ngày ô tô','06:00','18:00'),
('car','daily_night',180000,720,NULL,300000,0,15,'Vé ngày ban đêm ô tô','18:00','06:00'),
('car','overnight',120000,NULL,NULL,NULL,0,0,'Vé qua đêm ô tô','18:00','06:00'),
('car','monthly',1500000,NULL,NULL,NULL,0,0,'Vé tháng ô tô',NULL,NULL),
('car','quarterly',4050000,NULL,NULL,NULL,10,0,'Vé quý ô tô',NULL,NULL),
('car','yearly',14400000,NULL,NULL,NULL,20,0,'Vé năm ô tô',NULL,NULL);
)SQL";
    if (!q.exec(sql))
        qWarning() << "Seed pricing failed:" << q.lastError().text();
    return true;
}

bool DatabaseManager::upsertRfidCard(const QString &rfid,
                                     const QString &vehicleType,
                                     const QString &ticketType,
                                     const QString &status,
                                     const QString &description)
{
    if (rfid.trimmed().isEmpty())
        return false;
    const QString vt = normalizeVehicle(vehicleType);
    QSqlQuery q(DB_Connection);
    // Try update first
    q.prepare(R"(
        UPDATE rfid_cards
        SET vehicle_type=:vt, ticket_type=:tt, status=:st, description=:desc
        WHERE rfid=:rfid
    )");
    q.bindValue(":vt", vt);
    q.bindValue(":tt", ticketType);
    q.bindValue(":st", status);
    q.bindValue(":desc", description);
    q.bindValue(":rfid", rfid);
    if (!q.exec())
    {
        qWarning() << "upsertRfidCard update:" << q.lastError().text();
        return false;
    }
    if (q.numRowsAffected() > 0)
        return true;

    // Insert
    QSqlQuery qi(DB_Connection);
    qi.prepare(R"(
        INSERT INTO rfid_cards (rfid, vehicle_type, ticket_type, user_phone, status, created_at, assigned_at, description)
        VALUES (:rfid, :vt, :tt, NULL, :st, :created, NULL, :desc)
    )");
    qi.bindValue(":rfid", rfid);
    qi.bindValue(":vt", vt);
    qi.bindValue(":tt", ticketType);
    qi.bindValue(":st", status.isEmpty() ? QStringLiteral("available") : status);
    qi.bindValue(":created", nowIso8601());
    qi.bindValue(":desc", description);
    if (!qi.exec())
    {
        qWarning() << "upsertRfidCard insert:" << qi.lastError().text();
        return false;
    }
    return true;
}

bool DatabaseManager::assignRfidCard(const QString &rfid, int userId)
{
    if (rfid.trimmed().isEmpty() || userId <= 0)
        return false;
    QSqlQuery q(DB_Connection);
    // Ensure card exists
    q.prepare("SELECT id FROM rfid_cards WHERE rfid=:rfid");
    q.bindValue(":rfid", rfid);
    if (!q.exec() || !q.next())
        return false;
    // Set unique in users: clear any other user with same rfid, then set
    QSqlQuery qu(DB_Connection);
    qu.prepare("UPDATE users SET rfid=NULL WHERE rfid=:rfid");
    qu.bindValue(":rfid", rfid);
    qu.exec();
    qu.prepare("UPDATE users SET rfid=:rfid WHERE id=:uid");
    qu.bindValue(":rfid", rfid);
    qu.bindValue(":uid", userId);
    if (!qu.exec())
    {
        qWarning() << "assignRfidCard users:" << qu.lastError().text();
        return false;
    }
    // Fetch user's phone; card will store user_phone instead of user_id
    QString userPhone;
    {
        QSqlQuery qp(DB_Connection);
        qp.prepare("SELECT phone FROM users WHERE id=:uid LIMIT 1");
        qp.bindValue(":uid", userId);
        if (qp.exec() && qp.next())
            userPhone = qp.value(0).toString();
    }
    if (userPhone.isEmpty())
    {
        qWarning() << "assignRfidCard: user has no phone, cannot link by phone";
        return false;
    }
    // Update card
    QSqlQuery qc(DB_Connection);
    qc.prepare(R"(
        UPDATE rfid_cards SET user_phone=:up, status='assigned', assigned_at=:ts WHERE rfid=:rfid
    )");
    qc.bindValue(":up", userPhone.isEmpty() ? QVariant() : QVariant(userPhone));
    qc.bindValue(":ts", nowIso8601());
    qc.bindValue(":rfid", rfid);
    if (!qc.exec())
    {
        qWarning() << "assignRfidCard card:" << qc.lastError().text();
        return false;
    }
    return qc.numRowsAffected() > 0;
}

bool DatabaseManager::unassignRfidCard(const QString &rfid)
{
    if (rfid.trimmed().isEmpty())
        return false;
    QSqlQuery qu(DB_Connection);
    qu.prepare("UPDATE users SET rfid=NULL WHERE rfid=:rfid");
    qu.bindValue(":rfid", rfid);
    qu.exec();
    QSqlQuery qc(DB_Connection);
    qc.prepare("UPDATE rfid_cards SET user_phone=NULL, status='available' WHERE rfid=:rfid");
    qc.bindValue(":rfid", rfid);
    if (!qc.exec())
    {
        qWarning() << "unassignRfidCard:" << qc.lastError().text();
        return false;
    }
    return qc.numRowsAffected() > 0;
}

QList<QVariantMap> DatabaseManager::listRfidCards(const QString &status,
                                                  const QString &vehicleType,
                                                  const QString &ticketType,
                                                  int limit,
                                                  int offset)
{
    QList<QVariantMap> out;
    QString sql = "SELECT id, rfid, vehicle_type, ticket_type, user_phone, status, created_at, assigned_at, description FROM rfid_cards WHERE 1=1";
    if (!status.isEmpty())
        sql += " AND status = :st";
    if (!vehicleType.isEmpty())
        sql += " AND vehicle_type = :vt";
    if (!ticketType.isEmpty())
        sql += " AND ticket_type = :tt";
    sql += " ORDER BY id DESC LIMIT :limit OFFSET :offset";
    QSqlQuery q(DB_Connection);
    q.prepare(sql);
    if (!status.isEmpty())
        q.bindValue(":st", status);
    if (!vehicleType.isEmpty())
        q.bindValue(":vt", normalizeVehicle(vehicleType));
    if (!ticketType.isEmpty())
        q.bindValue(":tt", ticketType);
    q.bindValue(":limit", limit);
    q.bindValue(":offset", offset);
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("id", q.value("id"));
            m.insert("rfid", q.value("rfid"));
            m.insert("vehicle_type", q.value("vehicle_type"));
            m.insert("ticket_type", q.value("ticket_type"));
            m.insert("user_phone", q.value("user_phone"));
            m.insert("status", q.value("status"));
            m.insert("created_at", q.value("created_at"));
            m.insert("assigned_at", q.value("assigned_at"));
            m.insert("description", q.value("description"));
            out.append(m);
        }
    }
    else
    {
        qWarning() << "listRfidCards:" << q.lastError().text();
    }
    return out;
}

static QSqlDatabase openThreadDb(const QString &filePath)
{
    // Unique connection name per thread
    const QString cn = QStringLiteral("db_async_%1").arg((qulonglong)QThread::currentThreadId());
    if (QSqlDatabase::contains(cn))
        QSqlDatabase::removeDatabase(cn);
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", cn);
    db.setDatabaseName(filePath);
    db.open();
    QSqlQuery prag(db);
    prag.exec("PRAGMA journal_mode=WAL");
    prag.exec("PRAGMA synchronous=NORMAL");
    return db;
}

void DatabaseManager::getDashboardStatsAsync(const QString &todayIso)
{
    const QString path = dbFilePath_;
    auto fut = QtConcurrent::run([this, todayIso, path]()
                                 {
        QVariantMap stats;
        QSqlDatabase db = openThreadDb(path);
        // Compute day bounds
        const QDate d = QDate::fromString(todayIso, Qt::ISODate);
        const QString dayStart = QDateTime(d, QTime(0,0,0)).toString(Qt::ISODate);
        const QString nextStart = QDateTime(d.addDays(1), QTime(0,0,0)).toString(Qt::ISODate);
        QSqlQuery q(db);
        q.prepare(R"(SELECT 
            (SELECT COUNT(1) FROM parking_sessions WHERE checkin_time >= :ds AND checkin_time < :dn) AS in_total,
            (SELECT COUNT(1) FROM parking_sessions WHERE checkout_time >= :ds AND checkout_time < :dn) AS out_total,
            (SELECT IFNULL(SUM(amount),0) FROM revenues WHERE created_at >= :ds AND created_at < :dn) AS revenue_total,
            (SELECT COUNT(1) FROM subscriptions WHERE status='expired') AS expired_subs
        )");
        q.bindValue(":ds", dayStart);
        q.bindValue(":dn", nextStart);
        if (q.exec() && q.next()) {
            stats.insert("in_today", q.value(0));
            stats.insert("out_today", q.value(1));
            stats.insert("revenue_today", q.value(2));
            stats.insert("expired_subscriptions", q.value(3));
        }
    emit dashboardStatsReady(todayIso, stats);
    db.close(); });
}

void DatabaseManager::listRevenueSummaryAsync(const QString &fromIso,
                                              const QString &toIso,
                                              const QString &typeFilter)
{
    const QString path = dbFilePath_;
    auto fut = QtConcurrent::run([this, fromIso, toIso, typeFilter, path]()
                                 {
        QList<QVariantMap> out;
        QSqlDatabase db = openThreadDb(path);
        QString sql = R"(SELECT DATE(created_at) AS d,
            SUM(CASE WHEN revenue_type='parking_session' THEN 1 ELSE 0 END) AS session_count,
            SUM(CASE WHEN revenue_type='subscription' THEN 1 ELSE 0 END) AS subscription_count,
            SUM(amount) AS total_amount
            FROM revenues
            WHERE created_at >= :fs AND created_at < :tn
        )";
        if (!typeFilter.isEmpty() && typeFilter != "all")
            sql += QStringLiteral(" AND revenue_type=:rt");
        sql += QStringLiteral(" GROUP BY d ORDER BY d DESC LIMIT 180");
        QSqlQuery q(db);
        q.prepare(sql);
        const QDate df = QDate::fromString(fromIso, Qt::ISODate);
        const QDate dt = QDate::fromString(toIso, Qt::ISODate);
        const QString fromStart = QDateTime(df, QTime(0,0,0)).toString(Qt::ISODate);
        const QString toNext = QDateTime(dt.addDays(1), QTime(0,0,0)).toString(Qt::ISODate);
        q.bindValue(":fs", fromStart);
        q.bindValue(":tn", toNext);
        if (!typeFilter.isEmpty() && typeFilter != "all")
            q.bindValue(":rt", typeFilter);
        if (q.exec()) {
            while (q.next()) {
                QVariantMap m; m.insert("d", q.value(0)); m.insert("session_count", q.value(1)); m.insert("subscription_count", q.value(2)); m.insert("total_amount", q.value(3));
                out.append(m);
            }
        }
        emit revenueSummaryReady(fromIso, toIso, typeFilter, out);
        db.close(); });
}

void DatabaseManager::listRevenueByTicketTypeAsync(const QString &fromIso,
                                                   const QString &toIso)
{
    const QString path = dbFilePath_;
    auto fut = QtConcurrent::run([this, fromIso, toIso, path]()
                                 {
        QList<QVariantMap> out;
        QSqlDatabase db = openThreadDb(path);
        QString sql = R"(
            SELECT COALESCE(p.ticket_type, 'monthly') AS ticket_type,
                   SUM(r.amount) AS total_amount,
                   COUNT(1) AS count
            FROM revenues r
            LEFT JOIN pricing p ON p.id = r.pricing_id
            WHERE r.created_at >= :fs AND r.created_at < :tn
            GROUP BY COALESCE(p.ticket_type, 'monthly')
            ORDER BY total_amount DESC
        )";
        QSqlQuery q(db);
        q.prepare(sql);
        const QDate df = QDate::fromString(fromIso, Qt::ISODate);
        const QDate dt = QDate::fromString(toIso, Qt::ISODate);
        const QString fromStart = QDateTime(df, QTime(0,0,0)).toString(Qt::ISODate);
        const QString toNext = QDateTime(dt.addDays(1), QTime(0,0,0)).toString(Qt::ISODate);
        q.bindValue(":fs", fromStart);
        q.bindValue(":tn", toNext);
        if (q.exec()) {
            while (q.next()) {
                QVariantMap m; m.insert("ticket_type", q.value(0)); m.insert("total_amount", q.value(1)); m.insert("count", q.value(2));
                out.append(m);
            }
        }
    emit revenueByTicketReady(fromIso, toIso, out);
    db.close(); });
}

bool DatabaseManager::setRfidCardStatus(const QString &rfid, const QString &status)
{
    if (rfid.trimmed().isEmpty())
        return false;
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE rfid_cards SET status=:st WHERE rfid=:rfid");
    q.bindValue(":st", status);
    q.bindValue(":rfid", rfid);
    if (!q.exec())
    {
        qWarning() << "setRfidCardStatus:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantMap DatabaseManager::getRfidCard(const QString &rfid)
{
    QVariantMap m;
    if (rfid.trimmed().isEmpty())
        return m;
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT id, rfid, vehicle_type, ticket_type, user_phone, status, created_at, assigned_at, description FROM rfid_cards WHERE rfid=:rfid LIMIT 1");
    q.bindValue(":rfid", rfid);
    if (q.exec() && q.next())
    {
        m.insert("id", q.value("id"));
        m.insert("rfid", q.value("rfid"));
        m.insert("vehicle_type", q.value("vehicle_type"));
        m.insert("ticket_type", q.value("ticket_type"));
        m.insert("user_phone", q.value("user_phone"));
        m.insert("status", q.value("status"));
        m.insert("created_at", q.value("created_at"));
        m.insert("assigned_at", q.value("assigned_at"));
        m.insert("description", q.value("description"));
    }
    return m;
}

bool DatabaseManager::deleteRfidCard(const QString &rfid)
{
    if (rfid.trimmed().isEmpty())
        return false;
    {
        QSqlQuery qc(DB_Connection);
        qc.prepare("SELECT user_phone, status FROM rfid_cards WHERE rfid=:rfid LIMIT 1");
        qc.bindValue(":rfid", rfid);
        if (!qc.exec())
        {
            qWarning() << "deleteRfidCard/check:" << qc.lastError().text();
            return false;
        }
        if (!qc.next())
        {
            return false;
        }
        const QString userPhone = qc.value(0).toString();
        const QString status = qc.value(1).toString();
        if (!userPhone.trimmed().isEmpty() || status == QStringLiteral("assigned"))
        {
            qWarning() << "deleteRfidCard: blocked, card is assigned to user" << userPhone << "status" << status;
            return false;
        }
    }

    QSqlQuery q(DB_Connection);
    q.prepare("DELETE FROM rfid_cards WHERE rfid=:rfid");
    q.bindValue(":rfid", rfid);
    if (!q.exec())
    {
        qWarning() << "deleteRfidCard:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

void DatabaseManager::upsertPricingRowsAsync(const QString &jsonText)
{
    const QString path = dbFilePath_;
    auto fut = QtConcurrent::run([this, jsonText, path]()
                                 {
        int saved = 0;
        QSqlDatabase db = openThreadDb(path);
        QSqlQuery q(db);
        QJsonParseError err; QJsonDocument doc = QJsonDocument::fromJson(jsonText.toUtf8(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isArray()) { emit pricingUpsertDone(0); db.close(); return; }
        QJsonArray arr = doc.array();
        db.transaction();
        for (const auto &v : arr) {
            if (!v.isObject()) continue;
            QJsonObject r = v.toObject();
            const QString vt = r.value("vehicle_type").toString();
            const QString tt = r.value("ticket_type").toString();
            const int base = r.value("base_fee").toInt();
            const int dur = r.value("duration_minutes").isNull() ? -1 : r.value("duration_minutes").toInt();
            const int inc = r.value("incremental_fee").isNull() ? -1 : r.value("incremental_fee").toInt();
            const int cap = r.value("max_daily_fee").isNull() ? -1 : r.value("max_daily_fee").toInt();
            const double disc = r.value("discount_percentage").toDouble();
            const int grace = r.value("grace_period").toInt();
            const QString desc = r.value("description").toString();
            const QString st = r.value("start_time").toString();
            const QString et = r.value("end_time").toString();
            // Reuse existing helper on this same connection: call SQL directly here mirroring upsertPricingRow
            // Check existing
            QSqlQuery qc(db);
            qc.prepare("SELECT id FROM pricing WHERE vehicle_type=:vt AND ticket_type=:tt LIMIT 1");
            qc.bindValue(":vt", vt); qc.bindValue(":tt", tt);
            int existingId = -1;
            if (qc.exec() && qc.next()) existingId = qc.value(0).toInt();
            if (existingId > 0) {
                QSqlQuery qu(db);
                qu.prepare(R"(UPDATE pricing SET base_fee=:b, duration_minutes=:d, incremental_fee=:i, max_daily_fee=:m, discount_percentage=:dp, grace_period=:g, description=:desc, start_time=:st, end_time=:et WHERE id=:id)");
                qu.bindValue(":b", base);
                qu.bindValue(":d", (dur < 0) ? QVariant() : QVariant(dur));
                qu.bindValue(":i", (inc < 0) ? QVariant() : QVariant(inc));
                qu.bindValue(":m", (cap < 0) ? QVariant() : QVariant(cap));
                qu.bindValue(":dp", disc); qu.bindValue(":g", grace); qu.bindValue(":desc", desc); qu.bindValue(":st", st); qu.bindValue(":et", et); qu.bindValue(":id", existingId);
                if (qu.exec()) {
                    saved++;
                } else {
                    qWarning() << "upsertPricingRowsAsync update:" << qu.lastError().text();
                }
            } else {
                QSqlQuery qi(db);
                qi.prepare(R"(INSERT INTO pricing(vehicle_type, ticket_type, base_fee, duration_minutes, incremental_fee, max_daily_fee, discount_percentage, grace_period, description, start_time, end_time) VALUES (:vt,:tt,:b,:d,:i,:m,:dp,:g,:desc,:st,:et))");
                qi.bindValue(":vt", vt); qi.bindValue(":tt", tt); qi.bindValue(":b", base);
                qi.bindValue(":d", (dur < 0) ? QVariant() : QVariant(dur));
                qi.bindValue(":i", (inc < 0) ? QVariant() : QVariant(inc));
                qi.bindValue(":m", (cap < 0) ? QVariant() : QVariant(cap));
                qi.bindValue(":dp", disc); qi.bindValue(":g", grace); qi.bindValue(":desc", desc); qi.bindValue(":st", st); qi.bindValue(":et", et);
                if (qi.exec()) {
                    saved++;
                } else {
                    qWarning() << "upsertPricingRowsAsync insert:" << qi.lastError().text();
                }
            }
        }
        db.commit();
        emit pricingUpsertDone(saved);
        db.close(); });
}

void DatabaseManager::seedDemoDataAsync(int days, int sessionsPerDay, int subscriptionsPerDay)
{
    const QString path = dbFilePath_;
    auto fut = QtConcurrent::run([this, path, days, sessionsPerDay, subscriptionsPerDay]()
                                 {
        bool ok = true;
        QSqlDatabase db = openThreadDb(path);
        db.transaction();
        // Vehicles and full 7 ticket types
        const QStringList vehicles = {"car", "bike"};
        const QStringList tickets = {"hourly","daily_day","daily_night","overnight","monthly","quarterly","yearly"};
        // Ensure pricing rows for all 7 types
        for (const auto &vt : vehicles) {
            for (const auto &tt : tickets) {
                QSqlQuery qc(db); qc.prepare("SELECT id FROM pricing WHERE vehicle_type=:vt AND ticket_type=:tt LIMIT 1"); qc.bindValue(":vt", vt); qc.bindValue(":tt", tt);
                int existingId=-1; if (qc.exec() && qc.next()) existingId = qc.value(0).toInt();
                if (existingId <= 0) {
                    int base = (tt=="hourly") ? (vt=="car"?30000:8000) : (tt=="overnight"? (vt=="car"?120000:40000) : (tt=="monthly"? (vt=="car"?1500000:250000) : (tt=="quarterly"? (vt=="car"?4200000:675000) : (tt=="yearly"? (vt=="car"?14400000:2400000) : (vt=="car"?200000:30000)))));
                    QSqlQuery qi(db);
                    qi.prepare(R"(INSERT INTO pricing(vehicle_type, ticket_type, base_fee, duration_minutes, incremental_fee, max_daily_fee, discount_percentage, grace_period, description, start_time, end_time)
                                   VALUES (:vt,:tt,:b,:d,:i,:m,:dp,:g,:desc,:st,:et))");
                    qi.bindValue(":vt", vt); qi.bindValue(":tt", tt); qi.bindValue(":b", base);
                    // Map durations/times
                    int dur = -1; int inc = -1; int cap = -1; double disc=0.0; int grace=10; QString st, et;
                    if (tt=="hourly") { dur=60; inc=-1; cap=-1; }
                    if (tt=="daily_day") { dur=12*60; st="06:00"; et="18:00"; }
                    if (tt=="daily_night") { dur=12*60; st="18:00"; et="06:00"; }
                    if (tt=="overnight") { dur=-1; }
                    if (tt=="quarterly") disc = 10.0;
                    if (tt=="yearly") disc = 20.0;
                    qi.bindValue(":d", (dur<0)?QVariant():QVariant(dur));
                    qi.bindValue(":i", (inc<0)?QVariant():QVariant(inc));
                    qi.bindValue(":m", (cap<0)?QVariant():QVariant(cap));
                    qi.bindValue(":dp", disc); qi.bindValue(":g", grace);
                    qi.bindValue(":desc", QStringLiteral("demo %1 %2").arg(vt, tt));
                    qi.bindValue(":st", st); qi.bindValue(":et", et);
                    if (!qi.exec()) { ok=false; }
                }
            }
        }
        // Helper to fetch pricing_id
        auto getPid = [&](const QString &vt, const QString &tt)->int{ QSqlQuery q(db); q.prepare("SELECT id FROM pricing WHERE vehicle_type=:vt AND ticket_type=:tt LIMIT 1"); q.bindValue(":vt", vt); q.bindValue(":tt", tt); if(q.exec()&&q.next()) return q.value(0).toInt(); return -1; };
        const QDate today = QDate::currentDate();
        // Create demo users to link sessions/subscriptions
        for (int u=0; u<20; ++u){ QSqlQuery uq(db); uq.prepare("INSERT INTO users(full_name, phone, rfid, plate, vehicle_type, created_at, updated_at) VALUES (:n,:p,:r,:pl,:vt,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)"); uq.bindValue(":n", QString("User %1").arg(u+1)); uq.bindValue(":p", QString("09%1").arg(1000000+u)); uq.bindValue(":r", QVariant()); uq.bindValue(":pl", QString("%1-%2%3%4").arg(u%2?"29A":"59B").arg(u%10).arg((u/10)%10).arg((u/100)%10)); uq.bindValue(":vt", (u%2)?"car":"bike"); uq.exec(); }
        // Sessions with 4 per-use types
        for (int d=0; d<days; ++d){ const QDate day=today.addDays(-d); for (int i=0;i<sessionsPerDay;++i){ const QString vt = (i%2)?"car":"bike"; const QString tt = tickets.at((i%4)); const int pid = getPid(vt, tt); QTime tIn = QTime(6,0).addSecs(QRandomGenerator::global()->bounded(16*3600)); QDateTime tin(day,tIn); QDateTime tout = tin.addSecs(QRandomGenerator::global()->bounded(6*3600)+30*60); QSqlQuery s(db); s.prepare(R"(INSERT INTO parking_sessions (user_id, pricing_id, rfid, plate, checkin_time, checkout_time, duration_minutes, fee, status) VALUES (NULL,:pid,NULL,NULL,:cin,:cout,:dur,:fee,'checked_out'))"); s.bindValue(":pid", pid>0?pid:QVariant()); s.bindValue(":cin", tin.toString(Qt::ISODate)); s.bindValue(":cout", tout.toString(Qt::ISODate)); const int fee = computeFeeJson(vt, tt, tin, tout, false); s.bindValue(":dur", int(tin.secsTo(tout)/60)); s.bindValue(":fee", fee); if (s.exec() && fee>0){ QSqlQuery rs(db); rs.prepare(R"(INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note) VALUES (:sid,NULL,NULL,:pid,:amt,'cash','parking_session',:ts,'demo'))"); rs.bindValue(":sid", s.lastInsertId()); rs.bindValue(":pid", pid>0?pid:QVariant()); rs.bindValue(":amt", fee); rs.bindValue(":ts", tout.toString(Qt::ISODate)); rs.exec(); } } }
    // Subscription creations and payments with monthly/quarterly/yearly
    for (int d=0; d<days; ++d){ const QDate day=today.addDays(-d); for (int k=0;k<subscriptionsPerDay;++k){ const QString plan = (k%3==0?"monthly":(k%3==1?"quarterly":"yearly")); const QString vt = (k%2)?"car":"bike"; const int pid = getPid(vt, plan); // create subscription row
        QSqlQuery sub(db); sub.prepare(R"(INSERT INTO subscriptions (user_id, pricing_id, plate, rfid, plan_type, start_date, end_date, payment_mode, price, status, created_at, updated_at) VALUES (NULL,:pid,NULL,NULL,:plan,:sd,:ed,'prepaid',:price,'active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP))"); sub.bindValue(":pid", pid>0?pid:QVariant()); sub.bindValue(":plan", plan); int off = QRandomGenerator::global()->bounded(120) - 60; const QDate sd = day.addDays(off); const QDate ed = sd.addDays(plan=="monthly"?30:(plan=="quarterly"?90:365)); sub.bindValue(":sd", QDateTime(sd, QTime(0,0)).toString(Qt::ISODate)); sub.bindValue(":ed", QDateTime(ed, QTime(0,0)).toString(Qt::ISODate)); const int price = (plan=="monthly"? (vt=="car"?1500000:250000) : (plan=="quarterly"? (vt=="car"?4200000:675000) : (vt=="car"?14400000:2400000))); sub.bindValue(":price", price); sub.exec(); // revenue for subscription
        QSqlQuery r(db); r.prepare(R"(INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note) VALUES (NULL, NULL, NULL, :pid, :amt, 'cash', 'subscription', :ts, 'demo'))"); r.bindValue(":pid", pid>0?pid:QVariant()); r.bindValue(":amt", price); r.bindValue(":ts", QDateTime(day, QTime(9,0).addSecs(QRandomGenerator::global()->bounded(10*3600))).toString(Qt::ISODate)); r.exec(); } }
    // Mark expired where end_date < today
    {
        QSqlQuery ue(db); ue.prepare("UPDATE subscriptions SET status='expired' WHERE DATE(end_date) < DATE(:t)"); ue.bindValue(":t", QDateTime(today, QTime(0,0)).toString(Qt::ISODate)); ue.exec();
    }
        db.commit();
        emit seedDemoDone(ok);
        db.close(); });
}

bool DatabaseManager::migrateParkingSessionsPricingNotNull()
{
    // Backfill NULL pricing_id using users.vehicle_type -> pricing(hourly)
    QSqlQuery q(DB_Connection);
    // 1) If pricing_id exists and is NULL, try to compute from user vehicle_type
    if (!q.exec(R"(
        UPDATE parking_sessions AS ps
        SET pricing_id = (
            SELECT p.id FROM users u
            JOIN pricing p ON p.vehicle_type = CASE
                WHEN LOWER(u.vehicle_type) IN ('motorbike','bike') THEN 'bike'
                WHEN LOWER(u.vehicle_type) = 'truck' THEN 'truck'
                ELSE 'car'
            END AND p.ticket_type = 'hourly'
            WHERE u.id = ps.user_id
            ORDER BY p.id ASC LIMIT 1
        )
        WHERE ps.pricing_id IS NULL
    )"))
        return false;

    // 2) Fallback: set to default hourly for 'car' if still NULL
    const int defaultHourly = getPricingIdFor(QStringLiteral("car"), QStringLiteral("hourly"));
    if (defaultHourly > 0)
    {
        QSqlQuery q2(DB_Connection);
        q2.prepare("UPDATE parking_sessions SET pricing_id=? WHERE pricing_id IS NULL");
        q2.addBindValue(defaultHourly);
        if (!q2.exec())
            return false;
    }
    return true;
}

QString DatabaseManager::normalizeVehicle(const QString &vt) const
{
    if (vt == "motorbike" || vt == "bike")
        return "bike";
    if (vt == "car")
        return "car";
    if (vt == "truck")
        return "truck";
    return vt.toLower();
}
QString DatabaseManager::normalizePlan(const QString &plan) const
{
    const QString p = plan.toLower();
    if (p.startsWith("tháng") || p == "month" || p == "monthly")
        return "monthly";
    if (p.startsWith("quý") || p == "quarter" || p == "quarterly")
        return "quarterly";
    if (p.startsWith("năm") || p == "year" || p == "yearly")
        return "yearly";
    return p;
}

QString DatabaseManager::normalizeTicketType(const QString &ticket) const
{
    const QString t = ticket.trimmed().toLower();
    if (t.isEmpty())
        return QString();
    if (t == "per_use" || t == "peruse" || t == "per-use")
        return QStringLiteral("hourly");
    if (t == "hourly" || t == "gio" || t == "giờ")
        return QStringLiteral("hourly");
    if (t == "daily" || t == "ngay" || t == "ngày")
        return QStringLiteral("daily");
    if (t == "daily_day" || t == "day" || t == "ngay_ngay")
        return QStringLiteral("daily_day");
    if (t == "daily_night" || t == "night" || t == "ngay_dem")
        return QStringLiteral("daily_night");
    if (t == "overnight" || t == "qua_dem")
        return QStringLiteral("overnight");
    if (t == "monthly" || t == "thang" || t == "tháng")
        return QStringLiteral("monthly");
    if (t == "quarterly" || t == "quy" || t == "quý")
        return QStringLiteral("quarterly");
    if (t == "yearly" || t == "nam" || t == "năm")
        return QStringLiteral("yearly");
    return t;
}

QString DatabaseManager::pickDailyTicketForNow(const QString &vehicleType) const
{
    Q_UNUSED(vehicleType);
    // Use 06:00-18:00 as day window by default
    const QTime now = QTime::currentTime();
    const QTime dayStart(6, 0), dayEnd(18, 0);
    if (now >= dayStart && now < dayEnd)
        return QStringLiteral("daily_day");
    return QStringLiteral("daily_night");
}

int DatabaseManager::getPricingIdFor(const QString &vehicleType, const QString &ticketType)
{
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT id FROM pricing WHERE vehicle_type=:vt AND ticket_type=:tt ORDER BY id DESC LIMIT 1");
    q.bindValue(":vt", normalizeVehicle(vehicleType));
    q.bindValue(":tt", ticketType);
    if (q.exec() && q.next())
        return q.value(0).toInt();
    return -1;
}

int DatabaseManager::computeFeeFromPricing(int baseFee,
                                           int durationMinutes,
                                           int incrementalFee,
                                           int graceMinutes,
                                           int capPerDay,
                                           const QDateTime &checkin,
                                           const QDateTime &checkout)
{
    // Basic block pricing: grace once, base applies for first duration, then incremental per durationMinutes
    qint64 totalMin = qMax<qint64>(0, checkin.secsTo(checkout) / 60);
    if (totalMin <= graceMinutes)
        return 0;
    if (durationMinutes <= 0)
        durationMinutes = 60;
    int fee = 0;
    // First block
    if (totalMin > 0)
    {
        fee += baseFee;
        totalMin -= qMin<qint64>(totalMin, durationMinutes);
    }
    if (totalMin > 0 && incrementalFee > 0)
    {
        const int steps = static_cast<int>((totalMin + durationMinutes - 1) / durationMinutes);
        fee += steps * incrementalFee;
    }
    if (capPerDay > 0)
        fee = std::min(fee, capPerDay);
    return fee;
}

bool DatabaseManager::hasOpenSession(const QString &rfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT COUNT(1) FROM parking_sessions WHERE rfid = :rfid AND checkout_time IS NULL");
    q.bindValue(":rfid", rfid);
    if (!q.exec())
    {
        qWarning() << "hasOpenSession query error:" << q.lastError().text();
        return false;
    }
    if (q.next())
    {
        return q.value(0).toInt() > 0;
    }
    return false;
}

// QString DatabaseManager::encodeText(const QString &plain) const
// {
//     // Mã hóa XOR đơn giản
//     QByteArray b = plain.toUtf8();
//     for (auto &ch : b)
//         ch ^= 0x5A;
//     return QString::fromUtf8(b.toBase64());
// }

QString DatabaseManager::sanitizeForFile(const QString &s) const
{
    QString r = s;
    r.replace(QRegularExpression("[^A-Za-z0-9_-]"), "_");
    return r;
}

bool DatabaseManager::saveTextToFile(const QString &filePath, const QString &text)
{
    QString outPath = filePath;
    // Convert possible file URL from QML to local file path
    if (outPath.startsWith("file:"))
    {
        QUrl u(outPath);
        if (u.isLocalFile())
            outPath = u.toLocalFile();
    }
    if (outPath.trimmed().isEmpty())
    {
        // Fallback: write to Desktop with timestamp
        const QString desktop = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        const QString ts = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
        outPath = desktop + "/export_" + ts + ".txt";
    }
    QFileInfo fi(outPath);
    QDir dir(fi.path());
    if (!dir.exists())
    {
        if (!dir.mkpath("."))
            return false;
    }
    QFile f(outPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    QTextStream os(&f);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    os.setEncoding(QStringConverter::Utf8);
#else
    os.setCodec("UTF-8");
#endif
    os << text;
    f.close();
    return true;
}

bool DatabaseManager::exportRevenueToPdf(const QVariantList &rows,
                                         const QString &fromDate,
                                         const QString &toDate,
                                         int totalRevenue,
                                         int totalSession,
                                         int totalSubscription,
                                         const QString &filePath)
{
    QString outPath = filePath;
    if (outPath.startsWith("file:"))
    {
        QUrl u(outPath);
        if (u.isLocalFile())
            outPath = u.toLocalFile();
    }
    if (outPath.trimmed().isEmpty())
    {
        const QString desktop = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        const QString ts = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
        outPath = desktop + "/bao_cao_doanh_thu_" + sanitizeForFile(fromDate) + "_" + sanitizeForFile(toDate) + "_" + ts + ".pdf";
    }

#if QT_CONFIG(pdf)
    QPdfWriter writer(outPath);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setResolution(96);
    QPainter painter(&writer);
    if (!painter.isActive())
    {
        emit pdfExported(outPath, false);
        return false;
    }
    const QMarginsF margin(36, 36, 36, 36); // 0.5 inch
    QRectF pageRect = QRectF(QPointF(0, 0), QSizeF(writer.width(), writer.height()));
    QRectF content = pageRect.marginsRemoved(margin);
    QFont titleFont("Helvetica", 14, QFont::Bold);
    QFont textFont("Helvetica", 9);
    painter.setFont(titleFont);
    painter.drawText(content.topLeft() + QPointF(0, 10), QStringLiteral("Báo cáo doanh thu"));
    painter.setFont(textFont);
    qreal y = content.top() + 30;
    const QString sub = QStringLiteral("Khoảng thời gian: %1 đến %2").arg(fromDate, toDate);
    painter.drawText(QPointF(content.left(), y), sub);
    y += 18;
    painter.drawText(QPointF(content.left(), y), QStringLiteral("Tổng lượt vé lượt: %1").arg(totalSession));
    y += 14;
    painter.drawText(QPointF(content.left(), y), QStringLiteral("Tổng vé tháng: %1").arg(totalSubscription));
    y += 14;
    painter.drawText(QPointF(content.left(), y), QStringLiteral("Tổng doanh thu: %1 VNĐ").arg(totalRevenue));
    y += 24;
    // Table header
    QFont headerFont("Helvetica", 9, QFont::Bold);
    painter.setFont(headerFont);
    const qreal col1 = content.left();
    const qreal col2 = col1 + 140;
    const qreal col3 = col2 + 140;
    const qreal col4 = col3 + 140;
    painter.drawText(QPointF(col1, y), QStringLiteral("Ngày"));
    painter.drawText(QPointF(col2, y), QStringLiteral("Lượt vé lượt"));
    painter.drawText(QPointF(col3, y), QStringLiteral("Vé tháng"));
    painter.drawText(QPointF(col4, y), QStringLiteral("Doanh thu"));
    y += 14;
    painter.setFont(textFont);
    for (const QVariant &vr : rows)
    {
        const QVariantMap m = vr.toMap();
        const QString d = m.value("d").toString();
        const int sess = m.value("session_count").toInt();
        const int subs = m.value("subscription_count").toInt();
        const int amount = m.value("total_amount").toInt();
        painter.drawText(QPointF(col1, y), d);
        painter.drawText(QPointF(col2, y), QString::number(sess));
        painter.drawText(QPointF(col3, y), QString::number(subs));
        painter.drawText(QPointF(col4, y), QString::number(amount));
        y += 14;
        if (y > content.bottom() - 40)
        {
            writer.newPage();
            y = content.top();
        }
    }
    painter.end();
    emit pdfExported(outPath, true);
    return true;
#else
    Q_UNUSED(rows)
    Q_UNUSED(fromDate)
    Q_UNUSED(toDate)
    Q_UNUSED(totalRevenue)
    Q_UNUSED(totalSession)
    Q_UNUSED(totalSubscription)
    // Fallback: cannot write PDF without Qt PDF support
    emit pdfExported(outPath, false);
    return false;
#endif
}

QList<QVariantMap> DatabaseManager::listUsers(int limit, int offset)
{
    QList<QVariantMap> out;
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT id, full_name, phone, rfid, plate, vehicle_type, status, created_at FROM users ORDER BY id DESC LIMIT :limit OFFSET :offset");
    q.bindValue(":limit", limit);
    q.bindValue(":offset", offset);
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("id", q.value("id"));
            m.insert("full_name", q.value("full_name"));
            m.insert("phone", q.value("phone"));
            m.insert("rfid", q.value("rfid"));
            m.insert("plate", q.value("plate"));
            m.insert("vehicle_type", q.value("vehicle_type"));
            m.insert("status", q.value("status"));
            m.insert("created_at", q.value("created_at"));
            out.append(m);
        }
    }
    else
    {
        qWarning() << "listUsers:" << q.lastError().text();
    }
    return out;
}

bool DatabaseManager::softDeleteUser(int userId)
{
    if (userId <= 0)
        return false;
    // Hard delete as per new requirement:
    // 1) Clear RFID cards bound to this user via user_phone (including assigned_at)
    // 2) Delete user row (subscriptions cascade via FK ON DELETE CASCADE)
    DB_Connection.transaction();
    // Find phone for this user to nullify rfid_cards.user_phone
    QString phone;
    {
        QSqlQuery qph(DB_Connection);
        qph.prepare("SELECT phone FROM users WHERE id=:id LIMIT 1");
        qph.bindValue(":id", userId);
        if (qph.exec() && qph.next())
            phone = qph.value(0).toString();
    }
    QSqlQuery qc(DB_Connection);
    if (!phone.isEmpty())
    {
        qc.prepare("UPDATE rfid_cards SET user_phone=NULL, status='available', assigned_at=NULL WHERE user_phone=:ph");
        qc.bindValue(":ph", phone);
    }
    else
    {
        qc.prepare("UPDATE rfid_cards SET user_phone=NULL, status='available', assigned_at=NULL WHERE 1=0");
    }
    if (!qc.exec())
    {
        qWarning() << "deleteUser free cards:" << qc.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    QSqlQuery qdel(DB_Connection);
    qdel.prepare("DELETE FROM users WHERE id=:id");
    qdel.bindValue(":id", userId);
    if (!qdel.exec())
    {
        qWarning() << "deleteUser users:" << qdel.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    DB_Connection.commit();
    return qdel.numRowsAffected() > 0;
}

QVariantMap DatabaseManager::getDashboardStats(const QString &todayIso)
{
    QVariantMap out;
    // Use index-friendly range on ISO timestamps [start, nextDay)
    const QDate d = QDate::fromString(todayIso, Qt::ISODate);
    const QString dayStart = QDateTime(d, QTime(0, 0, 0)).toString(Qt::ISODate);
    const QString nextStart = QDateTime(d.addDays(1), QTime(0, 0, 0)).toString(Qt::ISODate);
    QSqlQuery q(DB_Connection);
    q.prepare(R"(SELECT 
        (SELECT COUNT(1) FROM parking_sessions WHERE checkin_time >= :ds AND checkin_time < :dn) AS in_total,
        (SELECT COUNT(1) FROM parking_sessions WHERE checkout_time >= :ds AND checkout_time < :dn) AS out_total,
        (SELECT IFNULL(SUM(amount),0) FROM revenues WHERE created_at >= :ds AND created_at < :dn) AS revenue_total,
        (SELECT COUNT(1) FROM subscriptions WHERE status='expired') AS expired_subs
    )");
    q.bindValue(":ds", dayStart);
    q.bindValue(":dn", nextStart);
    if (q.exec() && q.next())
    {
        out.insert("in_today", q.value(0));
        out.insert("out_today", q.value(1));
        out.insert("revenue_today", q.value(2));
        out.insert("expired_subscriptions", q.value(3));
    }
    return out;
}

bool DatabaseManager::seedDemoData(int days, int sessionsPerDay, int subscriptionsPerDay)
{
    // Avoid reseeding if data already exists
    {
        QSqlQuery qc(DB_Connection);
        if (qc.exec("SELECT COUNT(1) FROM revenues"))
        {
            if (qc.next())
            {
                const int revCount = qc.value(0).toInt();
                if (revCount > 0)
                    return true; // already populated with revenue
            }
        }
    }
    if (days <= 0)
        days = 30;
    if (sessionsPerDay <= 0)
        sessionsPerDay = 40;
    if (subscriptionsPerDay < 0)
        subscriptionsPerDay = 5;
    // Basic vehicles and tickets
    const QStringList vehicles = {"car", "bike"};
    const QStringList tickets = {"hourly", "daily_day", "daily_night", "overnight"};

    // Ensure minimal pricing rows exist
    for (const auto &vt : vehicles)
    {
        for (const auto &tt : tickets)
        {
            if (getPricingIdFor(vt, tt) <= 0)
            {
                // Create a simple JSON with two slots day/night
                QJsonObject base;
                base.insert("base_minutes", 60);
                base.insert("base_price", vt == "car" ? 5000 : 3000);
                base.insert("increment_minutes", 60);
                base.insert("increment_price", vt == "car" ? 5000 : 3000);
                base.insert("grace_minutes", 10);
                base.insert("cap_per_day", vt == "car" ? 60000 : 40000);

                QJsonArray slotArray;
                QJsonObject dayPricing;
                dayPricing.insert("increment_minutes", 60);
                dayPricing.insert("increment_price", vt == "car" ? 5000 : 3000);
                dayPricing.insert("cap", vt == "car" ? 40000 : 25000);
                QJsonObject daySlot;
                daySlot.insert("start", "06:00");
                daySlot.insert("end", "22:00");
                daySlot.insert("pricing", dayPricing);
                slotArray.append(daySlot);
                QJsonObject nightPricing;
                nightPricing.insert("increment_minutes", 60);
                nightPricing.insert("increment_price", vt == "car" ? 7000 : 4000);
                nightPricing.insert("cap", vt == "car" ? 45000 : 30000);
                QJsonObject nightSlot;
                nightSlot.insert("start", "22:00");
                nightSlot.insert("end", "06:00");
                nightSlot.insert("pricing", nightPricing);
                slotArray.append(nightSlot);

                QJsonObject rules;
                rules.insert("overnight_fee", vt == "car" ? 10000 : 5000);
                rules.insert("lost_card_penalty", 100000);
                QJsonObject root;
                root.insert("base", base);
                root.insert("incremental", "flat");
                root.insert("time_slots", slotArray);
                root.insert("rules", rules);
                savePricingJson(vt, tt, QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact)), QString());
            }
        }
    }

    // Seed RFID cards for per-use (unassigned)
    for (int i = 0; i < 200; ++i)
    {
        const QString rfid = QStringLiteral("D%1").arg(100000 + i);
        const QString vt = vehicles.at(i % vehicles.size());
        const QString tt = tickets.at(i % tickets.size());
        upsertRfidCard(rfid, vt, tt, QStringLiteral("available"), QStringLiteral("demo"));
    }

    // Generate sessions and revenues back in time
    const QDate today = QDate::currentDate();
    for (int d = 0; d < days; ++d)
    {
        const QDate day = today.addDays(-d);
        // Sessions
        for (int i = 0; i < sessionsPerDay; ++i)
        {
            const QString vt = vehicles.at((d + i) % vehicles.size());
            const QString tt = tickets.at((d * 7 + i) % tickets.size());
            const QString rfid = QStringLiteral("D%1").arg(100000 + ((d * sessionsPerDay + i) % 200));
            // Check-in around day with random time
            QTime tIn = QTime(6, 0).addSecs(QRandomGenerator::global()->bounded(16 * 3600)); // between 06:00 and 22:00
            QDateTime tin(day, tIn);
            QDateTime tout = tin.addSecs(QRandomGenerator::global()->bounded(6 * 3600) + 30 * 60); // 30m – 6.5h
            // Create session row directly
            const int pid = getPricingIdFor(vt, tt);
            QSqlQuery ins(DB_Connection);
            ins.prepare(R"(INSERT INTO parking_sessions (user_id, pricing_id, rfid, plate, checkin_time, checkout_time, duration_minutes, fee, status)
                          VALUES (:uid,:pid,:rf,:pl,:cin,:cout,:dur,:fee,'checked_out'))");
            ins.bindValue(":uid", QVariant());
            ins.bindValue(":pid", pid);
            ins.bindValue(":rf", rfid);
            ins.bindValue(":pl", QVariant());
            ins.bindValue(":cin", tin.toString(Qt::ISODate));
            ins.bindValue(":cout", tout.toString(Qt::ISODate));
            const int fee = computeFeeJson(vt, tt, tin, tout, false);
            ins.bindValue(":dur", static_cast<int>(tin.secsTo(tout) / 60));
            ins.bindValue(":fee", fee);
            if (!ins.exec())
            {
                qWarning() << "seedDemoData insert session:" << ins.lastError().text();
            }
            else if (fee > 0)
            {
                // Insert a revenue row timestamped at checkout to align charts by day
                QSqlQuery rs(DB_Connection);
                rs.prepare(R"(INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note)
                              VALUES (:sid, NULL, :uid, :pid, :amt, 'cash', 'parking_session', :ts, 'demo'))");
                rs.bindValue(":sid", ins.lastInsertId());
                rs.bindValue(":uid", QVariant());
                rs.bindValue(":pid", pid);
                rs.bindValue(":amt", fee);
                rs.bindValue(":ts", tout.toString(Qt::ISODate));
                if (!rs.exec())
                    qWarning() << "seedDemoData insert session revenue:" << rs.lastError().text();
            }
        }

        // Subscription payments of the day
        for (int k = 0; k < subscriptionsPerDay; ++k)
        {
            const int amount = (QRandomGenerator::global()->bounded(6) + 5) * 100000; // 500k – 1M
            QSqlQuery r(DB_Connection);
            // Assign a plausible subscription pricing_id: alternate monthly/quarterly/yearly for demo aggregation
            const QString plans[3] = {"monthly", "quarterly", "yearly"};
            const QString plan = plans[(d + k) % 3];
            const int pid = getPricingIdFor(QStringLiteral("car"), plan) > 0 ? getPricingIdFor(QStringLiteral("car"), plan)
                                                                             : getPricingIdFor(QStringLiteral("bike"), plan);
            r.prepare(R"(INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note)
                         VALUES (NULL, NULL, NULL, :pid, :amt, 'cash', 'subscription', :ts, 'demo'))");
            r.bindValue(":pid", pid > 0 ? pid : QVariant());
            r.bindValue(":amt", amount);
            r.bindValue(":ts", QDateTime(day, QTime(9, 0).addSecs(QRandomGenerator::global()->bounded(10 * 3600))).toString(Qt::ISODate));
            if (!r.exec())
                qWarning() << "seedDemoData insert revenue:" << r.lastError().text();
        }
    }
    return true;
}

bool DatabaseManager::hasActiveSubscription(const QString &rfid,
                                            const QString &plate,
                                            const QString &nowIso)
{
    auto m = findActiveSubscription(rfid, plate, nowIso);
    return !m.isEmpty();
}

QList<QVariantMap> DatabaseManager::listRevenueSummary(const QString &fromIso,
                                                       const QString &toIso,
                                                       const QString &typeFilter)
{
    QList<QVariantMap> out;
    QString sql = R"(SELECT DATE(created_at) AS d,
        SUM(CASE WHEN revenue_type='parking_session' THEN 1 ELSE 0 END) AS session_count,
        SUM(CASE WHEN revenue_type='subscription' THEN 1 ELSE 0 END) AS subscription_count,
        SUM(amount) AS total_amount
        FROM revenues
        WHERE created_at >= :fs AND created_at < :tn
    )";
    if (!typeFilter.isEmpty() && typeFilter != "all")
    {
        sql += QStringLiteral(" AND revenue_type=:rt");
    }
    sql += QStringLiteral(" GROUP BY d ORDER BY d DESC LIMIT 180");
    QSqlQuery q(DB_Connection);
    q.prepare(sql);
    // Compute [fromStart, toNextDay)
    const QDate df = QDate::fromString(fromIso, Qt::ISODate);
    const QDate dt = QDate::fromString(toIso, Qt::ISODate);
    const QString fromStart = QDateTime(df, QTime(0, 0, 0)).toString(Qt::ISODate);
    const QString toNext = QDateTime(dt.addDays(1), QTime(0, 0, 0)).toString(Qt::ISODate);
    q.bindValue(":fs", fromStart);
    q.bindValue(":tn", toNext);
    if (!typeFilter.isEmpty() && typeFilter != "all")
        q.bindValue(":rt", typeFilter);
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("d", q.value(0));
            m.insert("session_count", q.value(1));
            m.insert("subscription_count", q.value(2));
            m.insert("total_amount", q.value(3));
            out.append(m);
        }
    }
    return out;
}

QList<QVariantMap> DatabaseManager::listRevenueByTicketType(const QString &fromIso,
                                                            const QString &toIso)
{
    QList<QVariantMap> out;
    // Aggregate by pricing.ticket_type to cover all 7 types
    // Note: Some subscription revenues may not have pricing_id set; treat them as monthly when missing (common case)
    QString sql = R"(
        SELECT COALESCE(p.ticket_type, 'monthly') AS ticket_type,
               SUM(r.amount) AS total_amount,
               COUNT(1) AS count
        FROM revenues r
        LEFT JOIN pricing p ON p.id = r.pricing_id
        WHERE r.created_at >= :fs AND r.created_at < :tn
        GROUP BY COALESCE(p.ticket_type, 'monthly')
        ORDER BY total_amount DESC
    )";
    QSqlQuery q(DB_Connection);
    q.prepare(sql);
    const QDate df = QDate::fromString(fromIso, Qt::ISODate);
    const QDate dt = QDate::fromString(toIso, Qt::ISODate);
    const QString fromStart = QDateTime(df, QTime(0, 0, 0)).toString(Qt::ISODate);
    const QString toNext = QDateTime(dt.addDays(1), QTime(0, 0, 0)).toString(Qt::ISODate);
    q.bindValue(":fs", fromStart);
    q.bindValue(":tn", toNext);
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("ticket_type", q.value(0));
            m.insert("total_amount", q.value(1));
            m.insert("count", q.value(2));
            out.append(m);
        }
    }
    return out;
}

bool DatabaseManager::cancelSubscription(int subId)
{
    if (subId <= 0)
        return false;
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE subscriptions SET status='canceled' WHERE id=:id AND status='active'");
    q.bindValue(":id", subId);
    if (!q.exec())
    {
        qWarning() << "cancelSubscription:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool DatabaseManager::markSubscriptionLostCard(int subId)
{
    if (subId <= 0)
        return false;
    // Mark subscription card lost and free assignment from rfid_cards table
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT rfid FROM subscriptions WHERE id=:id LIMIT 1");
    q.bindValue(":id", subId);
    QString rfid;
    if (q.exec() && q.next())
        rfid = q.value(0).toString();
    if (rfid.isEmpty())
        return false;
    QSqlQuery qc(DB_Connection);
    qc.prepare("UPDATE rfid_cards SET status='lost', user_phone=NULL WHERE rfid=:rfid");
    qc.bindValue(":rfid", rfid);
    if (!qc.exec())
    {
        qWarning() << "markSubscriptionLostCard card:" << qc.lastError().text();
        return false;
    }
    QSqlQuery qs(DB_Connection);
    qs.prepare("UPDATE subscriptions SET rfid=NULL WHERE id=:id");
    qs.bindValue(":id", subId);
    if (!qs.exec())
    {
        qWarning() << "markSubscriptionLostCard sub:" << qs.lastError().text();
        return false;
    }
    return true;
}

int DatabaseManager::expireDueSubscriptions(const QString &todayIso)
{
    // Expect todayIso format YYYY-MM-DD; treat subscriptions with end_date < today as expired
    if (todayIso.isEmpty())
        return 0;
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE subscriptions SET status='expired' WHERE status='active' AND end_date < :today");
    q.bindValue(":today", todayIso);
    if (!q.exec())
    {
        qWarning() << "expireDueSubscriptions:" << q.lastError().text();
        return 0;
    }
    return q.numRowsAffected();
}

QString DatabaseManager::nowIso8601() const
{
    // Dùng giờ LOCAL để đồng bộ với overlay thời gian in trên ảnh từ camera
    return QDateTime::currentDateTime().toString(Qt::ISODate);
}

int DatabaseManager::upsertUser(const QString &fullName,
                                const QString &phone,
                                const QString &rfid,
                                const QString &plate,
                                const QString &vehicleType)
{
    if (!DB_Connection.isOpen() && !DB_Connection.open())
        return -1;
    DB_Connection.transaction();
    QSqlQuery q(DB_Connection);
    // Tìm theo RFID trước, nếu không có thì theo plate
    int userId = -1;
    q.prepare("SELECT id FROM users WHERE (rfid = :rfid AND rfid IS NOT NULL AND rfid <> '') OR (plate = :plate AND plate IS NOT NULL AND plate <> '') LIMIT 1");
    q.bindValue(":rfid", rfid);
    q.bindValue(":plate", plate);
    if (q.exec() && q.next())
    {
        userId = q.value(0).toInt();
        // Cập nhật thông tin cơ bản nếu trống
        QSqlQuery upd(DB_Connection);
        upd.prepare("UPDATE users SET full_name = COALESCE(NULLIF(:name,''), full_name), phone = COALESCE(NULLIF(:phone,''), phone), rfid = COALESCE(NULLIF(:rfid,''), rfid), plate = COALESCE(NULLIF(:plate,''), plate), vehicle_type = COALESCE(NULLIF(:vt,''), vehicle_type) WHERE id = :id");
        upd.bindValue(":name", fullName);
        upd.bindValue(":phone", phone);
        upd.bindValue(":rfid", rfid);
        upd.bindValue(":plate", plate);
        upd.bindValue(":vt", vehicleType);
        upd.bindValue(":id", userId);
        if (!upd.exec())
        {
            qWarning() << "upsertUser update:" << upd.lastError().text();
            DB_Connection.rollback();
            return -1;
        }
    }
    else
    {
        // Tạo mới
        QSqlQuery ins(DB_Connection);
        ins.prepare("INSERT INTO users (full_name, phone, rfid, plate, vehicle_type, created_at, status) VALUES(:n,:p,:r,:pl,:vt,:ca,'active')");
        ins.bindValue(":n", fullName);
        ins.bindValue(":p", phone);
        ins.bindValue(":r", rfid);
        ins.bindValue(":pl", plate);
        ins.bindValue(":vt", vehicleType);
        ins.bindValue(":ca", nowIso8601());
        if (!ins.exec())
        {
            qWarning() << "upsertUser insert:" << ins.lastError().text();
            DB_Connection.rollback();
            return -1;
        }
        userId = ins.lastInsertId().toInt();
    }
    DB_Connection.commit();
    return userId;
}

int DatabaseManager::createSubscription(int userId,
                                        int pricingId,
                                        const QString &plate,
                                        const QString &rfid,
                                        const QString &planType,
                                        const QString &startDate,
                                        const QString &endDate,
                                        const QString &paymentMode,
                                        int price,
                                        const QString &status)
{
    // Guard: prevent duplicate active subscriptions for the same user + RFID/plate overlapping the same period
    {
        QSqlQuery chk(DB_Connection);
        chk.prepare(R"(
            SELECT id FROM subscriptions
            WHERE status='active'
              AND user_id = :uid
              AND ( ( :rf <> '' AND rfid = :rf ) OR ( :pl <> '' AND plate = :pl ) )
              AND NOT (date(end_date) < date(:ns) OR date(start_date) > date(:ne))
            LIMIT 1
        )");
        chk.bindValue(":uid", userId);
        chk.bindValue(":rf", rfid);
        chk.bindValue(":pl", plate);
        chk.bindValue(":ns", startDate);
        chk.bindValue(":ne", endDate);
        if (chk.exec() && chk.next())
        {
            qWarning() << "createSubscription: duplicate active subscription exists for user" << userId << "rfid/plate" << rfid << plate;
            // Return a negative code distinct from SQL error to indicate duplicate
            return -2;
        }
    }

    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO subscriptions (user_id, pricing_id, plate, rfid, plan_type, start_date, end_date, payment_mode, price, status)
        VALUES (:uid,:pid,:pl,:rf,:pt,:sd,:ed,:pm,:pr,:st)
    )");
    q.bindValue(":uid", userId);
    q.bindValue(":pid", pricingId);
    q.bindValue(":pl", plate);
    q.bindValue(":rf", rfid);
    q.bindValue(":pt", planType);
    q.bindValue(":sd", startDate);
    q.bindValue(":ed", endDate);
    q.bindValue(":pm", paymentMode);
    q.bindValue(":pr", price);
    q.bindValue(":st", status);
    if (!q.exec())
    {
        qWarning() << "createSubscription:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool DatabaseManager::updateSubscription(int id,
                                         int userId,
                                         const QString &plate,
                                         const QString &rfid,
                                         const QString &planType,
                                         const QString &startDate,
                                         const QString &endDate,
                                         const QString &paymentMode,
                                         int price,
                                         const QString &status)
{
    // Determine pricing_id from user vehicle type and normalized plan type
    QString vt = QStringLiteral("car");
    {
        QSqlQuery uq(DB_Connection);
        uq.prepare("SELECT vehicle_type FROM users WHERE id=:id LIMIT 1");
        uq.bindValue(":id", userId);
        if (uq.exec() && uq.next())
            vt = uq.value(0).toString();
        if (vt.isEmpty())
            vt = QStringLiteral("car");
    }
    const QString ticket = normalizePlan(planType);
    const int pid = getPricingIdFor(vt, ticket);
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        UPDATE subscriptions SET user_id=:uid, pricing_id=:pid, plate=:pl, rfid=:rf, plan_type=:pt, start_date=:sd, end_date=:ed,
               payment_mode=:pm, price=:pr, status=:st
        WHERE id=:id
    )");
    q.bindValue(":uid", userId);
    q.bindValue(":pid", pid > 0 ? QVariant(pid) : QVariant());
    q.bindValue(":pl", plate);
    q.bindValue(":rf", rfid);
    q.bindValue(":pt", ticket);
    q.bindValue(":sd", startDate);
    q.bindValue(":ed", endDate);
    q.bindValue(":pm", paymentMode);
    q.bindValue(":pr", price);
    q.bindValue(":st", status);
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "updateSubscription:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVariantMap DatabaseManager::findActiveSubscription(const QString &rfid,
                                                    const QString &plate,
                                                    const QString &nowIso)
{
    const QString now = nowIso.isEmpty() ? nowIso8601() : nowIso;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT * FROM subscriptions
        WHERE status='active'
          AND ( (rfid IS NOT NULL AND rfid <> '' AND rfid = :rf) OR (plate IS NOT NULL AND plate <> '' AND plate = :pl) )
          AND start_date <= :now AND end_date >= :now
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":rf", rfid);
    q.bindValue(":pl", plate);
    q.bindValue(":now", now);
    QVariantMap m;
    if (q.exec() && q.next())
    {
        const QSqlRecord rec = q.record();
        for (int i = 0; i < rec.count(); ++i)
            m.insert(rec.fieldName(i), q.value(i));
    }
    return m;
}

int DatabaseManager::insertRevenue(std::optional<int> sessionId,
                                   std::optional<int> subscriptionId,
                                   std::optional<int> userId,
                                   int amount,
                                   const QString &paymentType,
                                   const QString &revenueType,
                                   const QString &note)
{
    // Try to infer pricing_id if not provided by caller
    int pricingId = -1;
    if (sessionId.has_value())
    {
        QSqlQuery qp(DB_Connection);
        qp.prepare("SELECT pricing_id FROM parking_sessions WHERE id=:id");
        qp.bindValue(":id", sessionId.value());
        if (qp.exec() && qp.next())
            pricingId = qp.value(0).toInt();
    }
    else if (subscriptionId.has_value())
    {
        QSqlQuery qs(DB_Connection);
        qs.prepare("SELECT pricing_id FROM subscriptions WHERE id=:id");
        qs.bindValue(":id", subscriptionId.value());
        if (qs.exec() && qs.next())
            pricingId = qs.value(0).toInt();
    }

    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note)
        VALUES (:sid,:subid,:uid,:pid,:amt,:pt,:rt,:ts,:note)
    )");
    q.bindValue(":sid", sessionId.has_value() ? QVariant(sessionId.value()) : QVariant());
    q.bindValue(":subid", subscriptionId.has_value() ? QVariant(subscriptionId.value()) : QVariant());
    q.bindValue(":uid", userId.has_value() ? QVariant(userId.value()) : QVariant());
    q.bindValue(":pid", pricingId > 0 ? QVariant(pricingId) : QVariant());
    q.bindValue(":amt", amount);
    q.bindValue(":pt", paymentType);
    q.bindValue(":rt", revenueType);
    q.bindValue(":ts", nowIso8601());
    q.bindValue(":note", note);
    if (!q.exec())
    {
        qWarning() << "insertRevenue:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

int DatabaseManager::addPenalty(std::optional<int> userId,
                                int amount,
                                const QString &paymentType,
                                const QString &note)
{
    // Respect CHECK constraint: use 'other' for penalties
    return insertRevenue(std::nullopt, std::nullopt, userId, amount, paymentType, QStringLiteral("other"), note);
}

QList<QVariantMap> DatabaseManager::searchSessions(const QString &plate,
                                                   const QString &rfid,
                                                   const QString &fromIso,
                                                   const QString &toIso,
                                                   const QString &status,
                                                   int limit,
                                                   int offset)
{
    QString sql = "SELECT id, user_id, rfid, plate, checkin_time, checkout_time, duration_minutes, fee, status FROM parking_sessions WHERE 1=1";
    if (!plate.isEmpty())
        sql += " AND plate = :plate";
    if (!rfid.isEmpty())
        sql += " AND rfid = :rfid";
    if (!fromIso.isEmpty())
        sql += " AND checkin_time >= :from";
    if (!toIso.isEmpty())
        sql += " AND (checkout_time <= :to OR (checkout_time IS NULL AND checkin_time <= :to))";
    if (!status.isEmpty())
        sql += " AND status = :st";
    sql += " ORDER BY id DESC LIMIT :limit OFFSET :offset";
    QSqlQuery q(DB_Connection);
    q.prepare(sql);
    if (!plate.isEmpty())
        q.bindValue(":plate", plate);
    if (!rfid.isEmpty())
        q.bindValue(":rfid", rfid);
    if (!fromIso.isEmpty())
        q.bindValue(":from", fromIso);
    if (!toIso.isEmpty())
        q.bindValue(":to", toIso);
    if (!status.isEmpty())
        q.bindValue(":st", status);
    q.bindValue(":limit", limit);
    q.bindValue(":offset", offset);
    QList<QVariantMap> out;
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("id", q.value("id"));
            m.insert("user_id", q.value("user_id"));
            m.insert("rfid", q.value("rfid"));
            m.insert("plate", q.value("plate"));
            m.insert("checkin_time", q.value("checkin_time"));
            m.insert("checkout_time", q.value("checkout_time"));
            m.insert("duration_minutes", q.value("duration_minutes"));
            m.insert("fee", q.value("fee"));
            m.insert("status", q.value("status"));
            out.append(m);
        }
    }
    else
    {
        qWarning() << "searchSessions:" << q.lastError().text();
    }
    return out;
}

QVariantMap DatabaseManager::getSessionDetails(int id)
{
    QVariantMap m;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, rfid, plate, checkin_time, checkout_time, fee, checkin_image1, checkin_image2, checkout_image1, checkout_image2 
        FROM parking_sessions WHERE id = :id LIMIT 1
    )");
    q.bindValue(":id", id);
    if (q.exec() && q.next())
    {
        m.insert("id", q.value("id"));
        m.insert("rfid", q.value("rfid"));
        m.insert("plate", q.value("plate"));
        m.insert("checkin_time", q.value("checkin_time"));
        m.insert("checkout_time", q.value("checkout_time"));
        m.insert("fee", q.value("fee"));
        const QByteArray img1 = q.value("checkin_image1").isNull() ? QByteArray() : q.value("checkin_image1").toByteArray();
        const QByteArray img2 = q.value("checkin_image2").isNull() ? QByteArray() : q.value("checkin_image2").toByteArray();
        const QByteArray co1 = q.value("checkout_image1").isNull() ? QByteArray() : q.value("checkout_image1").toByteArray();
        const QByteArray co2 = q.value("checkout_image2").isNull() ? QByteArray() : q.value("checkout_image2").toByteArray();
        // Convert to data URL for QML Image with basic mime sniffing
        auto toDataUrl = [](const QByteArray &bytes) -> QString
        {
            if (bytes.isEmpty())
                return QString();
            QString mime = QStringLiteral("image/jpeg");
            if (bytes.size() >= 8)
            {
                const uchar b0 = static_cast<uchar>(bytes[0]);
                const uchar b1 = static_cast<uchar>(bytes[1]);
                const uchar b2 = static_cast<uchar>(bytes[2]);
                const uchar b3 = static_cast<uchar>(bytes[3]);
                if (b0 == 0xFF && b1 == 0xD8 && b2 == 0xFF)
                    mime = QStringLiteral("image/jpeg");
                else if (b0 == 0x89 && b1 == 0x50 && b2 == 0x4E && b3 == 0x47)
                    mime = QStringLiteral("image/png");
                else if (b0 == 'G' && b1 == 'I' && b2 == 'F' && b3 == '8')
                    mime = QStringLiteral("image/gif");
                else if (b0 == 'B' && b1 == 'M')
                    mime = QStringLiteral("image/bmp");
            }
            return QStringLiteral("data:") + mime + QStringLiteral(";base64,") + QString::fromLatin1(bytes.toBase64());
        };
        m.insert("img1", toDataUrl(img1));
        m.insert("img2", toDataUrl(img2));
        m.insert("checkout_img1", toDataUrl(co1));
        m.insert("checkout_img2", toDataUrl(co2));
    }
    return m;
}
CheckInResult DatabaseManager::checkIn(const QString &rfid,
                                       const QString &plate,
                                       const QByteArray &image1,
                                       const QByteArray &image2)
{
    if (hasOpenSession(rfid))
        return CheckInResult::AlreadyOpen; // Đang gửi – không cho check-in
    const QString encRfid = rfid;
    const QString encPlate = plate.isEmpty() ? QStringLiteral("unknown") : plate;
    const QString nowTxt = nowIso8601();
    // Gán user nếu có, và kiểm tra subscription active
    int userId = -1;
    QString vehicleType = QStringLiteral("car");
    QString cardVehicleType;
    QString cardTicketType;
    // Read RFID card info to support short-term cards without subscription/user
    {
        QSqlQuery qc(DB_Connection);
        qc.prepare("SELECT vehicle_type, ticket_type FROM rfid_cards WHERE rfid=:rf LIMIT 1");
        qc.bindValue(":rf", encRfid);
        if (qc.exec() && qc.next())
        {
            cardVehicleType = qc.value(0).toString();
            cardTicketType = qc.value(1).toString();
        }
    }
    if (auto u = findUserByRfidOrPlate(encRfid, encPlate))
    {
        userId = u->value("id").toInt();
        vehicleType = u->value("vehicle_type").toString();
        if (vehicleType.isEmpty())
            vehicleType = QStringLiteral("car");
    }
    // If no identified user, leave user_id as NULL to represent guest
    auto sub = findActiveSubscription(encRfid, encPlate, QString());
    int pricingId = -1;
    if (!sub.isEmpty() && sub.contains("pricing_id"))
        pricingId = sub.value("pricing_id").toInt();
    if (pricingId <= 0)
    {
        // Prefer card vehicle/ticket if available; fall back to user vehicle
        const QString vt = cardVehicleType.isEmpty() ? vehicleType : cardVehicleType;
        QString tt = normalizeTicketType(cardTicketType);
        if (tt.isEmpty())
            tt = QStringLiteral("hourly");
        // If generic daily, pick day/night by current time window
        if (tt == QLatin1String("daily"))
            tt = pickDailyTicketForNow(vt);
        pricingId = getPricingIdFor(vt, tt);
        if (pricingId <= 0)
        {
            // Fallback: try hourly if specific short-term ticket not configured
            pricingId = getPricingIdFor(vt, QStringLiteral("hourly"));
        }
    }
    QSqlQuery q(DB_Connection);
    // Dùng placeholders vị trí để tránh mismatch trong một số build Qt/SQLite
    q.prepare("INSERT INTO parking_sessions (user_id, pricing_id, rfid, plate, checkin_time, checkin_image1, checkin_image2, status) VALUES(?,?,?,?,?,?,?,?)");
    q.addBindValue(userId > 0 ? QVariant(userId) : QVariant());
    q.addBindValue(pricingId > 0 ? QVariant(pricingId) : QVariant());
    q.addBindValue(encRfid);
    q.addBindValue(encPlate);
    q.addBindValue(nowTxt);
    q.addBindValue(image1);
    q.addBindValue(image2);
    q.addBindValue(QStringLiteral("checked_in"));
    if (!q.exec())
    {
        qWarning() << "checkIn error:" << q.lastError().text();
        return CheckInResult::Error;
    }
    Q_UNUSED(sub);
    return CheckInResult::Ok;
}

CheckOutResult DatabaseManager::checkOut(const QString &rfid,
                                         const QString &plate)
{
    const QString encRfid = rfid;
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
    {
        qWarning() << "checkOut: no open session";
        return CheckOutResult::NoOpen;
    }

    const int id = openRec->value("id").toInt();
    const QString checkinTs = openRec->value("checkin_time").toString();
    QDateTime tin = QDateTime::fromString(checkinTs, Qt::ISODate);
    QDateTime tout = QDateTime::currentDateTime();
    qint64 mins = qMax<qint64>(0, tin.secsTo(tout) / 60);
    int userId = -1;
    QString vehicleType = "car";
    if (auto u = findUserByRfidOrPlate(encRfid, plate))
    {
        userId = u->value("id").toInt();
        vehicleType = u->value("vehicle_type").toString();
    }
    QVariantMap activeSub = findActiveSubscription(encRfid, plate, QString());
    bool hasSub = !activeSub.isEmpty();
    int fee = 0;

    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        UPDATE parking_sessions SET
            checkout_time = :ts,
            duration_minutes = :dur,
            fee = :fee,
            status = :st
        WHERE id = :id
    )");
    const QString coTs = nowIso8601();
    q.bindValue(":ts", coTs);
    q.bindValue(":dur", static_cast<int>(mins));
    // Compute fee (subscriptions pay 0; otherwise use pricing JSON)
    if (!hasSub)
        fee = computeFeeForSession(id, coTs, false);
    q.bindValue(":fee", fee);
    q.bindValue(":st", QStringLiteral("checked_out"));
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "checkout update error:" << q.lastError().text();
        return CheckOutResult::Error;
    }
    if (fee > 0)
    {
        // Include pricing_id on the revenue row for proper ticket-type aggregation
        QSqlQuery qp(DB_Connection);
        qp.prepare("SELECT pricing_id FROM parking_sessions WHERE id=:id");
        qp.bindValue(":id", id);
        int revPid = -1;
        if (qp.exec() && qp.next())
            revPid = qp.value(0).toInt();
        QSqlQuery r(DB_Connection);
        r.prepare(R"(INSERT INTO revenues (session_id, subscription_id, user_id, pricing_id, amount, payment_type, revenue_type, created_at, note)
                      VALUES (:sid, NULL, :uid, :pid, :amt, 'cash', 'parking_session', :ts, :note))");
        r.bindValue(":sid", id);
        r.bindValue(":uid", userId > 0 ? QVariant(userId) : QVariant());
        r.bindValue(":pid", revPid > 0 ? QVariant(revPid) : QVariant());
        r.bindValue(":amt", fee);
        r.bindValue(":ts", coTs);
        r.bindValue(":note", QString());
        if (!r.exec())
            qWarning() << "insert revenue on checkout:" << r.lastError().text();
    }
    return CheckOutResult::OkMatched;
}

std::optional<QVariantMap> DatabaseManager::findOpenByRfid(const QString &encodedRfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, rfid, plate, checkin_time, checkout_time, status
        FROM parking_sessions
        WHERE rfid = :rfid AND checkout_time IS NULL
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":rfid", encodedRfid);
    if (q.exec() && q.next())
    {
        QVariantMap m;
        m.insert("id", q.value("id"));
        m.insert("rfid", q.value("rfid"));
        m.insert("plate", q.value("plate"));
        m.insert("checkin_time", q.value("checkin_time"));
        m.insert("checkout_time", q.value("checkout_time"));
        m.insert("status", q.value("status"));
        return m;
    }
    return std::nullopt;
}

QVariantMap DatabaseManager::fetchOpenSession(const QString &rfid)
{
    const QString enc = rfid;
    auto rec = findOpenByRfid(enc);
    if (!rec.has_value())
        return {};
    QVariantMap m;
    m.insert("id", rec->value("id"));
    m.insert("rfid", rfid);
    m.insert("checkin_time", rec->value("checkin_time"));
    m.insert("status", rec->value("status"));
    return m;
}

CheckOutResult DatabaseManager::checkOutRfidOnly(const QString &rfid, QString *checkoutTimeOut)
{
    const QString encRfid = rfid;
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
        return CheckOutResult::NoOpen;
    const int id = openRec->value("id").toInt();
    const QString ts = nowIso8601();
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE parking_sessions SET checkout_time = :ts, status = :st WHERE id = :id");
    q.bindValue(":ts", ts);
    q.bindValue(":st", QStringLiteral("checked_out"));
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "checkOutRfidOnly error:" << q.lastError().text();
        return CheckOutResult::Error;
    }
    if (checkoutTimeOut)
        *checkoutTimeOut = ts;
    return CheckOutResult::OkMatched;
}

CheckOutResult DatabaseManager::checkOutRfidWithImages(const QString &rfid,
                                                       QString *checkoutTimeOut,
                                                       const QByteArray &image1,
                                                       const QByteArray &image2)
{
    const QString encRfid = rfid;
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
        return CheckOutResult::NoOpen;
    const int id = openRec->value("id").toInt();
    const QString ts = nowIso8601();
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE parking_sessions SET checkout_time = :ts, status = :st, checkout_image1 = :img1, checkout_image2 = :img2 WHERE id = :id");
    q.bindValue(":ts", ts);
    q.bindValue(":st", QStringLiteral("checked_out"));
    q.bindValue(":img1", image1);
    q.bindValue(":img2", image2);
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "checkOutRfidWithImages error:" << q.lastError().text();
        return CheckOutResult::Error;
    }
    if (checkoutTimeOut)
        *checkoutTimeOut = ts;
    return CheckOutResult::OkMatched;
}

bool DatabaseManager::deleteClosedSessions(const QString &rfid)
{
    const QString encRfid = rfid;
    QSqlQuery q(DB_Connection);
    // Preserve history but free the card by clearing RFID on closed sessions
    q.prepare("UPDATE parking_sessions SET rfid = '' WHERE rfid = :rfid AND checkout_time IS NOT NULL");
    q.bindValue(":rfid", encRfid);
    if (!q.exec())
    {
        qWarning() << "deleteClosedSessions (anonymize) error:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantMap DatabaseManager::fetchFullOpenSession(const QString &rfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, rfid, plate, checkin_time, checkout_time, checkin_image1, checkin_image2, checkout_image1, checkout_image2, status
        FROM parking_sessions
        WHERE rfid = :rfid AND checkout_time IS NULL
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":rfid", rfid);
    QVariantMap m;
    if (q.exec() && q.next())
    {
        m.insert("id", q.value("id"));
        m.insert("rfid", q.value("rfid"));
        m.insert("plate", q.value("plate"));
        m.insert("checkin_time", q.value("checkin_time"));
        m.insert("checkout_time", q.value("checkout_time"));
        m.insert("status", q.value("status"));
        m.insert("image1", q.value("checkin_image1"));
        m.insert("image2", q.value("checkin_image2"));
        m.insert("checkout_image1", q.value("checkout_image1"));
        m.insert("checkout_image2", q.value("checkout_image2"));
    }
    return m;
}

bool DatabaseManager::updatePlateForOpenSession(const QString &rfid, const QString &plate)
{
    const QString encRfid = rfid;
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
        return false;
    const int id = openRec->value("id").toInt();
    const QString encPlate = plate.isEmpty() ? QStringLiteral("unknown") : plate;
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE parking_sessions SET plate = :plate WHERE id = :id");
    q.bindValue(":plate", encPlate);
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "update plate for open session error:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantMap DatabaseManager::getUserById(int userId)
{
    QVariantMap m;
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT * FROM users WHERE id = :id LIMIT 1");
    q.bindValue(":id", userId);
    if (q.exec() && q.next())
    {
        const QSqlRecord rec = q.record();
        for (int i = 0; i < rec.count(); ++i)
            m.insert(rec.fieldName(i), q.value(i));
    }
    return m;
}

// --- Triển khai bảng giá động ---

std::optional<QVariantMap> DatabaseManager::findUserByRfidOrPlate(const QString &rfid,
                                                                  const QString &plate)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT * FROM users
        WHERE (rfid IS NOT NULL AND rfid <> '' AND rfid = :rf) OR (plate IS NOT NULL AND plate <> '' AND plate = :pl)
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":rf", rfid);
    q.bindValue(":pl", plate);
    if (q.exec() && q.next())
    {
        QVariantMap m;
        const QSqlRecord rec = q.record();
        for (int i = 0; i < rec.count(); ++i)
            m.insert(rec.fieldName(i), q.value(i));
        return m;
    }
    return std::nullopt;
}

int DatabaseManager::computeFee(const QString &vehicleType, qint64 durationMinutes)
{
    // Basic fallback: use latest pricing row columns if available, otherwise simple per-hour
    int baseFee = 5000;
    int grace = 0;
    int inc = 5000;
    int cap = 0;
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT base_fee, grace_period, incremental_fee, max_daily_fee FROM pricing WHERE vehicle_type=:vt AND ticket_type='hourly' ORDER BY id DESC LIMIT 1");
    q.bindValue(":vt", vehicleType);
    if (q.exec() && q.next())
    {
        baseFee = q.value(0).toInt();
        grace = q.value(1).toInt();
        inc = q.value(2).toInt();
        cap = q.value(3).toInt();
    }
    if (durationMinutes <= grace)
        return 0;
    qint64 hours = (durationMinutes + 59) / 60; // ceil hours
    int fee = 0;
    if (hours > 0)
    {
        fee = baseFee;
        if (hours > 1)
            fee += static_cast<int>((hours - 1) * inc);
    }
    if (cap > 0 && fee > cap)
        fee = cap;
    return fee;
}

int DatabaseManager::computeFeeJson(const QString &vehicleType,
                                    const QDateTime &checkin,
                                    const QDateTime &checkout,
                                    bool lostCard)
{
    Q_UNUSED(vehicleType);
    // fetch latest JSON pricing for this vehicle type & per_use
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT description, base_fee, grace_period, incremental_fee, max_daily_fee FROM pricing WHERE vehicle_type = :vt AND ticket_type = 'per_use' ORDER BY id DESC LIMIT 1");
    q.bindValue(":vt", vehicleType);
    QString jsonText;
    int fallbackBase = 5000, fallbackGrace = 0, fallbackInc = 5000, fallbackCap = 0;
    if (q.exec() && q.next())
    {
        jsonText = q.value(0).toString();
        fallbackBase = q.value(1).toInt();
        fallbackGrace = q.value(2).toInt();
        fallbackInc = q.value(3).toInt();
        fallbackCap = q.value(4).toInt();
    }

    if (lostCard)
    {
        if (!jsonText.isEmpty())
        {
            const auto obj = QJsonDocument::fromJson(jsonText.toUtf8()).object();
            const auto rules = obj.value("rules").toObject();
            return rules.value("lost_card_penalty").toInt(100000);
        }
        return 100000;
    }

    if (jsonText.isEmpty())
    {
        qint64 mins = qMax<qint64>(0, checkin.secsTo(checkout) / 60);
        return computeFee(vehicleType, mins);
    }

    const QJsonObject root = QJsonDocument::fromJson(jsonText.toUtf8()).object();
    const QJsonObject base = root.value("base").toObject();
    const int grace = base.value("grace_minutes").toInt(0);
    int baseMinutes = base.value("base_minutes").toInt(60);
    const int basePrice = base.value("base_price").toInt(0);
    const int incMinutesDefault = base.value("increment_minutes").toInt(60);
    const int incPriceDefault = base.value("increment_price").toInt(0);
    const int capPerDayDefault = base.value("cap_per_day").toInt(0);
    const QString incrementalMode = root.value("incremental").toString("flat");
    const QJsonArray timeSlots = root.value("time_slots").toArray();
    const QJsonObject rules = root.value("rules").toObject();
    const int overnightFee = rules.value("overnight_fee").toInt(0);

    auto daySlotsFor = [&](const QDate &day)
    {
        Q_UNUSED(day);
        struct Slot
        {
            QTime start;
            QTime end;
            int incMin;
            int incPrice;
            int cap;
        };
        QVector<Slot> daySlots;
        if (!timeSlots.isEmpty())
        {
            for (const auto &v : timeSlots)
            {
                const QJsonObject s = v.toObject();
                const QTime st = QTime::fromString(s.value("start").toString(), "HH:mm");
                QTime en = QTime::fromString(s.value("end").toString(), "HH:mm");
                if (!en.isValid())
                    en = QTime(23, 59, 59);
                const QJsonObject pr = s.value("pricing").toObject();
                daySlots.push_back({st, en, pr.value("increment_minutes").toInt(incMinutesDefault), pr.value("increment_price").toInt(incPriceDefault), pr.value("cap").toInt(capPerDayDefault)});
            }
        }
        else
        {
            daySlots.push_back({QTime(0, 0), QTime(23, 59, 59), incMinutesDefault, incPriceDefault, capPerDayDefault});
        }
        // sort by start
        std::sort(daySlots.begin(), daySlots.end(), [](const Slot &a, const Slot &b)
                  { return a.start < b.start; });
        return daySlots;
    };

    int totalFee = 0;
    QDateTime curStart = checkin;
    while (curStart < checkout)
    {
        const QDate day = curStart.date();
        const QDateTime dayEnd(day.addDays(1), QTime(0, 0));
        const QDateTime curEnd = std::min(checkout, dayEnd);
        int remainingGrace = grace;
        int dayFee = 0;
        int remainingBase = baseMinutes;

        const auto slotsToday = daySlotsFor(day);
        QDateTime s = curStart;
        while (s < curEnd)
        {
            const QTime nowT = s.time();
            // find active slot
            auto cur = slotsToday.last();
            for (const auto &sl : slotsToday)
            {
                if (nowT >= sl.start && nowT < sl.end)
                {
                    cur = sl;
                    break;
                }
            }
            QDateTime slotEnd(day, cur.end);
            if (slotEnd <= s)
                slotEnd = QDateTime(day.addDays(1), QTime(0, 0));
            if (slotEnd > curEnd)
                slotEnd = curEnd;
            int mins = static_cast<int>(qMax<qint64>(0, s.secsTo(slotEnd) / 60));
            if (mins <= 0)
            {
                s = slotEnd;
                continue;
            }

            // apply grace once per day
            int billable = mins;
            if (remainingGrace > 0)
            {
                const int used = std::min(remainingGrace, billable);
                billable -= used;
                remainingGrace -= used;
            }

            int feePart = 0;
            if (billable > 0)
            {
                // consume base minutes once per day (add basePrice when first consuming)
                if (remainingBase > 0)
                {
                    const int usedBase = std::min(remainingBase, billable);
                    if (remainingBase == baseMinutes)
                        dayFee += basePrice; // add once when base starts being used
                    remainingBase -= usedBase;
                    billable -= usedBase;
                }
                if (billable > 0)
                {
                    const int steps = (billable + cur.incMin - 1) / cur.incMin; // ceil
                    if (incrementalMode == "increasing")
                    {
                        for (int i = 0; i < steps; ++i)
                            feePart += cur.incPrice + i * 1000;
                    }
                    else if (incrementalMode == "decreasing")
                    {
                        for (int i = 0; i < steps; ++i)
                            feePart += std::max(0, cur.incPrice - i * 1000);
                    }
                    else
                    {
                        feePart += steps * cur.incPrice;
                    }
                }
                if (cur.cap > 0 && feePart > cur.cap)
                    feePart = cur.cap;
            }
            dayFee += feePart;
            s = slotEnd;
        }
        if (capPerDayDefault > 0 && dayFee > capPerDayDefault)
            dayFee = capPerDayDefault;
        totalFee += dayFee;
        curStart = curEnd;
    }

    if (checkin.date() != checkout.date() && overnightFee > 0)
        totalFee += overnightFee;
    return totalFee;
}

int DatabaseManager::computeFeeJson(const QString &vehicleType,
                                    const QString &ticketType,
                                    const QDateTime &checkin,
                                    const QDateTime &checkout,
                                    bool lostCard)
{
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT description, base_fee, grace_period, incremental_fee, max_daily_fee FROM pricing WHERE vehicle_type = :vt AND ticket_type = :tt ORDER BY id DESC LIMIT 1");
    q.bindValue(":vt", vehicleType);
    q.bindValue(":tt", ticketType);
    QString jsonText;
    int fallbackBase = 5000, fallbackGrace = 0, fallbackInc = 5000, fallbackCap = 0;
    if (q.exec() && q.next())
    {
        jsonText = q.value(0).toString();
        fallbackBase = q.value(1).toInt();
        fallbackGrace = q.value(2).toInt();
        fallbackInc = q.value(3).toInt();
        fallbackCap = q.value(4).toInt();
    }

    if (lostCard)
    {
        if (!jsonText.isEmpty())
        {
            const auto obj = QJsonDocument::fromJson(jsonText.toUtf8()).object();
            const auto rules = obj.value("rules").toObject();
            return rules.value("lost_card_penalty").toInt(100000);
        }
        return 100000;
    }

    if (jsonText.isEmpty())
    {
        // fallback to normalized columns via computeFee
        qint64 mins = qMax<qint64>(0, checkin.secsTo(checkout) / 60);
        return computeFee(vehicleType, mins);
    }

    // Parse and compute using the JSON text for this ticket type
    const QJsonObject root = QJsonDocument::fromJson(jsonText.toUtf8()).object();
    const QJsonObject base = root.value("base").toObject();
    const int grace = base.value("grace_minutes").toInt(0);
    int baseMinutes = base.value("base_minutes").toInt(60);
    const int basePrice = base.value("base_price").toInt(fallbackBase);
    const int incMinutesDefault = base.value("increment_minutes").toInt(60);
    const int incPriceDefault = base.value("increment_price").toInt(fallbackInc);
    const int capPerDayDefault = base.value("cap_per_day").toInt(fallbackCap);
    const QString incrementalMode = root.value("incremental").toString("flat");
    const QJsonArray timeSlots = root.value("time_slots").toArray();
    const QJsonObject rules = root.value("rules").toObject();
    const int overnightFee = rules.value("overnight_fee").toInt(0);

    struct Slot
    {
        QTime start;
        QTime end;
        int incMin;
        int incPrice;
        int cap;
    };
    auto daySlotsFor = [&](const QDate &day)
    {
        Q_UNUSED(day);
        QVector<Slot> daySlots;
        if (!timeSlots.isEmpty())
        {
            for (const auto &v : timeSlots)
            {
                const QJsonObject s = v.toObject();
                const QTime st = QTime::fromString(s.value("start").toString(), "HH:mm");
                QTime en = QTime::fromString(s.value("end").toString(), "HH:mm");
                if (!en.isValid())
                    en = QTime(23, 59, 59);
                const QJsonObject pr = s.value("pricing").toObject();
                daySlots.push_back({st, en,
                                    pr.value("increment_minutes").toInt(incMinutesDefault),
                                    pr.value("increment_price").toInt(incPriceDefault),
                                    pr.value("cap").toInt(capPerDayDefault)});
            }
        }
        else
        {
            daySlots.push_back({QTime(0, 0), QTime(23, 59, 59), incMinutesDefault, incPriceDefault, capPerDayDefault});
        }
        std::sort(daySlots.begin(), daySlots.end(), [](const Slot &a, const Slot &b)
                  { return a.start < b.start; });
        return daySlots;
    };

    int totalFee = 0;
    QDateTime curStart = checkin;
    while (curStart < checkout)
    {
        const QDate day = curStart.date();
        const QDateTime dayEnd(day.addDays(1), QTime(0, 0));
        const QDateTime curEnd = std::min(checkout, dayEnd);
        int remainingGrace = grace;
        int dayFee = 0;
        int remainingBase = baseMinutes;

        const auto slotsToday = daySlotsFor(day);
        QDateTime s = curStart;
        while (s < curEnd)
        {
            const QTime nowT = s.time();
            auto cur = slotsToday.last();
            for (const auto &sl : slotsToday)
            {
                if (nowT >= sl.start && nowT < sl.end)
                {
                    cur = sl;
                    break;
                }
            }
            QDateTime slotEnd(day, cur.end);
            if (slotEnd <= s)
                slotEnd = QDateTime(day.addDays(1), QTime(0, 0));
            if (slotEnd > curEnd)
                slotEnd = curEnd;
            int mins = static_cast<int>(qMax<qint64>(0, s.secsTo(slotEnd) / 60));
            if (mins <= 0)
            {
                s = slotEnd;
                continue;
            }

            int billable = mins;
            if (remainingGrace > 0)
            {
                const int used = std::min(remainingGrace, billable);
                billable -= used;
                remainingGrace -= used;
            }

            int feePart = 0;
            if (billable > 0)
            {
                if (remainingBase > 0)
                {
                    const int usedBase = std::min(remainingBase, billable);
                    if (remainingBase == baseMinutes)
                        feePart += basePrice; // add once when base starts being used
                    remainingBase -= usedBase;
                    billable -= usedBase;
                }
                if (billable > 0)
                {
                    const int steps = (billable + cur.incMin - 1) / cur.incMin; // ceil
                    if (incrementalMode == "increasing")
                    {
                        int inc = 0;
                        for (int i = 0; i < steps; ++i)
                            inc += cur.incPrice * (i + 1);
                        feePart += inc;
                    }
                    else
                    {
                        feePart += steps * cur.incPrice;
                    }
                }
                if (cur.cap > 0 && feePart > cur.cap)
                    feePart = cur.cap;
            }
            dayFee += feePart;
            s = slotEnd;
        }
        if (capPerDayDefault > 0 && dayFee > capPerDayDefault)
            dayFee = capPerDayDefault;
        totalFee += dayFee;
        curStart = curEnd;
    }

    if (checkin.date() != checkout.date() && overnightFee > 0)
        totalFee += overnightFee;
    return totalFee;
}

int DatabaseManager::computeFeeForSession(int sessionId,
                                          const QString &nowIso,
                                          bool lostCard)
{
    const QString now = nowIso.isEmpty() ? nowIso8601() : nowIso;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT s.id, s.user_id, s.rfid, s.plate, s.checkin_time,
               COALESCE(s.checkout_time, :now) AS co,
               s.pricing_id,
               u.vehicle_type,
               p.base_fee, p.duration_minutes, p.incremental_fee, p.grace_period, p.max_daily_fee,
               p.ticket_type, p.description
        FROM parking_sessions s
        LEFT JOIN users u ON u.id = s.user_id
        LEFT JOIN pricing p ON p.id = s.pricing_id
        WHERE s.id = :id
    )");
    q.bindValue(":now", now);
    q.bindValue(":id", sessionId);
    if (!q.exec() || !q.next())
        return -1;
    const QString vt = q.value("vehicle_type").toString().isEmpty() ? QStringLiteral("car") : q.value("vehicle_type").toString();
    const QString ttJoined = q.value("ticket_type").toString();
    const QDateTime tin = QDateTime::fromString(q.value("checkin_time").toString(), Qt::ISODate);
    const QDateTime tout = QDateTime::fromString(q.value("co").toString(), Qt::ISODate);
    if (lostCard)
        return 100000; // simple rule for now

    int fee = -1;
    int baseMin = 0; // minimum base to apply when duration > grace and computed fee == 0
    int graceAll = 0;

    // Prefer JSON description when valid
    bool usedJson = false;
    if (!q.value("description").isNull())
    {
        const QString jsonText = q.value("description").toString();
        QJsonParseError perr;
        const auto doc = QJsonDocument::fromJson(jsonText.toUtf8(), &perr);
        if (perr.error == QJsonParseError::NoError && doc.isObject())
        {
            const auto obj = doc.object();
            const auto base = obj.value("base").toObject();
            baseMin = base.value("base_price").toInt(0);
            graceAll = base.value("grace_minutes").toInt(0);
            const QString tt = ttJoined;
            fee = computeFeeJson(vt, tt, tin, tout, lostCard);
            usedJson = true;
        }
    }

    // Fallback to normalized columns
    if (fee < 0 && !q.value("base_fee").isNull())
    {
        const int baseFee = q.value("base_fee").toInt();
        const int durMin = q.value("duration_minutes").isNull() ? 60 : q.value("duration_minutes").toInt();
        const int incFee = q.value("incremental_fee").isNull() ? 0 : q.value("incremental_fee").toInt();
        const int grace = q.value("grace_period").isNull() ? 0 : q.value("grace_period").toInt();
        const int cap = q.value("max_daily_fee").isNull() ? 0 : q.value("max_daily_fee").toInt();
        fee = computeFeeFromPricing(baseFee, durMin, incFee, grace, cap, tin, tout);
        if (baseMin <= 0)
            baseMin = baseFee;
        if (graceAll <= 0)
            graceAll = grace;
    }

    // If still not computed, try ticket-aware JSON based on ticket type for this vehicle
    if (fee < 0)
    {
        QString ticketType;
        QSqlQuery qt(DB_Connection);
        qt.prepare("SELECT ticket_type, base_fee FROM pricing WHERE id = :pid LIMIT 1");
        qt.bindValue(":pid", q.value("pricing_id"));
        if (qt.exec() && qt.next())
        {
            ticketType = qt.value(0).toString();
            if (baseMin <= 0)
                baseMin = qt.value(1).toInt();
        }
        if (!ticketType.isEmpty())
            fee = computeFeeJson(vt, ticketType, tin, tout, lostCard);
    }

    // Try generic hourly pricing as last structured fallback
    if (fee < 0)
    {
        const int pid = getPricingIdFor(vt, QStringLiteral("hourly"));
        if (pid > 0)
        {
            QSqlQuery qp(DB_Connection);
            qp.prepare("SELECT base_fee, duration_minutes, incremental_fee, grace_period, max_daily_fee FROM pricing WHERE id=:id");
            qp.bindValue(":id", pid);
            if (qp.exec() && qp.next())
            {
                const int baseFee = qp.value(0).toInt();
                const int durMin = qp.value(1).isNull() ? 60 : qp.value(1).toInt();
                const int incFee = qp.value(2).isNull() ? 0 : qp.value(2).toInt();
                const int grace = qp.value(3).isNull() ? 0 : qp.value(3).toInt();
                const int cap = qp.value(4).isNull() ? 0 : qp.value(4).toInt();
                fee = computeFeeFromPricing(baseFee, durMin, incFee, grace, cap, tin, tout);
                if (baseMin <= 0)
                    baseMin = baseFee;
                if (graceAll <= 0)
                    graceAll = grace;
            }
        }
    }

    // Final fallback to generic JSON ("per_use") if present
    if (fee < 0)
        fee = computeFeeJson(vt, tin, tout, lostCard);

    // Apply minimum base when duration beyond grace but fee came out 0 due to grace rules
    const qint64 durationMin = qMax<qint64>(0, tin.secsTo(tout) / 60);
    const bool isPerUse = ttJoined.isEmpty() || ttJoined == QLatin1String("hourly") || ttJoined == QLatin1String("daily_day") || ttJoined == QLatin1String("daily_night") || ttJoined == QLatin1String("overnight");
    if (durationMin > qMax(0, graceAll) && isPerUse && fee == 0 && baseMin > 0)
        fee = baseMin;

    return fee;
}

bool DatabaseManager::savePricingJson(const QString &vehicleType,
                                      const QString &ticketType,
                                      const QString &jsonText,
                                      const QString &description)
{
    QSqlQuery q(DB_Connection);
    // Compatibility: store JSON text into description field for the given ticket type
    q.prepare(R"(
        INSERT INTO pricing (vehicle_type, ticket_type, base_fee, duration_minutes, incremental_fee, max_daily_fee, discount_percentage, grace_period, description, start_time, end_time)
        VALUES (:vt, :tt, 0, NULL, NULL, NULL, 0, 0, :desc, NULL, NULL)
    )");
    q.bindValue(":vt", vehicleType);
    q.bindValue(":tt", ticketType);
    q.bindValue(":desc", jsonText.isEmpty() ? description : jsonText);
    if (!q.exec())
    {
        qWarning() << "savePricingJson:" << q.lastError().text();
        return false;
    }
    return true;
}

QVariantMap DatabaseManager::getLatestPricing(const QString &vehicleType,
                                              const QString &ticketType)
{
    QVariantMap out;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, vehicle_type, ticket_type, description, base_fee, grace_period, incremental_fee, max_daily_fee
        FROM pricing
        WHERE vehicle_type = :vt AND ticket_type = :tt
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":vt", vehicleType);
    q.bindValue(":tt", ticketType);
    if (q.exec() && q.next())
    {
        out.insert("id", q.value("id"));
        out.insert("vehicle_type", q.value("vehicle_type"));
        out.insert("ticket_type", q.value("ticket_type"));
        const QString descOrJson = q.value("description").toString();
        out.insert("description", descOrJson);
        // For compatibility, expose as json/time_slot_text if it looks like JSON
        QJsonParseError perr;
        const auto doc = QJsonDocument::fromJson(descOrJson.toUtf8(), &perr);
        if (perr.error == QJsonParseError::NoError && doc.isObject())
            out.insert("json", doc.object().toVariantMap());
        else
            out.insert("json", QVariant());
        out.insert("time_slot_text", descOrJson);
        out.insert("base_fee", q.value("base_fee"));
        out.insert("grace_period", q.value("grace_period"));
        out.insert("incremental_fee", q.value("incremental_fee"));
        out.insert("max_daily_fee", q.value("max_daily_fee"));
    }
    return out;
}

QList<QVariantMap> DatabaseManager::listSubscriptions(int limit, int offset)
{
    QList<QVariantMap> out;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT s.id, s.user_id, u.full_name, u.vehicle_type, s.plate, s.rfid, s.plan_type,
               s.start_date, s.end_date, s.payment_mode, s.price, s.status
        FROM subscriptions s
        LEFT JOIN users u ON u.id = s.user_id
        ORDER BY s.id DESC
        LIMIT :limit OFFSET :offset
    )");
    q.bindValue(":limit", limit);
    q.bindValue(":offset", offset);
    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap m;
            m.insert("id", q.value("id"));
            m.insert("user_id", q.value("user_id"));
            m.insert("full_name", q.value("full_name"));
            m.insert("vehicle_type", q.value("vehicle_type"));
            m.insert("plate", q.value("plate"));
            m.insert("rfid", q.value("rfid"));
            m.insert("plan_type", q.value("plan_type"));
            m.insert("start_date", q.value("start_date"));
            m.insert("end_date", q.value("end_date"));
            m.insert("payment_mode", q.value("payment_mode"));
            m.insert("price", q.value("price"));
            m.insert("status", q.value("status"));
            out.append(m);
        }
    }
    else
    {
        qWarning() << "listSubscriptions:" << q.lastError().text();
    }
    return out;
}

int DatabaseManager::getPricingId(const QString &vehicleType, const QString &ticketType)
{
    return getPricingIdFor(vehicleType, ticketType);
}

QVariantMap DatabaseManager::getLatestSubscriptionForUser(int userId)
{
    QVariantMap out;
    if (userId <= 0)
        return out;
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT s.id, s.user_id, s.plate, s.rfid, s.plan_type, s.start_date, s.end_date,
               s.payment_mode, s.price, s.status
        FROM subscriptions s
        WHERE s.user_id = :uid
        ORDER BY s.id DESC
        LIMIT 1
    )");
    q.bindValue(":uid", userId);
    if (q.exec() && q.next())
    {
        const QSqlRecord rec = q.record();
        for (int i = 0; i < rec.count(); ++i)
        {
            out.insert(rec.fieldName(i), q.value(i));
        }
    }
    else if (q.lastError().isValid())
    {
        qWarning() << "getLatestSubscriptionForUser:" << q.lastError().text();
    }
    return out;
}

bool DatabaseManager::upsertPricingRow(const QString &vehicleType,
                                       const QString &ticketType,
                                       int baseFee,
                                       int durationMinutes,
                                       int incrementalFee,
                                       int maxDailyFee,
                                       double discountPercentage,
                                       int gracePeriod,
                                       const QString &description,
                                       const QString &startTime,
                                       const QString &endTime)
{
    const QString vt = normalizeVehicle(vehicleType);
    QSqlQuery q(DB_Connection);
    // Try update first
    q.prepare(R"(
        UPDATE pricing
        SET base_fee=:bf,
            duration_minutes=:dm,
            incremental_fee=:inc,
            max_daily_fee=:cap,
            discount_percentage=:disc,
            grace_period=:gr,
            description=:desc,
            start_time=:st,
            end_time=:et
        WHERE vehicle_type=:vt AND ticket_type=:tt
    )");
    q.bindValue(":bf", baseFee);
    if (durationMinutes <= 0)
        q.bindValue(":dm", QVariant());
    else
        q.bindValue(":dm", durationMinutes);
    if (incrementalFee <= 0)
        q.bindValue(":inc", QVariant());
    else
        q.bindValue(":inc", incrementalFee);
    if (maxDailyFee <= 0)
        q.bindValue(":cap", QVariant());
    else
        q.bindValue(":cap", maxDailyFee);
    q.bindValue(":disc", discountPercentage);
    q.bindValue(":gr", gracePeriod);
    q.bindValue(":desc", description);
    if (startTime.isEmpty())
        q.bindValue(":st", QVariant());
    else
        q.bindValue(":st", startTime);
    if (endTime.isEmpty())
        q.bindValue(":et", QVariant());
    else
        q.bindValue(":et", endTime);
    q.bindValue(":vt", vt);
    q.bindValue(":tt", ticketType);
    if (!q.exec())
    {
        qWarning() << "upsertPricingRow update:" << q.lastError().text();
        return false;
    }
    if (q.numRowsAffected() > 0)
        return true;

    // Insert if nothing updated
    QSqlQuery qi(DB_Connection);
    qi.prepare(R"(
        INSERT INTO pricing (vehicle_type, ticket_type, base_fee, duration_minutes, incremental_fee, max_daily_fee, discount_percentage, grace_period, description, start_time, end_time)
        VALUES (:vt, :tt, :bf, :dm, :inc, :cap, :disc, :gr, :desc, :st, :et)
    )");
    qi.bindValue(":vt", vt);
    qi.bindValue(":tt", ticketType);
    qi.bindValue(":bf", baseFee);
    if (durationMinutes <= 0)
        qi.bindValue(":dm", QVariant());
    else
        qi.bindValue(":dm", durationMinutes);
    if (incrementalFee <= 0)
        qi.bindValue(":inc", QVariant());
    else
        qi.bindValue(":inc", incrementalFee);
    if (maxDailyFee <= 0)
        qi.bindValue(":cap", QVariant());
    else
        qi.bindValue(":cap", maxDailyFee);
    qi.bindValue(":disc", discountPercentage);
    qi.bindValue(":gr", gracePeriod);
    qi.bindValue(":desc", description);
    if (startTime.isEmpty())
        qi.bindValue(":st", QVariant());
    else
        qi.bindValue(":st", startTime);
    if (endTime.isEmpty())
        qi.bindValue(":et", QVariant());
    else
        qi.bindValue(":et", endTime);
    if (!qi.exec())
    {
        qWarning() << "upsertPricingRow insert:" << qi.lastError().text();
        return false;
    }
    return true;
}
