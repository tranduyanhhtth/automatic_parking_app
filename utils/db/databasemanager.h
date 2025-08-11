#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QDir>
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QtSql>
#include <QDebug>
#include <QDateTime>
#include "domain/model/parkingrecord.h"
#include "domain/ports/iparkingrepository.h"
#include <optional>

class DatabaseManager : public QObject, public IParkingRepository
{
    Q_OBJECT

public:
    explicit DatabaseManager(QObject *parent = nullptr);

    // Khởi tạo CSDL (tạo bảng nếu chưa có) – V2, không dùng nâng cấp từng cột
    bool initialize();

    // Kiểm tra RFID có đang có phiên gửi xe (chưa checkout) hay không
    Q_INVOKABLE bool hasOpenSession(const QString &rfid) override;

    // API phiên bản V2
    // Check-in: tạo bản ghi mới khi thẻ rảnh
    // Trả về 1 nếu thành công, -2 nếu đang gửi, -1 nếu lỗi
    Q_INVOKABLE CheckInResult checkIn(const QString &rfid,
                                      const QString &plateFront,
                                      const QString &plateRear,
                                      const QByteArray &frontImage,
                                      const QByteArray &rearImage) override;

    // Check-out: so sánh biển số (trước/sau) với bản ghi đang mở
    // Trả về 1 nếu khớp và cập nhật thành công; 0 nếu không khớp; -2 nếu không có phiên mở; -1 nếu lỗi
    Q_INVOKABLE CheckOutResult checkOut(const QString &rfid,
                                        const QString &plateFront,
                                        const QString &plateRear,
                                        const QByteArray &frontImage,
                                        const QByteArray &rearImage) override;

private:
    QSqlDatabase DB_Connection;

    // Khởi tạo lược đồ V2 nguyên khối (idempotent)
    bool ensureSchema();
    // Truy vấn bản ghi đang mở (nếu có)
    std::optional<ParkingRecord> findOpenByRfid(const QString &encodedRfid);
    // Tạo mới bản ghi check-in
    bool insertRecord(const ParkingRecord &rec);
    // Cập nhật bản ghi khi check-out
    bool updateCheckoutById(int id, qint64 checkoutTime,
                            const QString &frontPath,
                            const QString &rearPath);
    // Mã hóa/che mờ đơn giản cho trường nhạy cảm (RFID, biển số) – có thể thay bằng mã hóa thực tế
    QString encodeText(const QString &plain) const;
    // Chuẩn hóa chuỗi để đặt tên file an toàn
    QString sanitizeForFile(const QString &s) const;
    // Lưu ảnh JPEG ra đĩa, trả về đường dẫn
    QString saveJpeg(const QByteArray &bytes, const QString &role, const QString &rfid, qint64 ts) const;
};

#endif // DATABASEMANAGER_H
