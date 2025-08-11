#include "parkingcontroller.h"
#include "domain/ports/icamerasnapshotprovider.h"
#include "domain/ports/iparkingrepository.h"
#include "domain/ports/ibarrier.h"
#include "domain/ports/iocr.h"
#include "domain/ports/icardreader.h"

ParkingController::ParkingController(ICameraSnapshotProvider *cam,
                                     IParkingRepository *db,
                                     IBarrier *barrier,
                                     IOcr *ocr,
                                     ICardReader *reader,
                                     QObject *parent)
    : QObject(parent), m_cam(cam), m_db(db), m_barrier(barrier), m_ocr(ocr), m_reader(reader)
{
    if (m_reader)
        connect(m_reader, &ICardReader::rfidScanned, this, &ParkingController::onRfidScanned);
}

void ParkingController::simulateSwipe(const QString &rfid)
{
    onRfidScanned(rfid);
}

void ParkingController::onRfidScanned(const QString &rfid)
{
    if (!m_cam || !m_db || !m_barrier || !m_ocr)
        return;

    // 1) Chụp ảnh từ 2 camera
    const QByteArray front = m_cam->captureInputSnapshot(85);
    const QByteArray rear = m_cam->captureOutputSnapshot(85);

    // 2) OCR nhận dạng biển số
    const QVariantMap res = m_ocr->recognizePlates(front, rear);
    m_plateFront = res.value("front").toString();
    m_plateRear = res.value("rear").toString();
    emit plateFrontChanged();
    emit plateRearChanged();

    // 3) Giao dịch DB + điều khiển barrier
    if (!m_db->hasOpenSession(rfid))
    {
        const CheckInResult ok = m_db->checkIn(rfid, m_plateFront, m_plateRear, front, rear);
        if (ok == CheckInResult::Ok)
        {
            m_message = QStringLiteral("Đã check-in");
            m_barrier->open();
        }
        else if (ok == CheckInResult::AlreadyOpen)
        {
            m_message = QStringLiteral("Thẻ đang gửi – không thể check-in");
        }
        else
        {
            m_message = QStringLiteral("Lỗi check-in");
        }
    }
    else
    {
        const CheckOutResult match = m_db->checkOut(rfid, m_plateFront, m_plateRear, front, rear);
        if (match == CheckOutResult::OkMatched)
        {
            m_message = QStringLiteral("Khớp biển số – mở barrier");
            m_barrier->open();
        }
        else if (match == CheckOutResult::NotMatched)
        {
            m_message = QStringLiteral("Không khớp biển số – từ chối");
        }
        else if (match == CheckOutResult::NoOpen)
        {
            m_message = QStringLiteral("Không có phiên gửi đang mở");
        }
        else
        {
            m_message = QStringLiteral("Lỗi check-out");
        }
    }
    emit messageChanged();
}
