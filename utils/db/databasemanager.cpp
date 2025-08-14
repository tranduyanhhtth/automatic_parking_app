#include "databasemanager.h"
#include <QFile>
#include <QRegularExpression>

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
    const QString ddl = R"(
        CREATE TABLE IF NOT EXISTS parking_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rfid TEXT NOT NULL,
            plate TEXT NOT NULL,
            checking_time TEXT NOT NULL,
            checkout_time TEXT,
            checkin_image1 BLOB,
            checkin_image2 BLOB,
            status TEXT NOT NULL
        )
    )";
    if (!q.exec(ddl))
    {
        qWarning() << "Không thể tạo bảng parking_log:" << q.lastError().text();
        return false;
    }
    return true;
}

bool DatabaseManager::hasOpenSession(const QString &rfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare("SELECT COUNT(1) FROM parking_log WHERE rfid = :rfid AND checkout_time IS NULL");
    q.bindValue(":rfid", encodeText(rfid));
    if (!q.exec())
    {
        qWarning() << "hasOpenSession query error:" << q.lastError().text();
        return false; // safer default
    }
    if (q.next())
    {
        return q.value(0).toInt() > 0;
    }
    return false;
}

QString DatabaseManager::encodeText(const QString &plain) const
{
    // Mã hóa XOR đơn giản để minh họa; nên thay thế bằng mã hóa thực tế khi triển khai
    QByteArray b = plain.toUtf8();
    for (auto &ch : b)
        ch ^= 0x5A;
    return QString::fromUtf8(b.toBase64());
}

QString DatabaseManager::sanitizeForFile(const QString &s) const
{
    QString r = s;
    r.replace(QRegularExpression("[^A-Za-z0-9_-]"), "_");
    return r;
}

QString DatabaseManager::nowIso8601() const
{
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}

CheckInResult DatabaseManager::checkIn(const QString &rfid,
                                       const QString &plate,
                                       const QByteArray &image1,
                                       const QByteArray &image2)
{
    if (hasOpenSession(rfid))
        return CheckInResult::AlreadyOpen; // Đang gửi – không cho check-in
    const QString encRfid = encodeText(rfid);
    const QString encPlate = encodeText(plate);
    const QString nowTxt = nowIso8601();
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO parking_log (rfid, plate, checking_time, checkin_image1, checkin_image2, status)
        VALUES(:rfid, :plate, :ts, :img1, :img2, :st)
    )");
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
    return CheckInResult::Ok;
}

CheckOutResult DatabaseManager::checkOut(const QString &rfid,
                                         const QString &plate)
{
    const QString encRfid = encodeText(rfid);
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
    {
        qWarning() << "checkOut: no open session";
        return CheckOutResult::NoOpen;
    }
    const int id = openRec->value("id").toInt();
    const QString encPlateSaved = openRec->value("plate").toString();
    const QString encPlateNow = encodeText(plate);
    const bool matched = (encPlateSaved == encPlateNow);
    if (!matched)
        return CheckOutResult::NotMatched; // Không khớp biển số – từ chối

    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        UPDATE parking_log SET
            checkout_time = :ts,
            status = :st
        WHERE id = :id
    )");
    q.bindValue(":ts", nowIso8601());
    q.bindValue(":st", QStringLiteral("out"));
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "checkout update error:" << q.lastError().text();
        return CheckOutResult::Error;
    }
    return CheckOutResult::OkMatched;
}

std::optional<QVariantMap> DatabaseManager::findOpenByRfid(const QString &encodedRfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, rfid, plate, checking_time, checkout_time,
               status
        FROM parking_log
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
        m.insert("checking_time", q.value("checking_time"));
        m.insert("checkout_time", q.value("checkout_time"));
        m.insert("status", q.value("status"));
        return m;
    }
    return std::nullopt;
}

QVariantMap DatabaseManager::fetchOpenSession(const QString &rfid)
{
    const QString enc = encodeText(rfid);
    auto rec = findOpenByRfid(enc);
    if (!rec.has_value())
        return {};
    QVariantMap m;
    m.insert("id", rec->value("id"));
    m.insert("rfid", rfid);
    m.insert("checking_time", rec->value("checking_time"));
    m.insert("status", rec->value("status"));
    return m;
}

CheckOutResult DatabaseManager::checkOutRfidOnly(const QString &rfid, QString *checkoutTimeOut)
{
    const QString encRfid = encodeText(rfid);
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
        return CheckOutResult::NoOpen;
    const int id = openRec->value("id").toInt();
    const QString ts = nowIso8601();
    QSqlQuery q(DB_Connection);
    q.prepare("UPDATE parking_log SET checkout_time = :ts, status = :st WHERE id = :id");
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

bool DatabaseManager::deleteClosedSessions(const QString &rfid)
{
    const QString encRfid = encodeText(rfid);
    QSqlQuery q(DB_Connection);
    q.prepare("DELETE FROM parking_log WHERE rfid = :rfid AND checkout_time IS NOT NULL");
    q.bindValue(":rfid", encRfid);
    if (!q.exec())
    {
        qWarning() << "deleteClosedSessions error:" << q.lastError().text();
        return false;
    }
    return true;
}
