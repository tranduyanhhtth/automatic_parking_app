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
    // Thông tin cổng vào
    Q_PROPERTY(QString entrancePlate READ entrancePlate NOTIFY entranceInfoChanged)
    Q_PROPERTY(QString entranceTimeIn READ entranceTimeIn NOTIFY entranceInfoChanged)
    Q_PROPERTY(QString entranceCardType READ entranceCardType NOTIFY entranceInfoChanged)
    Q_PROPERTY(QString entranceCardId READ entranceCardId NOTIFY entranceInfoChanged)
    // Thông tin cổng ra
    Q_PROPERTY(QString exitPlate READ exitPlate NOTIFY exitInfoChanged)
    Q_PROPERTY(QString exitTimeIn READ exitTimeIn NOTIFY exitInfoChanged)
    Q_PROPERTY(QString exitTimeOut READ exitTimeOut NOTIFY exitInfoChanged)
    Q_PROPERTY(QString exitCardId READ exitCardId NOTIFY exitInfoChanged)
    // Thông báo tiền
    Q_PROPERTY(QString moneyMessage READ moneyMessage NOTIFY moneyMessageChanged)
    Q_PROPERTY(int gateMode READ gateMode WRITE setGateMode NOTIFY gateModeChanged) // 0: Cổng vào, 1: Cổng ra
    Q_PROPERTY(int lane READ lane WRITE setLane NOTIFY laneChanged)                 // 0: Làn 1, 1: Làn 2
    Q_PROPERTY(int openCount READ openCount NOTIFY openCountChanged)
    // Dual mode: 0 Mixed (Lane1=IN, Lane2=OUT), 1 AllEntrance, 2 AllExit
    Q_PROPERTY(int dualMode READ dualMode WRITE setDualMode NOTIFY dualModeChanged)
    // mở bằng cơm
    Q_PROPERTY(QString exitImage1DataUrl READ exitImage1DataUrl NOTIFY exitReviewChanged)
    Q_PROPERTY(QString exitImage2DataUrl READ exitImage2DataUrl NOTIFY exitReviewChanged)
    Q_PROPERTY(bool exitReviewAvailable READ exitReviewAvailable NOTIFY exitReviewChanged)
