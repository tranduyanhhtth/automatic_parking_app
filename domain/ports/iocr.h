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
};

#endif // IOCR_H
