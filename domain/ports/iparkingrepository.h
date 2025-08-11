#ifndef IPARKINGREPOSITORY_H
#define IPARKINGREPOSITORY_H
#include <QString>
#include <QByteArray>

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
    virtual CheckInResult checkIn(const QString &rfid,
                                  const QString &plateFront,
                                  const QString &plateRear,
                                  const QByteArray &frontImage,
                                  const QByteArray &rearImage) = 0;
    virtual CheckOutResult checkOut(const QString &rfid,
                                    const QString &plateFront,
                                    const QString &plateRear,
                                    const QByteArray &frontImage,
                                    const QByteArray &rearImage) = 0;
};

#endif // IPARKINGREPOSITORY_H
