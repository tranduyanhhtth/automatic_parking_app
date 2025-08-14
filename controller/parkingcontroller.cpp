#include "parkingcontroller.h"
#include "domain/ports/icamerasnapshotprovider.h"
#include "domain/ports/iparkingrepository.h"
#include "domain/ports/ibarrier.h"
#include "domain/ports/iocr.h"
#include "domain/ports/icardreader.h"
#include <QDateTime>

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

void ParkingController::deleteClosed(const QString &rfid)
{
    if (!m_db)
        return;
    if (rfid.isEmpty())
        return;
    if (m_db->deleteClosedSessions(rfid))
    {
        m_message = QStringLiteral("Đã xóa phiên đã đóng");
        emit messageChanged();
        refreshOpenCount();
    }
    else
    {
        m_message = QStringLiteral("Xóa thất bại");
        emit messageChanged();
    }
}

void ParkingController::refreshOpenCount()
{
    // Đếm số phiên mở: tạm query đơn giản
    if (!m_db)
        return;
    // Không có API riêng: tái sử dụng hasOpenSession cho lastRfid (1 hoặc 0)
    int cnt = 0;
    if (!m_lastRfid.isEmpty() && m_db->hasOpenSession(m_lastRfid))
        cnt = 1;
    if (cnt != m_openCount)
    {
        m_openCount = cnt;
        emit openCountChanged();
    }
}

void ParkingController::onRfidScanned(const QString &rfid)
{
    if (!m_cam || !m_db || !m_barrier)
        return; // OCR có thể tạm thời null nếu chưa tích hợp, barrier cần cho mở

    // 1) Chụp ảnh từ 2 camera
    const QByteArray img1 = m_cam->captureInputSnapshot(85);
    const QByteArray img2 = m_cam->captureOutputSnapshot(85);

    // 2) OCR (nếu đã cấu hình) nhận dạng biển số; nếu chưa, để chuỗi rỗng
    QString detectedPlate;
    if (m_ocr)
    {
        const QVariantMap res = m_ocr->recognizePlates(img1, img2);
        detectedPlate = res.value("front").toString();
        if (detectedPlate.isEmpty())
            detectedPlate = res.value("rear").toString();
    }

    // 3) Giao dịch DB + điều khiển barrier
    if (m_gateMode == 0) // Cổng vào: tạo phiên mới nếu chưa có
    {
        if (m_db->hasOpenSession(rfid))
        {
            m_message = QStringLiteral("Thẻ đã vào – chưa ra");
        }
        else
        {
            m_plate = detectedPlate;
            emit plateChanged();
            const CheckInResult ok = m_db->checkIn(rfid, m_plate, img1, img2);
            if (ok == CheckInResult::Ok)
            {
                m_message = QStringLiteral("Check-in thành công");
                // Lấy thời gian vào
                auto open = m_db->fetchOpenSession(rfid);
                m_checkInTime = open.value("checking_time").toString();
                m_checkOutTime.clear();
                emit timesChanged();
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
    }
    else
    {
        // Cổng ra: so khớp plate (nếu có) qua OCR; nếu OCR chưa có -> chỉ so RFID
        m_plate = detectedPlate;
        emit plateChanged();
        QString checkoutTime;
        CheckOutResult match;
        if (!detectedPlate.isEmpty())
        {
            match = m_db->checkOut(rfid, detectedPlate);
        }
        else
        {
            match = m_db->checkOut(rfid, QString()); // plate rỗng sẽ không khớp: fallback RFID-only
            if (match == CheckOutResult::NotMatched)
            {
                // RFID-only fallback (giữ lịch sử so khớp plate sau này)
                match = m_db->checkOutRfidOnly(rfid, &checkoutTime);
            }
        }
        if (match == CheckOutResult::OkMatched)
        {
            m_message = QStringLiteral("Check-out thành công");
            if (checkoutTime.isEmpty())
                checkoutTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
            m_checkOutTime = checkoutTime;
            emit timesChanged();
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
    refreshOpenCount();
}
