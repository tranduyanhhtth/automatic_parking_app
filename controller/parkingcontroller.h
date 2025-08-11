#ifndef PARKINGCONTROLLER_H
#define PARKINGCONTROLLER_H

#include <QObject>
#include <QString>
#include <QByteArray>
#include <QVariantMap>
#include "domain/ports/icamerasnapshotprovider.h"
#include "domain/ports/iparkingrepository.h"
#include "domain/ports/ibarrier.h"
#include "domain/ports/iocr.h"
#include "domain/ports/icardreader.h"

class CameraManager;
class DatabaseManager;
class BarrierController;
class OCRProcessor;
class CardReader;

// Application Layer: điều phối luồng nghiệp vụ check-in/check-out
class ParkingController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString plateFront READ plateFront NOTIFY plateFrontChanged)
    Q_PROPERTY(QString plateRear READ plateRear NOTIFY plateRearChanged)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
public:
    explicit ParkingController(ICameraSnapshotProvider *cam,
                               IParkingRepository *db,
                               IBarrier *barrier,
                               IOcr *ocr,
                               ICardReader *reader,
                               QObject *parent = nullptr);

    QString plateFront() const { return m_plateFront; }
    QString plateRear() const { return m_plateRear; }
    QString message() const { return m_message; }

public slots:
    Q_INVOKABLE void simulateSwipe(const QString &rfid);

signals:
    void plateFrontChanged();
    void plateRearChanged();
    void messageChanged();

private slots:
    void onRfidScanned(const QString &rfid);

private:
    ICameraSnapshotProvider *m_cam{nullptr};
    IParkingRepository *m_db{nullptr};
    IBarrier *m_barrier{nullptr};
    IOcr *m_ocr{nullptr};
    ICardReader *m_reader{nullptr};

    QString m_plateFront;
    QString m_plateRear;
    QString m_message;
};

#endif // PARKINGCONTROLLER_H
