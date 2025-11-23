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
#include <QVariant>
// #include "domain/model/parkingrecord.h"
#include "domain/ports/iparkingrepository.h"
#include <optional>
class QThread;

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
                                                      const QByteArray &image2,
                                                      const QString &paymentMethod) override;

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
                                       int pricingId,
                                       const QString &plate,
                                       const QString &rfid,
                                       const QString &planType,
                                       const QString &startDate,
                                       const QString &endDate,
                                       const QString &paymentMode,
                                       int price,
                                       const QString &status,
                                       const QString &paymentmethod) override;
    Q_INVOKABLE bool updateSubscription(int id,
                                        int userId,
                                        const QString &plate,
                                        const QString &rfid,
                                        const QString &planType,
                                        const QString &startDate,
                                        const QString &endDate,
                                        const QString &paymentMode,
                                        int price,
                                        const QString &status,
                                        const QString &paymentMethod) override;
    Q_INVOKABLE bool updateSubscriptionPaymentDetails(int id,
                                                      const QString &paymentMode,
                                                      const QString &paymentMethod);
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

    // Danh sách subscriptions
    Q_INVOKABLE QList<QVariantMap> listSubscriptions(int limit = 500,
                                                     int offset = 0) override;
    Q_INVOKABLE QVariantMap getLatestSubscriptionForUser(int userId);
    Q_INVOKABLE int getPricingId(const QString &vehicleType,
                                 const QString &ticketType) override;

    // Seed demo data for dashboard/revenue when system is new
    Q_INVOKABLE bool seedDemoData(int days = 30,
                                  int sessionsPerDay = 50,
                                  int subscriptionsPerDay = 5);
    Q_INVOKABLE void seedDemoDataAsync(int days = 30,
                                       int sessionsPerDay = 50,
                                       int subscriptionsPerDay = 5);

    // Lưu một dòng pricing chuẩn hóa (update nếu đã tồn tại theo vehicle_type + ticket_type)
    Q_INVOKABLE bool upsertPricingRow(const QString &vehicleType,
                                      const QString &ticketType,
                                      int baseFee,
                                      int durationMinutes,
                                      int incrementalFee,
                                      int maxDailyFee,
                                      double discountPercentage,
                                      int gracePeriod,
                                      const QString &description,
                                      const QString &startTime,
                                      const QString &endTime);

    // Async batch upsert to avoid UI blocking when saving many rows
    Q_INVOKABLE void upsertPricingRowsAsync(const QString &jsonText);

    // RFID cards management (exposed to QML) -- moved to public to ensure meta-object visibility
    Q_INVOKABLE bool upsertRfidCard(const QString &rfid,
                                    const QString &vehicleType,
                                    const QString &ticketType,
                                    const QString &status,
                                    const QString &description = QString(),
                                    const QString &ownerName = QString(),
                                    const QString &plate = QString(),
                                    const QString &ownerPhone = QString());
    Q_INVOKABLE bool assignRfidCard(const QString &rfid, int userId);
    Q_INVOKABLE bool unassignRfidCard(const QString &rfid);
    Q_INVOKABLE QList<QVariantMap> listRfidCards(const QString &status = QString(),
                                                 const QString &vehicleType = QString(),
                                                 const QString &ticketType = QString(),
                                                 int limit = 500,
                                                 int offset = 0);
    Q_INVOKABLE bool setRfidCardStatus(const QString &rfid, const QString &status);
    Q_INVOKABLE QVariantMap getRfidCard(const QString &rfid);
    Q_INVOKABLE bool deleteRfidCard(const QString &rfid);

    // Dashboard & Revenue summaries
    Q_INVOKABLE QVariantMap getDashboardStats(const QString &todayIso);
    Q_INVOKABLE QList<QVariantMap> listRevenueSummary(const QString &fromIso,
                                                      const QString &toIso,
                                                      const QString &typeFilter);
    // Breakdown revenue by ticket_type across both session and subscription revenues
    Q_INVOKABLE QList<QVariantMap> listRevenueByTicketType(const QString &fromIso,
                                                           const QString &toIso);

    // Users management (Admin UI)
    Q_INVOKABLE QList<QVariantMap> listUsers(int limit = 500, int offset = 0);
    Q_INVOKABLE bool softDeleteUser(int userId); // mark inactive instead of hard delete
    Q_INVOKABLE bool cancelSubscription(int subId);
    Q_INVOKABLE bool markSubscriptionLostCard(int subId);
    Q_INVOKABLE int expireDueSubscriptions(const QString &todayIso);

    // Subscription checks (exposed for controller UI logic)
    Q_INVOKABLE bool hasActiveSubscription(const QString &rfid,
                                           const QString &plate = QString(),
                                           const QString &nowIso = QString());

    // Async variants (run on background thread and emit results back)
    Q_INVOKABLE void getDashboardStatsAsync(const QString &todayIso);
    Q_INVOKABLE void listRevenueSummaryAsync(const QString &fromIso,
                                             const QString &toIso,
                                             const QString &typeFilter);
    Q_INVOKABLE void listRevenueByTicketTypeAsync(const QString &fromIso,
                                                  const QString &toIso);

    // File export helpers (exposed to QML)
    Q_INVOKABLE bool saveTextToFile(const QString &filePath, const QString &text);
    // Export revenue summary to a PDF file. If filePath is empty, a default file will be placed on Desktop
    Q_INVOKABLE bool exportRevenueToPdf(const QVariantList &rows,
                                        const QString &fromDate,
                                        const QString &toDate,
                                        int totalRevenue,
                                        int totalSession,
                                        int totalSubscription,
                                        const QString &filePath = QString());
    // Employee Management
    Q_INVOKABLE QList<QVariantMap> listEmployees();
    Q_INVOKABLE int addEmployee(const QString &fullName, const QString &staffId, const QString &role, const QString &note);
    Q_INVOKABLE bool updateEmployee(int id, const QString &fullName, const QString &staffId, const QString &role, const QString &note);

    Q_INVOKABLE bool deleteEmployee(int id);
    Q_INVOKABLE bool checkInEmployee(int employeeId);
    Q_INVOKABLE bool checkOutEmployee(int employeeId);
