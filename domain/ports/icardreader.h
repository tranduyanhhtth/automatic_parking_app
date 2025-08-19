#ifndef ICARDREADER_H
#define ICARDREADER_H
#include <QObject>
#include <QString>

class ICardReader : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    virtual ~ICardReader() = default;

signals:
    void rfidScanned(const QString &rfid);
};

#endif // ICARDREADER_H
