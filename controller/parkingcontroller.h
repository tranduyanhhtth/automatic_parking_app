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
    Q_PROPERTY(QString plate READ plate NOTIFY plateChanged)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
    Q_PROPERTY(QString lastRfid READ lastRfid NOTIFY lastRfidChanged)
    Q_PROPERTY(QString checkInTime READ checkInTime NOTIFY timesChanged)
    Q_PROPERTY(QString checkOutTime READ checkOutTime NOTIFY timesChanged)
    Q_PROPERTY(int gateMode READ gateMode WRITE setGateMode NOTIFY gateModeChanged) // 0: Entrance, 1: Exit
    Q_PROPERTY(int openCount READ openCount NOTIFY openCountChanged)
public:
    explicit ParkingController(ICameraSnapshotProvider *cam,
                               IParkingRepository *db,
                               IBarrier *barrier,
                               IOcr *ocr,
                               ICardReader *reader,
                               QObject *parent = nullptr);

    QString plate() const { return m_plate; }
    QString message() const { return m_message; }
    QString lastRfid() const { return m_lastRfid; }
    QString checkInTime() const { return m_checkInTime; }
    QString checkOutTime() const { return m_checkOutTime; }
    int gateMode() const { return m_gateMode; }
    void setGateMode(int m)
    {
        if (m_gateMode != m)
        {
            m_gateMode = m;
            emit gateModeChanged();
        }
    }
    int openCount() const { return m_openCount; }

public slots:
    Q_INVOKABLE void simulateSwipe(const QString &rfid);
    Q_INVOKABLE void deleteClosed(const QString &rfid); // Xóa bản ghi đã đóng của RFID
    Q_INVOKABLE void refreshOpenCount();

signals:
    void plateChanged();
    void messageChanged();
    void lastRfidChanged();
    void timesChanged();
    void gateModeChanged();
    void openCountChanged();

private slots:
    void onRfidScanned(const QString &rfid);

private:
    ICameraSnapshotProvider *m_cam{nullptr};
    IParkingRepository *m_db{nullptr};
    IBarrier *m_barrier{nullptr};
    IOcr *m_ocr{nullptr};
    ICardReader *m_reader{nullptr};

    QString m_plate;
    QString m_message;
    QString m_lastRfid;
    QString m_checkInTime;
    QString m_checkOutTime;
    int m_gateMode = 0;
    int m_openCount = 0;
};

#endif // PARKINGCONTROLLER_H