public:
    explicit ParkingController(ICameraSnapshotProvider *cam1,
                               ICameraSnapshotProvider *cam2,
                               IParkingRepository *db,
                               IBarrier *barrier1,
                               IBarrier *barrier2,
                               IOcr *ocr,
                               ICardReader *entranceReader,
                               ICardReader *exitReader,
                               QObject *parent = nullptr);

    QString plate() const { return m_plate; }
    QString message() const { return m_message; }
    QString lastRfid() const { return m_lastRfid; }
    QString checkInTime() const { return m_checkInTime; }
    QString checkOutTime() const { return m_checkOutTime; }
    int gateMode() const { return m_gateMode; }
    int lane() const { return m_lane; }
    void setGateMode(int m)
    {
        if (m_gateMode != m)
        {
            m_gateMode = m;
            emit gateModeChanged();

            // Khi chuyển cổng, reset debounce để cho phép quẹt thẻ ngay lập tức
            if (auto hid = qobject_cast<QObject *>(m_readerEntrance))
                QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
            if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
                QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);

            // Khi chuyển sang CỔNG RA (1)
            if (m_gateMode == 1)
            {
                // Xóa snapshot xem trước
                if (m_cam1)
                    m_cam1->clearSnapshots();
                if (m_cam2)
                    m_cam2->clearSnapshots();
                if (!m_lastRfid.isEmpty())
                {
                    m_lastRfid.clear();
                    emit lastRfidChanged();
                }
                if (!m_plate.isEmpty())
                {
                    m_plate.clear();
                    emit plateChanged();
                }
                if (!m_message.isEmpty())
                {
                    m_message.clear();
                    emit messageChanged();
                }
                if (!m_checkInTime.isEmpty() || !m_checkOutTime.isEmpty())
                {
                    m_checkInTime.clear();
                    m_checkOutTime.clear();
                    emit timesChanged();
                }
                if (!m_exitImg1.isEmpty() || !m_exitImg2.isEmpty())
                {
                    m_exitImg1.clear();
                    m_exitImg2.clear();
                    emit exitReviewChanged();
                }
            }
            // Khi chuyển sang CỔNG VÀO (0)
            else if (m_gateMode == 0)
            {
                // Xóa snapshot xem trước
                if (m_cam1)
                    m_cam1->clearSnapshots();
                if (m_cam2)
                    m_cam2->clearSnapshots();
                if (!m_lastRfid.isEmpty())
                {
                    m_lastRfid.clear();
                    emit lastRfidChanged();
                }
                if (!m_plate.isEmpty())
                {
                    m_plate.clear();
                    emit plateChanged();
                }
                if (!m_message.isEmpty())
                {
                    m_message.clear();
                    emit messageChanged();
                }
                if (!m_checkInTime.isEmpty() || !m_checkOutTime.isEmpty())
                {
                    m_checkInTime.clear();
                    m_checkOutTime.clear();
                    emit timesChanged();
                }
                if (!m_exitImg1.isEmpty() || !m_exitImg2.isEmpty())
                {
                    m_exitImg1.clear();
                    m_exitImg2.clear();
                    emit exitReviewChanged();
                }
            }
        }
    }
    void setLane(int l)
    {
        if (m_lane == l)
            return;
        m_lane = l;
        emit laneChanged();
        // Khi đổi làn, làm sạch UI tương tự đổi cổng
        if (m_cam1)
            m_cam1->clearSnapshots();
        if (m_cam2)
            m_cam2->clearSnapshots();
        if (!m_lastRfid.isEmpty())
        {
            m_lastRfid.clear();
            emit lastRfidChanged();
        }
        if (!m_plate.isEmpty())
        {
            m_plate.clear();
            emit plateChanged();
        }
        if (!m_message.isEmpty())
        {
            m_message.clear();
            emit messageChanged();
        }
        if (!m_checkInTime.isEmpty() || !m_checkOutTime.isEmpty())
        {
            m_checkInTime.clear();
            m_checkOutTime.clear();
            emit timesChanged();
        }
        if (!m_exitImg1.isEmpty() || !m_exitImg2.isEmpty())
        {
            m_exitImg1.clear();
            m_exitImg2.clear();
            emit exitReviewChanged();
        }
        // Reset debounce
        if (auto hid = qobject_cast<QObject *>(m_readerEntrance))
            QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
        if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
            QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);
    }
    int openCount() const { return m_openCount; }
    int dualMode() const { return m_dualMode; }
    // mở bằng cơm
    QString exitImage1DataUrl() const { return m_exitImg1; }
    QString exitImage2DataUrl() const { return m_exitImg2; }
    bool exitReviewAvailable() const { return !m_exitImg1.isEmpty() || !m_exitImg2.isEmpty(); }

public slots:
    // Tải ảnh phiên vào để bác bảo vệ so sánh
    Q_INVOKABLE void loadExitReview(const QString &rfid);
    // Nút Mở: cổng vào -> mở ngay; cổng ra -> đóng phiên theo RFID hiện tại rồi mở
    Q_INVOKABLE bool approveAndOpenBarrier();
    // Dự phòng: luôn mở barrier (không động tới DB)
    Q_INVOKABLE void manualOpenBarrier();
    Q_INVOKABLE void manualCloseBarrier();
    Q_INVOKABLE void setDualMode(int mode)
    {
        if (mode < 0 || mode > 2)
            mode = 0;
        if (m_dualMode == mode)
            return;
        m_dualMode = mode;
        emit dualModeChanged();
        // Clear transient UI and reset debounce on mode change
        if (m_cam1)
            m_cam1->clearSnapshots();
        if (m_cam2)
            m_cam2->clearSnapshots();
        if (!m_lastRfid.isEmpty())
        {
            m_lastRfid.clear();
            emit lastRfidChanged();
        }
        if (!m_plate.isEmpty())
        {
            m_plate.clear();
            emit plateChanged();
        }
        if (!m_message.isEmpty())
        {
            m_message.clear();
            emit messageChanged();
        }
        if (!m_checkInTime.isEmpty() || !m_checkOutTime.isEmpty())
        {
            m_checkInTime.clear();
            m_checkOutTime.clear();
            emit timesChanged();
        }
        if (!m_exitImg1.isEmpty() || !m_exitImg2.isEmpty())
        {
            m_exitImg1.clear();
            m_exitImg2.clear();
            emit exitReviewChanged();
        }
        if (auto hid1 = qobject_cast<QObject *>(m_readerEntrance))
            QMetaObject::invokeMethod(hid1, "resetDebounce", Qt::QueuedConnection);
        if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
            QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);
    }

