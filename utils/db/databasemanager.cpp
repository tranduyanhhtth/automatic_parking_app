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
            plate_front TEXT NOT NULL,
            plate_rear TEXT NOT NULL,
            checkin_time INTEGER NOT NULL,
            checkout_time INTEGER,
            checkin_front_image_path TEXT,
            checkin_rear_image_path TEXT,
            checkout_front_image_path TEXT,
            checkout_rear_image_path TEXT,
            status INTEGER NOT NULL DEFAULT 0
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

QString DatabaseManager::saveJpeg(const QByteArray &bytes, const QString &role, const QString &rfid, qint64 ts) const
{
    if (bytes.isEmpty())
        return QString();
    const QString baseDir = QCoreApplication::applicationDirPath() + "/../../assets/captures"; // lưu cạnh thư mục assets
    QDir().mkpath(baseDir);
    const QString file = QString("%1/%2_%3_%4.jpg").arg(baseDir, sanitizeForFile(rfid)).arg(role).arg(QString::number(ts));
    QFile f(file);
    if (f.open(QIODevice::WriteOnly))
    {
        f.write(bytes);
        f.close();
        return QDir::toNativeSeparators(file);
    }
    return QString();
}

CheckInResult DatabaseManager::checkIn(const QString &rfid,
                                       const QString &plateFront,
                                       const QString &plateRear,
                                       const QByteArray &frontImage,
                                       const QByteArray &rearImage)
{
    if (hasOpenSession(rfid))
        return CheckInResult::AlreadyOpen; // Đang gửi – không cho check-in
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    const QString encRfid = encodeText(rfid);
    const QString encFront = encodeText(plateFront);
    const QString encRear = encodeText(plateRear);
    const QString frontPath = saveJpeg(frontImage, "checkin_front", rfid, now);
    const QString rearPath = saveJpeg(rearImage, "checkin_rear", rfid, now);
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO parking_log (rfid, plate_front, plate_rear, checkin_time, checkin_front_image_path, checkin_rear_image_path, status)
        VALUES(:rfid, :pf, :pr, :ts, :pff, :prf, 0)
    )");
    q.bindValue(":rfid", encRfid);
    q.bindValue(":pf", encFront);
    q.bindValue(":pr", encRear);
    q.bindValue(":ts", now);
    q.bindValue(":pff", frontPath);
    q.bindValue(":prf", rearPath);
    if (!q.exec())
    {
        qWarning() << "checkIn error:" << q.lastError().text();
        return CheckInResult::Error;
    }
    return CheckInResult::Ok;
}

CheckOutResult DatabaseManager::checkOut(const QString &rfid,
                                         const QString &plateFront,
                                         const QString &plateRear,
                                         const QByteArray &frontImage,
                                         const QByteArray &rearImage)
{
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    const QString encRfid = encodeText(rfid);
    auto openRec = findOpenByRfid(encRfid);
    if (!openRec.has_value())
    {
        qWarning() << "checkOut: no open session";
        return CheckOutResult::NoOpen;
    }
    const int id = openRec->id;
    const QString encFrontSaved = openRec->plateFront;
    const QString encRearSaved = openRec->plateRear;
    const QString encFrontNow = encodeText(plateFront);
    const QString encRearNow = encodeText(plateRear);
    const bool matched = (encFrontSaved == encFrontNow) && (encRearSaved == encRearNow);
    if (!matched)
        return CheckOutResult::NotMatched; // Không khớp biển số – từ chối

    const QString frontPath = saveJpeg(frontImage, "checkout_front", rfid, now);
    const QString rearPath = saveJpeg(rearImage, "checkout_rear", rfid, now);
    if (!updateCheckoutById(id, now, frontPath, rearPath))
        return CheckOutResult::Error;
    return CheckOutResult::OkMatched;
}

std::optional<ParkingRecord> DatabaseManager::findOpenByRfid(const QString &encodedRfid)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        SELECT id, rfid, plate_front, plate_rear, checkin_time, checkout_time,
               checkin_front_image_path, checkin_rear_image_path,
               checkout_front_image_path, checkout_rear_image_path, status
        FROM parking_log
        WHERE rfid = :rfid AND checkout_time IS NULL
        ORDER BY id DESC LIMIT 1
    )");
    q.bindValue(":rfid", encodedRfid);
    if (q.exec() && q.next())
        return ParkingRecord::fromQueryRow(q);
    return std::nullopt;
}

bool DatabaseManager::insertRecord(const ParkingRecord &rec)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        INSERT INTO parking_log (
            rfid, plate_front, plate_rear, checkin_time,
            checkin_front_image_path, checkin_rear_image_path, status
        ) VALUES(:rfid, :pf, :pr, :ts, :pff, :prf, :st)
    )");
    q.bindValue(":rfid", rec.rfid);
    q.bindValue(":pf", rec.plateFront);
    q.bindValue(":pr", rec.plateRear);
    q.bindValue(":ts", rec.checkinTime);
    q.bindValue(":pff", rec.checkinFrontImagePath);
    q.bindValue(":prf", rec.checkinRearImagePath);
    q.bindValue(":st", rec.status);
    if (!q.exec())
    {
        qWarning() << "insertRecord error:" << q.lastError().text();
        return false;
    }
    return true;
}

bool DatabaseManager::updateCheckoutById(int id, qint64 checkoutTime,
                                         const QString &frontPath,
                                         const QString &rearPath)
{
    QSqlQuery q(DB_Connection);
    q.prepare(R"(
        UPDATE parking_log SET
            checkout_time = :ts,
            checkout_front_image_path = :pff,
            checkout_rear_image_path = :prf,
            status = 1
        WHERE id = :id
    )");
    q.bindValue(":ts", checkoutTime);
    q.bindValue(":pff", frontPath);
    q.bindValue(":prf", rearPath);
    q.bindValue(":id", id);
    if (!q.exec())
    {
        qWarning() << "updateCheckoutById error:" << q.lastError().text();
        return false;
    }
    return true;
}
