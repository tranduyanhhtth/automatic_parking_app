#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QDir>
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QDateTime>
#include <QList>
// #include "domain/model/parkingrecord.h"
#include "domain/ports/iparkingrepository.h"
#include <optional>

class DatabaseManager : public QObject, public IParkingRepository
{
    Q_OBJECT

public:
    explicit DatabaseManager(QObject *parent = nullptr);

    // Khởi tạo CSDL (tạo bảng nếu chưa có)
    bool initialize();

    // Kiểm tra RFID có đang có phiên gửi xe (chưa checkout) hay không
    Q_INVOKABLE bool hasOpenSession(const QString &rfid) override;

    // API
    // Check-in: tạo bản ghi mới khi thẻ rảnh
    // Trả về 1 nếu thành công, -2 nếu đang gửi, -1 nếu lỗi
    Q_INVOKABLE CheckInResult checkIn(const QString &rfid,
                                      const QString &plate,
                                      const QByteArray &image1,
                                      const QByteArray &image2) override;

    // Check-out: so sánh biển số (trước/sau) với bản ghi đang mở
    // Trả về 1 nếu khớp và cập nhật thành công; 0 nếu không khớp; -2 nếu không có phiên mở; -1 nếu lỗi
    Q_INVOKABLE CheckOutResult checkOut(const QString &rfid,
                                        const QString &plate) override;
    Q_INVOKABLE QVariantMap fetchOpenSession(const QString &rfid) override;

    Q_INVOKABLE CheckOutResult checkOutRfidOnly(const QString &rfid, QString *checkoutTimeOut) override;
    Q_INVOKABLE CheckOutResult checkOutRfidWithImages(const QString &rfid,
                                                      QString *checkoutTimeOut,
                                                      const QByteArray &image1,
                                                      const QByteArray &image2) override;

    Q_INVOKABLE bool deleteClosedSessions(const QString &rfid) override;

    // Tạm thời lấy thông tin phiên vào dạng plaintext để hiển thị ở cổng ra
    Q_INVOKABLE QVariantMap fetchFullOpenSession(const QString &rfid) override;

    Q_INVOKABLE bool updatePlateForOpenSession(const QString &rfid, const QString &plate) override;
    Q_INVOKABLE QVariantMap getUserById(int userId) override;

    // Mở rộng: Users / Subscriptions / Pricing / Revenues
    Q_INVOKABLE int upsertUser(const QString &fullName,
                               const QString &phone,
                               const QString &rfid,
                               const QString &plate,
                               const QString &vehicleType) override;
    Q_INVOKABLE int createSubscription(int userId,
                                       const QString &plate,
                                       const QString &rfid,
                                       const QString &planType,
                                       const QString &startDate,
                                       const QString &endDate,
                                       const QString &paymentMode,
                                       int price,
                                       const QString &status) override;
    Q_INVOKABLE QVariantMap findActiveSubscription(const QString &rfid,
                                                   const QString &plate,
                                                   const QString &nowIso) override;
    Q_INVOKABLE int insertRevenue(std::optional<int> sessionId,
                                  std::optional<int> subscriptionId,
                                  std::optional<int> userId,
                                  int amount,
                                  const QString &paymentType,
                                  const QString &revenueType,
                                  const QString &note) override;
    Q_INVOKABLE int addPenalty(std::optional<int> userId,
                               int amount,
                               const QString &paymentType,
                               const QString &note) override;
    Q_INVOKABLE QList<QVariantMap> searchSessions(const QString &plate,
                                                  const QString &rfid,
                                                  const QString &fromIso,
                                                  const QString &toIso,
                                                  const QString &status,
                                                  int limit,
                                                  int offset) override;
    // Lấy chi tiết phiên theo ID, bao gồm ảnh (data URL)
    Q_INVOKABLE QVariantMap getSessionDetails(int id);
    Q_INVOKABLE int computeFeeForSession(int sessionId,
                                         const QString &nowIso,
                                         bool lostCard) override;
    Q_INVOKABLE bool savePricingJson(const QString &vehicleType,
                                     const QString &ticketType,
                                     const QString &jsonText,
                                     const QString &description) override;
    Q_INVOKABLE QVariantMap getLatestPricing(const QString &vehicleType,
                                             const QString &ticketType) override;

private:
    QSqlDatabase DB_Connection;

    bool ensureSchema();
    // Truy vấn bản ghi đang mở
    std::optional<QVariantMap> findOpenByRfid(const QString &encodedRfid);
    // Nội bộ: tra user theo RFID/Plate
    std::optional<QVariantMap> findUserByRfidOrPlate(const QString &rfid, const QString &plate);
    // Nội bộ: tính phí theo pricing cơ bản
    int computeFee(const QString &vehicleType, qint64 durationMinutes);
    // Nội bộ: tính phí theo JSON time_slots
    int computeFeeJson(const QString &vehicleType,
                       const QDateTime &checkin,
                       const QDateTime &checkout,
                       bool lostCard);

    // // Mã hóa đơn giản cho trường nhạy cảm (RFID, biển số)
    // QString encodeText(const QString &plain) const;

    // Chuẩn hóa chuỗi để đặt tên file an toàn
    QString sanitizeForFile(const QString &s) const;

    // Tạo timestamp dạng TEXT (ISO 8601)
    QString nowIso8601() const;
};

#endif // DATABASEMANAGER_H
