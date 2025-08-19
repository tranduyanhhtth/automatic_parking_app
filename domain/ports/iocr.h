#ifndef IOCR_H
#define IOCR_H
#include <QVariantMap>
#include <QByteArray>

class IOcr
{
public:
    virtual ~IOcr() = default;
    virtual QVariantMap recognizePlates(const QByteArray &front,
                                        const QByteArray &rear) = 0;
    // Tương tác với CSDL: lấy ảnh của phiên mở theo RFID, chạy OCR và cập nhật cột 'plate'.
    virtual QString processOpenSessionAndUpdatePlate(const QString &rfid) = 0;
};

#endif // IOCR_H
