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

    // 2) parking_sessions
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS parking_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
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
            status TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL
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

    // Indexes cho truy vấn nhanh
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_rfid_open ON parking_sessions(rfid, checkout_time)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_plate ON parking_sessions(plate)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_time ON parking_sessions(checkin_time, checkout_time)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_sessions_status ON parking_sessions(status)");

    // Migrate: add checkout images columns if missing (ignore errors if already exist)
    q.exec("ALTER TABLE parking_sessions ADD COLUMN checkout_image1 BLOB");
    q.exec("ALTER TABLE parking_sessions ADD COLUMN checkout_image2 BLOB");

    // 3) pricing
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS pricing (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_type TEXT NOT NULL,
            ticket_type TEXT NOT NULL,
            base_fee INTEGER NOT NULL,
            time_slot TEXT NOT NULL,
            grace_period INTEGER,
            incremental_fee INTEGER,
            decremental_fee INTEGER,
            max_daily_fee INTEGER,
            description TEXT
        )
    )"))
    {
        qWarning() << "DDL pricing:" << q.lastError().text();
        DB_Connection.rollback();
        return false;
    }
    q.exec("CREATE INDEX IF NOT EXISTS idx_pricing_vt_tt ON pricing(vehicle_type, ticket_type)");

    // 4) subscriptions
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            plate TEXT,
            rfid TEXT,
            plan_type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            payment_mode TEXT NOT NULL,
            price INTEGER NOT NULL,
            status TEXT DEFAULT 'active',
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
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

    // 5) revenues
    if (!q.exec(R"(
        CREATE TABLE IF NOT EXISTS revenues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER,
            subscription_id INTEGER,
            user_id INTEGER,
            amount INTEGER NOT NULL,
            payment_type TEXT NOT NULL,
            revenue_type TEXT NOT NULL,
            created_at TEXT,
            note TEXT,
            FOREIGN KEY(session_id) REFERENCES parking_sessions(id) ON DELETE SET NULL,
            FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL
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
    return true;
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
        INSERT INTO subscriptions (user_id, plate, rfid, plan_type, start_date, end_date, payment_mode, price, status)
        VALUES (:uid,:pl,:rf,:pt,:sd,:ed,:pm,:pr,:st)
    )");
    q.bindValue(":uid", userId);
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
    return insertRevenue(std::nullopt, std::nullopt, userId, amount, paymentType, QStringLiteral("penalty"), note);
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
    if (auto u = findUserByRfidOrPlate(encRfid, encPlate))
        userId = u->value("id").toInt();
    auto sub = findActiveSubscription(encRfid, encPlate, QString());
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO parking_sessions (user_id, rfid, plate, checkin_time, checkin_image1, checkin_image2, status)
        VALUES(:uid, :rfid, :plate, :ts, :img1, :img2, :st)
    )");
    q.bindValue(":uid", userId > 0 ? QVariant(userId) : QVariant(QVariant::Int));
    q.bindValue(":rfid", encRfid);
    q.bindValue(":plate", encPlate);
    q.bindValue(":ts", nowTxt);
    q.bindValue(":img1", image1);
    q.bindValue(":img2", image2);
    q.bindValue(":st", QStringLiteral("in"));
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
    q.bindValue(":st", QStringLiteral("out"));
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
    q.bindValue(":st", QStringLiteral("out"));
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
    q.bindValue(":st", QStringLiteral("out"));
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
    q.prepare("SELECT base_fee, grace_period, incremental_fee, max_daily_fee FROM pricing WHERE vehicle_type=:vt AND ticket_type='per_use' ORDER BY id DESC LIMIT 1");
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
    q.prepare("SELECT time_slot, base_fee, grace_period, incremental_fee, max_daily_fee FROM pricing WHERE vehicle_type = :vt AND ticket_type = 'per_use' ORDER BY id DESC LIMIT 1");
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
               u.vehicle_type
        FROM parking_sessions s
        LEFT JOIN users u ON u.id = s.user_id
        WHERE s.id = :id
    )");
    q.bindValue(":now", now);
    q.bindValue(":id", sessionId);
    if (!q.exec() || !q.next())
        return -1;
    const QString vt = q.value("vehicle_type").toString().isEmpty() ? QStringLiteral("car") : q.value("vehicle_type").toString();
    const QDateTime tin = QDateTime::fromString(q.value("checkin_time").toString(), Qt::ISODate);
    const QDateTime tout = QDateTime::fromString(q.value("co").toString(), Qt::ISODate);
    return computeFeeJson(vt, tin, tout, lostCard);
}

bool DatabaseManager::savePricingJson(const QString &vehicleType,
                                      const QString &ticketType,
                                      const QString &jsonText,
                                      const QString &description)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO pricing (vehicle_type, ticket_type, base_fee, time_slot, grace_period, incremental_fee, decremental_fee, max_daily_fee, description)
        VALUES (:vt, :tt, 0, :js, 0, 0, 0, 0, :desc)
    )");
    q.bindValue(":vt", vehicleType);
    q.bindValue(":tt", ticketType);
    q.bindValue(":js", jsonText);
    q.bindValue(":desc", description);
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
        SELECT id, vehicle_type, ticket_type, time_slot, description, base_fee, grace_period, incremental_fee, decremental_fee, max_daily_fee
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
        out.insert("description", q.value("description"));
        // Parse JSON text field into an object
        const QString js = q.value("time_slot").toString();
        QJsonParseError perr;
        const auto doc = QJsonDocument::fromJson(js.toUtf8(), &perr);
        if (perr.error == QJsonParseError::NoError && doc.isObject())
            out.insert("json", doc.object().toVariantMap());
        else
            out.insert("json", QVariant());
        out.insert("time_slot_text", js);
        out.insert("base_fee", q.value("base_fee"));
        out.insert("grace_period", q.value("grace_period"));
        out.insert("incremental_fee", q.value("incremental_fee"));
        out.insert("decremental_fee", q.value("decremental_fee"));
        out.insert("max_daily_fee", q.value("max_daily_fee"));
    }
    return out;
}
