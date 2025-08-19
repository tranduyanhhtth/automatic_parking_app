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
    Q_PROPERTY(int gateMode READ gateMode WRITE setGateMode NOTIFY gateModeChanged) // 0: Cổng vào, 1: Cổng ra
    Q_PROPERTY(int openCount READ openCount NOTIFY openCountChanged)
    // mở bằng cơm
    Q_PROPERTY(QString exitImage1DataUrl READ exitImage1DataUrl NOTIFY exitReviewChanged)
    Q_PROPERTY(QString exitImage2DataUrl READ exitImage2DataUrl NOTIFY exitReviewChanged)
    Q_PROPERTY(bool exitReviewAvailable READ exitReviewAvailable NOTIFY exitReviewChanged)
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

            // Khi chuyển cổng, reset debounce để cho phép quẹt thẻ ngay lập tức
            if (auto hid = qobject_cast<QObject *>(m_reader))
                QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);

            // Khi chuyển sang CỔNG RA (1), xóa RFID trước đó để bắt buộc quẹt thẻ mới
            if (m_gateMode == 1)
            {
                if (!m_lastRfid.isEmpty())
                {
                    m_lastRfid.clear();
                    emit lastRfidChanged();
                }
            }
        }
    }
    int openCount() const { return m_openCount; }
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

signals:
    void plateChanged();
    void messageChanged();
    void lastRfidChanged();
    void timesChanged();
    void gateModeChanged();
    void openCountChanged();
    void exitReviewChanged();
    void showToast(const QString &message);

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
    // Chặn quẹt liên tiếp cùng một thẻ trong thời gian ngắn
    QString m_lastEntranceRfid;
    qint64 m_lastEntranceMs = 0;
    int m_entranceRepeatBlockMs = 1500; // 1.5s
    // mở bằng cơm
    QString m_exitImg1;
    QString m_exitImg2;

    static QString makeDataUrlFromBytes(const QByteArray &bytes, const QString &mime = QStringLiteral("image/jpeg"));
    QString normalizeRfid(const QString &r) const;
};

#endif // PARKINGCONTROLLER_H
