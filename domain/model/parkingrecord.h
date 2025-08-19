#ifndef PARKINGRECORD_H
#define PARKINGRECORD_H

#include <QString>
#include <QSqlQuery>
#include <QVariant>

// Mô hình dữ liệu cho 1 bản ghi bãi đỗ xe
class ParkingRecord
{
public:
    int id = 0;
    QString rfid;
    QString plateFront;
    QString plateRear;
    qint64 checkinTime = 0;
    qint64 checkoutTime = 0;
    QString checkinFrontImagePath;
    QString checkinRearImagePath;
    QString checkoutFrontImagePath;
    QString checkoutRearImagePath;
    int status = 0; // 0 = đang gửi, 1 = đã ra

    static ParkingRecord fromQueryRow(const QSqlQuery &q)
    {
        ParkingRecord r;
        r.id = q.value("id").toInt();
        r.rfid = q.value("rfid").toString();
        r.plateFront = q.value("plate_front").toString();
        r.plateRear = q.value("plate_rear").toString();
        r.checkinTime = q.value("checkin_time").toLongLong();
        r.checkoutTime = q.value("checkout_time").toLongLong();
        r.checkinFrontImagePath = q.value("checkin_front_image_path").toString();
        r.checkinRearImagePath = q.value("checkin_rear_image_path").toString();
        r.checkoutFrontImagePath = q.value("checkout_front_image_path").toString();
        r.checkoutRearImagePath = q.value("checkout_rear_image_path").toString();
        r.status = q.value("status").toInt();
        return r;
    }
};

#endif // PARKINGRECORD_H