signals:
    void dashboardStatsReady(const QString &todayIso, const QVariantMap &stats);
    void revenueSummaryReady(const QString &fromIso, const QString &toIso, const QString &typeFilter, const QList<QVariantMap> &rows);
    void revenueByTicketReady(const QString &fromIso, const QString &toIso, const QList<QVariantMap> &rows);
    void pricingUpsertDone(int savedCount);
    void seedDemoDone(bool ok);
    void pdfExported(const QString &filePath, bool ok);

private:
    QSqlDatabase DB_Connection;
    QString dbFilePath_;

    bool ensureSchema();
    bool ensureDefaultPricing();
    // Truy vấn bản ghi đang mở
    std::optional<QVariantMap> findOpenByRfid(const QString &encodedRfid);
    // Nội bộ: tra user theo RFID/Plate
    std::optional<QVariantMap> findUserByRfidOrPlate(const QString &rfid, const QString &plate);
    // Nội bộ: tra pricing id theo loại xe + loại vé
    int getPricingIdFor(const QString &vehicleType, const QString &ticketType);
    QString normalizeVehicle(const QString &vt) const; // motorbike->bike
    QString normalizePlan(const QString &plan) const;  // tháng->monthly
    // Map legacy/synonym ticket types to supported ones (e.g., daily -> daily_day/night by time, per_use -> hourly)
    QString normalizeTicketType(const QString &ticket) const;
    QString pickDailyTicketForNow(const QString &vehicleType) const;
    // Nội bộ: tính phí theo row pricing đã chọn
    int computeFeeFromPricing(int baseFee,
                              int durationMinutes,
                              int incrementalFee,
                              int graceMinutes,
                              int capPerDay,
                              const QDateTime &checkin,
                              const QDateTime &checkout);
    int computeFee(const QString &vehicleType, qint64 durationMinutes);
    int computeFeeJson(const QString &vehicleType,
                       const QDateTime &checkin,
                       const QDateTime &checkout,
                       bool lostCard);
    // Overload using specific ticket type (hourly/daily_day/daily_night/overnight)
    int computeFeeJson(const QString &vehicleType,
                       const QString &ticketType,
                       const QDateTime &checkin,
                       const QDateTime &checkout,
                       bool lostCard);

    // // Mã hóa đơn giản cho trường nhạy cảm (RFID, biển số)
    // QString encodeText(const QString &plain) const;

    // Chuẩn hóa chuỗi để đặt tên file an toàn
    QString sanitizeForFile(const QString &s) const;

    // Tạo timestamp dạng TEXT (ISO 8601)
    QString nowIso8601() const;
    // Migration helpers
    bool migrateParkingSessionsPricingNotNull();
};

#endif // DATABASEMANAGER_H
