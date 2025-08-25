#ifndef IPARKINGREPOSITORY_H
#define IPARKINGREPOSITORY_H
#include <QString>
#include <QByteArray>
#include <QVariantMap>
#include <optional>

enum class CheckInResult
{
    Ok = 1,
    AlreadyOpen = -2,
    Error = -1
};
enum class CheckOutResult
{
    OkMatched = 1,
    NotMatched = 0,
    NoOpen = -2,
    Error = -1
};

class IParkingRepository
{
public:
    virtual ~IParkingRepository() = default;
    virtual bool hasOpenSession(const QString &rfid) = 0;
    // Check-in: lưu trữ rfid, biển số thống nhất và hai BLOB hình ảnh chụp.
    virtual CheckInResult checkIn(const QString &rfid,
                                  const QString &plate,
                                  const QByteArray &image1,
                                  const QByteArray &image2) = 0;
    // Check-out: kiểm tra biển số và đóng phiên. Không lưu hình ảnh khi checkout.
    virtual CheckOutResult checkOut(const QString &rfid,
                                    const QString &plate) = 0;
    // Lấy bản ghi đang mở theo RFID (map rỗng nếu không có)
    virtual QVariantMap fetchOpenSession(const QString &rfid) = 0;
    // Checkout chỉ dựa trên RFID (không so khớp biển số). Trả về thời gian checkout qua tham chiếu nếu thành công.
    virtual CheckOutResult checkOutRfidOnly(const QString &rfid, QString *checkoutTimeOut) = 0;
    // Checkout theo RFID và lưu ảnh checkout (2 ảnh). Trả về thời gian checkout qua tham chiếu nếu thành công.
    virtual CheckOutResult checkOutRfidWithImages(const QString &rfid,
                                                  QString *checkoutTimeOut,
                                                  const QByteArray &image1,
                                                  const QByteArray &image2) = 0;
    // Xóa các bản ghi đã đóng (checkout_time NOT NULL) cho RFID
    virtual bool deleteClosedSessions(const QString &rfid) = 0;
    // Lấy full thông tin phiên mở (kèm ảnh) để hiển thị
    virtual QVariantMap fetchFullOpenSession(const QString &rfid) = 0;
    // Cập nhật biển số cho phiên đang mở theo RFID (nếu tồn tại).
    virtual bool updatePlateForOpenSession(const QString &rfid, const QString &plate) = 0;

    // Lấy thông tin người dùng theo ID (nếu có liên kết)
    virtual QVariantMap getUserById(int userId) = 0;

    // === Mở rộng miền dữ liệu (Users / Subscriptions / Pricing / Revenues) ===
    // Tạo hoặc cập nhật user theo RFID/biển số; trả về user_id (hoặc -1 nếu lỗi)
    virtual int upsertUser(const QString &fullName,
                           const QString &phone,
                           const QString &rfid,
                           const QString &plate,
                           const QString &vehicleType) = 0;
    // Tạo subscription (vé tháng/quý/tuần); trả về id hoặc -1 nếu lỗi
    virtual int createSubscription(int userId,
                                   const QString &plate,
                                   const QString &rfid,
                                   const QString &planType,
                                   const QString &startDate,
                                   const QString &endDate,
                                   const QString &paymentMode,
                                   int price,
                                   const QString &status = QStringLiteral("active")) = 0;
    // Tìm subscription còn hạn tại thời điểm nowIso (nếu nowIso rỗng dùng hiện tại)
    virtual QVariantMap findActiveSubscription(const QString &rfid,
                                               const QString &plate,
                                               const QString &nowIso = QString()) = 0;
    // Lưu doanh thu (vé tháng, phiên gửi xe, phạt, khác)
    virtual int insertRevenue(std::optional<int> sessionId,
                              std::optional<int> subscriptionId,
                              std::optional<int> userId,
                              int amount,
                              const QString &paymentType,
                              const QString &revenueType,
                              const QString &note = QString()) = 0;
    // Ghi nhận phạt
    virtual int addPenalty(std::optional<int> userId,
                           int amount,
                           const QString &paymentType,
                           const QString &note) = 0;
    // Tìm kiếm các phiên gửi xe theo nhiều tiêu chí
    virtual QList<QVariantMap> searchSessions(const QString &plate,
                                              const QString &rfid,
                                              const QString &fromIso,
                                              const QString &toIso,
                                              const QString &status,
                                              int limit = 200,
                                              int offset = 0) = 0;
    // Tính phí theo sessionId dựa trên pricing JSON + quy tắc; nếu nowIso trống sẽ dùng hiện tại
    virtual int computeFeeForSession(int sessionId,
                                     const QString &nowIso = QString(),
                                     bool lostCard = false) = 0;
    // Lưu cấu hình pricing dạng JSON cho vehicle_type + ticket_type (tạo phiên bản mới)
    virtual bool savePricingJson(const QString &vehicleType,
                                 const QString &ticketType,
                                 const QString &jsonText,
                                 const QString &description = QString()) = 0;

    // Lấy cấu hình pricing JSON mới nhất cho vehicle_type + ticket_type
    virtual QVariantMap getLatestPricing(const QString &vehicleType,
                                         const QString &ticketType) = 0;
};

#endif // IPARKINGREPOSITORY_H