signals:
    void plateChanged();
    void messageChanged();
    void lastRfidChanged();
    void timesChanged();
    void entranceInfoChanged();
    void exitInfoChanged();
    void moneyMessageChanged();
    void gateModeChanged();
    void laneChanged();
    void openCountChanged();
    void exitReviewChanged();
    void showToast(const QString &message);
    // Debug logging hook for UI HID LOG overlay
    void debugLog(const QString &message);
    void dualModeChanged();

private slots:
    void onEntranceRfidScanned(const QString &rfid);
    void onExitRfidScanned(const QString &rfid);

private:
    ICameraSnapshotProvider *m_cam1{nullptr};
    ICameraSnapshotProvider *m_cam2{nullptr};
    IParkingRepository *m_db{nullptr};
    IBarrier *m_barrier1{nullptr};
    IBarrier *m_barrier2{nullptr};
    IOcr *m_ocr{nullptr};
    ICardReader *m_readerEntrance{nullptr};
    ICardReader *m_readerExit{nullptr};

    QString m_plate;
    QString m_message;
    QString m_lastRfid;
    QString m_checkInTime;
    QString m_checkOutTime;
    int m_gateMode = 0;
    int m_lane = 0;
    int m_openCount = 0;
    int m_dualMode = 0; // 0 mixed, 1 all entrance, 2 all exit
    // Chặn quẹt liên tiếp cùng một thẻ trong thời gian ngắn
    QString m_lastEntranceRfid;
    qint64 m_lastEntranceMs = 0;
    int m_entranceRepeatBlockMs = 1500; // 1.5s
    // mở bằng cơm
    QString m_exitImg1;
    QString m_exitImg2;

    // Trạng thái hiển thị mới
    QString m_entrancePlate;
    QString m_entranceTimeIn;
    QString m_entranceCardType;
    QString m_entranceCardId;

    QString m_exitPlate;
    QString m_exitTimeIn;
    QString m_exitTimeOut;
    QString m_exitCardId;

    QString m_moneyMessage;

    static QString makeDataUrlFromBytes(const QByteArray &bytes, const QString &mime = QStringLiteral("image/jpeg"));
    QString normalizeRfid(const QString &r) const;
    inline ICameraSnapshotProvider *currentCam() const { return m_lane == 0 ? m_cam1 : m_cam2; }
    inline IBarrier *currentBarrier() const { return m_lane == 0 ? m_barrier1 : m_barrier2; }
    inline ICameraSnapshotProvider *camForLane(int lane) const { return lane == 0 ? m_cam1 : m_cam2; }
    inline IBarrier *barrierForLane(int lane) const { return lane == 0 ? m_barrier1 : m_barrier2; }
    void processEntranceRfid(const QString &normRfid, int laneIdx);
    void processExitRfid(const QString &normRfid, int laneIdx);
    // Helper cho QML
public:
    QString entrancePlate() const { return m_entrancePlate; }
    QString entranceTimeIn() const { return m_entranceTimeIn; }
    QString entranceCardType() const { return m_entranceCardType; }
    QString entranceCardId() const { return m_entranceCardId; }

    QString exitPlate() const { return m_exitPlate; }
    QString exitTimeIn() const { return m_exitTimeIn; }
    QString exitTimeOut() const { return m_exitTimeOut; }
    QString exitCardId() const { return m_exitCardId; }
    QString moneyMessage() const { return m_moneyMessage; }
};

#endif // PARKINGCONTROLLER_H
