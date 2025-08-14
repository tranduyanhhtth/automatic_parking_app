#ifndef IPARKINGREPOSITORY_H
#define IPARKINGREPOSITORY_H
#include <QString>
#include <QByteArray>
#include <QVariantMap>

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
    // Is there an open session (checkout_time is NULL)?
    virtual bool hasOpenSession(const QString &rfid) = 0;
    // Check-in: store rfid, unified plate, and two snapshot BLOBs.
    virtual CheckInResult checkIn(const QString &rfid,
                                  const QString &plate,
                                  const QByteArray &image1,
                                  const QByteArray &image2) = 0;
    // Check-out: verify plate matches and close the session. No image storage at checkout.
    virtual CheckOutResult checkOut(const QString &rfid,
                                    const QString &plate) = 0;
    // Lấy bản ghi đang mở theo RFID (map rỗng nếu không có)
    virtual QVariantMap fetchOpenSession(const QString &rfid) = 0;
    // Checkout chỉ dựa trên RFID (không so khớp biển số). Trả về thời gian checkout qua tham chiếu nếu thành công.
    virtual CheckOutResult checkOutRfidOnly(const QString &rfid, QString *checkoutTimeOut) = 0;
    // Xóa các bản ghi đã đóng (checkout_time NOT NULL) cho RFID
    virtual bool deleteClosedSessions(const QString &rfid) = 0;
};

#endif // IPARKINGREPOSITORY_H
