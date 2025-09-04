#include "databasemanager.h"
#include <QFile>
#include <QRegularExpression>
#include <QSqlRecord>
// Pricing JSON & containers
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <algorithm>

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent)
{
    DB_Connection = QSqlDatabase::addDatabase("QSQLITE");
    DB_Connection.setDatabaseName(QCoreApplication::applicationDirPath() + "/../../database/parking.db");
    if (DB_Connection.open())
    {
        qDebug() << "Database Is Connected";
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
    return ensureSchema();
}

bool DatabaseManager::ensureSchema()
{
    QSqlQuery q(DB_Connection);
    DB_Connection.transaction();
    // 1) users
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            phone TEXT NOT NULL,
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

    // 2) parking_sessions (enforce NOT NULL on pricing_id, and RESTRICT on FKs)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS parking_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
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
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT,
            FOREIGN KEY(pricing_id) REFERENCES pricing(id) ON DELETE RESTRICT
        )
    )"))
    {
        qWarning() << "DDL parking_sessions:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }

    // Back-compat: parking_log cũ migrate sơ bộ sang parking_sessions
    if (q.exec("SELECT name FROM sqlite_master WHERE type='table' AND name='parking_log'") && q.next())
    {
        QSqlQuery copy(DB_Connection);
        copy.exec("INSERT INTO parking_sessions (rfid, plate, checkin_time, checkout_time, checkin_image1, checkin_image2, status) SELECT rfid, plate, checkin_time, checkout_time, checkin_image1, checkin_image2, status FROM parking_log WHERE NOT EXISTS (SELECT 1 FROM parking_sessions LIMIT 1)");
    }

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
            FOREIGN KEY(pricing_id) REFERENCES pricing(id) ON DELETE CASCADE
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

    // 5) revenues (link pricing_id and stricter enums)
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS revenues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER,
            subscription_id INTEGER,
            user_id INTEGER NOT NULL,
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

    DB_Connection.commit();
    // Seed default pricing if table is empty
    ensureDefaultPricing();

    // Backfill legacy columns just added (outside of transaction to avoid long locks)
    // Ensure we have a guest user id to satisfy NOT NULL user_id on new inserts
    const int guestId = ensureGuestUser();
    if (guestId > 0)
    {
        QSqlQuery updUser(DB_Connection);
        updUser.prepare("UPDATE parking_sessions SET user_id = COALESCE(user_id, ?) WHERE user_id IS NULL");
        updUser.addBindValue(guestId);
        updUser.exec(); // ignore errors if column already had data
    }

    // If an older DB has NULL pricing_id in parking_sessions, migrate/backfill it now
    migrateParkingSessionsPricingNotNull();
    return true;
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
    q.bindValue(":pid", pid > 0 ? QVariant(pid) : QVariant(QVariant::Int));
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
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO revenues (session_id, subscription_id, user_id, amount, payment_type, revenue_type, created_at, note)
        VALUES (:sid,:subid,:uid,:amt,:pt,:rt,:ts,:note)
    )");
    q.bindValue(":sid", sessionId.has_value() ? QVariant(sessionId.value()) : QVariant(QVariant::Int));
    q.bindValue(":subid", subscriptionId.has_value() ? QVariant(subscriptionId.value()) : QVariant(QVariant::Int));
    q.bindValue(":uid", userId.has_value() ? QVariant(userId.value()) : QVariant(QVariant::Int));
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
    if (auto u = findUserByRfidOrPlate(encRfid, encPlate))
    {
        userId = u->value("id").toInt();
        vehicleType = u->value("vehicle_type").toString();
        if (vehicleType.isEmpty())
            vehicleType = QStringLiteral("car");
    }
    if (userId <= 0)
        userId = ensureGuestUser();
    auto sub = findActiveSubscription(encRfid, encPlate, QString());
    int pricingId = -1;
    if (!sub.isEmpty() && sub.contains("pricing_id"))
        pricingId = sub.value("pricing_id").toInt();
    if (pricingId <= 0)
        pricingId = getPricingIdFor(vehicleType, QStringLiteral("hourly"));
    QSqlQuery q(DB_Connection);
    // Dùng placeholders vị trí để tránh mismatch trong một số build Qt/SQLite
    q.prepare("INSERT INTO parking_sessions (user_id, pricing_id, rfid, plate, checkin_time, checkin_image1, checkin_image2, status) VALUES(?,?,?,?,?,?,?,?)");
    q.addBindValue(userId);
    q.addBindValue(pricingId > 0 ? QVariant(pricingId) : QVariant(QVariant::Int));
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

int DatabaseManager::ensureGuestUser()
{
    // Tạo hoặc lấy user mặc định cho khách vãng lai
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT id FROM users WHERE phone = '0000000000' AND full_name = 'Guest' LIMIT 1");
    if (q.exec() && q.next())
        return q.value(0).toInt();
    QSqlQuery ins(DB_Connection);
    ins.prepare("INSERT INTO users (full_name, phone, rfid, plate, vehicle_type, created_at, status) VALUES(?,?,?,?,?,?,?)");
    ins.addBindValue(QStringLiteral("Guest"));
    ins.addBindValue(QStringLiteral("0000000000"));
    ins.addBindValue(QVariant());
    ins.addBindValue(QVariant());
    ins.addBindValue(QStringLiteral("car"));
    ins.addBindValue(nowIso8601());
    ins.addBindValue(QStringLiteral("active"));
    if (!ins.exec())
        return 1; // worst-case fallback, though NOT NULL will accept 1 only if exists
    return ins.lastInsertId().toInt();
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
        insertRevenue(id, std::nullopt, userId > 0 ? std::optional<int>(userId) : std::nullopt,
                      fee, QStringLiteral("cash"), QStringLiteral("parking_session"), QString());
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
               p.base_fee, p.duration_minutes, p.incremental_fee, p.grace_period, p.max_daily_fee
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
    const QDateTime tin = QDateTime::fromString(q.value("checkin_time").toString(), Qt::ISODate);
    const QDateTime tout = QDateTime::fromString(q.value("co").toString(), Qt::ISODate);
    if (lostCard)
        return 100000; // simple rule for now

    // If we have pricing joined, compute from normalized fields
    if (!q.value("base_fee").isNull())
    {
        const int baseFee = q.value("base_fee").toInt();
        const int durMin = q.value("duration_minutes").isNull() ? 60 : q.value("duration_minutes").toInt();
        const int incFee = q.value("incremental_fee").isNull() ? 0 : q.value("incremental_fee").toInt();
        const int grace = q.value("grace_period").isNull() ? 0 : q.value("grace_period").toInt();
        const int cap = q.value("max_daily_fee").isNull() ? 0 : q.value("max_daily_fee").toInt();
        return computeFeeFromPricing(baseFee, durMin, incFee, grace, cap, tin, tout);
    }
    // Fallback to hourly pricing by vehicle
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
            return computeFeeFromPricing(baseFee, durMin, incFee, grace, cap, tin, tout);
        }
    }
    // Last resort: legacy JSON
    return computeFeeJson(vt, tin, tout, lostCard);
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
