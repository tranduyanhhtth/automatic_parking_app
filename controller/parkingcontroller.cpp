#include "parkingcontroller.h"
#include "domain/ports/icamerasnapshotprovider.h"
#include "domain/ports/iparkingrepository.h"
#include "domain/ports/ibarrier.h"
#include "domain/ports/iocr.h"
#include "domain/ports/icardreader.h"
#include "utils/io_barrier/usbrelaybarrier.h"
#include <QDateTime>
#include <QTimer>
#include <QBuffer>
#include <QRegularExpression>

ParkingController::ParkingController(ICameraSnapshotProvider *cam1,
                                     ICameraSnapshotProvider *cam2,
                                     IParkingRepository *db,
                                     IBarrier *barrier1,
                                     IBarrier *barrier2,
                                     IOcr *ocr,
                                     ICardReader *entranceReader,
                                     ICardReader *exitReader,
                                     QObject *parent)
    : QObject(parent), m_cam1(cam1), m_cam2(cam2), m_db(db), m_barrier1(barrier1), m_barrier2(barrier2), m_ocr(ocr), m_readerEntrance(entranceReader), m_readerExit(exitReader)
{
    if (m_readerEntrance)
        connect(m_readerEntrance, &ICardReader::rfidScanned, this, &ParkingController::onEntranceRfidScanned);
    if (m_readerExit)
        connect(m_readerExit, &ICardReader::rfidScanned, this, &ParkingController::onExitRfidScanned);
}

void ParkingController::onEntranceRfidScanned(const QString &rfid)
{
    const QString normRfid = normalizeRfid(rfid);
    if (!m_cam1 || !m_db || !m_barrier1)
        return; // OCR có thể tạm thời null

    // CỔNG VÀO
    if (m_db->hasOpenSession(normRfid))
    {
        m_message = QStringLiteral("Thẻ đang sử dụng");
        emit messageChanged();
        emit showToast(m_message);
        // Không cập nhật lastRfid, không chụp ảnh, không OCR
        return;
    }
    else
    {
        // Từ đây thẻ chắc chắn chưa sử dụng -> chụp ảnh hiện tại từ camera làn vào
        QByteArray img1 = m_cam1->captureInputSnapshot(85);
        QByteArray img2 = m_cam1->captureOutputSnapshot(85);
        QString detectedPlate;
        if (m_ocr)
        {
            const QVariantMap res = m_ocr->recognizePlates(img1, img2);
            const QString backend = res.value("backend").toString();
            const int fbc = res.value("frontBoxCount").toInt();
            const int rbc = res.value("rearBoxCount").toInt();
            emit showToast(QStringLiteral("OCR(%1) boxes F:%2 R:%3").arg(backend).arg(fbc).arg(rbc));
            detectedPlate = res.value("front").toString();
            if (detectedPlate.isEmpty())
                detectedPlate = res.value("rear").toString();
            if (!detectedPlate.isEmpty())
                emit showToast(QStringLiteral("OCR plate: %1").arg(detectedPlate));
            else
                emit showToast(QStringLiteral("OCR plate: (none)"));
        }

        // Cập nhật lastRfid cho UI khi thực sự tiến hành check-in
        m_lastRfid = normRfid;
        emit lastRfidChanged();

        m_plate = detectedPlate;
        emit plateChanged();
        const CheckInResult ok = m_db->checkIn(normRfid, m_plate, img1, img2);
        if (ok == CheckInResult::Ok)
        {
            emit debugLog(QStringLiteral("IN: check-in %1 -> pulse barrier1").arg(normRfid));
            m_message = QStringLiteral("Check-in thành công");
            // Set giờ vào tức thời (LOCAL) rồi đồng bộ lại từ DB nếu có
            m_checkInTime = QDateTime::currentDateTime().toString(Qt::ISODate);
            auto open = m_db->fetchOpenSession(normRfid);
            const QString dbTime = open.value("checkin_time").toString();
            if (!dbTime.isEmpty())
                m_checkInTime = dbTime;
            m_checkOutTime.clear();
            emit timesChanged();
            ++m_openCount;
            emit openCountChanged();

            // Pulse barrier1 for 1s
            if (m_barrier1)
            {
                if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier1))
                    relay->pulse(1000);
                else
                {
                    m_barrier1->open();
                    QTimer::singleShot(1000, this, [this]
                                       { if (m_barrier1) m_barrier1->close(); });
                }
                emit debugLog(QStringLiteral("IN: barrier1 pulsed 1000ms"));
            }

            // Cập nhật khối hiển thị cổng vào
            m_entrancePlate = m_plate;
            m_entranceTimeIn = m_checkInTime;
            m_entranceCardId = normRfid;
            m_entranceCardType = QStringLiteral("Vãng lai");
            emit entranceInfoChanged();
            m_moneyMessage = QStringLiteral("Cổng vào: %1 - %2").arg(m_entranceCardType, m_entranceCardId);
            emit moneyMessageChanged();
        }
        else if (ok == CheckInResult::AlreadyOpen)
        {
            m_message = QStringLiteral("Thẻ đang sử dụng");
            emit messageChanged();
            emit showToast(m_message);
        }
        else
        {
            m_message = QStringLiteral("Lỗi check-in");
        }
    }
}

void ParkingController::onExitRfidScanned(const QString &rfid)
{
    const QString normRfid = normalizeRfid(rfid);
    if (!m_cam2 || !m_db || !m_barrier2)
        return;

    // Yêu cầu quẹt thẻ để tra DB. Không quẹt -> không tương tác DB
    if (normRfid.isEmpty())
        return;

    if (!m_db->hasOpenSession(normRfid))
    {
        // Thông báo: thẻ chưa được sử dụng
        emit showToast(QStringLiteral("Thẻ chưa được sử dụng"));
        return;
    }
    // Có phiên mở -> nhận dạng từ CAMERA HIỆN TẠI (nếu có OCR) để THÔNG BÁO
    m_lastRfid = normRfid;
    emit lastRfidChanged();
    // Nạp ảnh DB để UI review (ảnh lúc check-in)
    loadExitReview(normRfid);
    // Nếu có OCR: nhận dạng để thông báo (không chặn barrier)
    if (m_ocr)
    {
        QVariantMap full = m_db->fetchFullOpenSession(normRfid);
        const QString storedPlate = full.value("plate").toString();
        auto normalizePlate = [](QString p)
        {
            p = p.toUpper();
            p.remove(QRegularExpression("[^A-Z0-9]"));
            return p;
        };
        QString ocrPlate;
        {
            QByteArray live1 = m_cam2->captureInputSnapshot(85);
            QByteArray live2 = m_cam2->captureOutputSnapshot(85);
            const QVariantMap res = m_ocr->recognizePlates(live1, live2);
            const QString backend = res.value("backend").toString();
            const int fbc = res.value("frontBoxCount").toInt();
            const int rbc = res.value("rearBoxCount").toInt();
            emit showToast(QStringLiteral("OCR(%1) boxes F:%2 R:%3").arg(backend).arg(fbc).arg(rbc));
            ocrPlate = res.value("front").toString();
            if (ocrPlate.isEmpty())
                ocrPlate = res.value("rear").toString();
            if (ocrPlate.isEmpty())
                ocrPlate = QStringLiteral("unknown");
            else
                emit showToast(QStringLiteral("OCR plate: %1").arg(ocrPlate));
        }

        const QString a = normalizePlate(storedPlate);
        const QString b = normalizePlate(ocrPlate);
        if (!a.isEmpty() && !b.isEmpty() && a == b)
            emit showToast(QStringLiteral("Biển số khớp: %1").arg(ocrPlate));
        else
            emit showToast(QStringLiteral("Biển số không khớp"));
    }

    // Lấy thông tin phiên đang mở trước khi checkout (tránh mất dữ liệu sau khi xóa)
    QVariantMap openBefore = m_db->fetchFullOpenSession(normRfid);
    const QString plateBefore = openBefore.value("plate").toString();
    const QString checkinBefore = openBefore.value("checkin_time").toString();

    // Luôn quyết định theo RFID (không phụ thuộc UI gate mode):
    // 1) checkout trong DB, 2) xóa theo RFID để giải phóng thẻ, 3) mở barrier2 (xung)
    QString coTime;
    const CheckOutResult r = m_db->checkOutRfidOnly(normRfid, &coTime);
    if (r == CheckOutResult::OkMatched)
    {
        // cập nhật thời gian ra theo DB
        m_checkOutTime = coTime;
        emit timesChanged();

        // xóa các phiên đã đóng theo RFID để giải phóng thẻ cho lần sau
        m_db->deleteClosedSessions(normRfid);

        // mở barrier cổng ra (barrier2) rồi đóng ngay (xung ngắn)
        if (m_barrier2)
        {
            emit debugLog(QStringLiteral("OUT: pulse barrier2 500ms"));
            if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier2))
                relay->pulse(500);
            else
            {
                m_barrier2->open();
                QTimer::singleShot(500, this, [this]
                                   { if (m_barrier2) m_barrier2->close(); });
            }
        }

        // Thông điệp UI + cập nhật khối Cổng ra (dùng dữ liệu trước checkout)
        m_message = QStringLiteral("Check-out thành công");
        emit messageChanged();
        emit showToast(QStringLiteral("Kết thúc phiên"));

        m_exitCardId = normRfid;
        m_exitPlate = plateBefore;
        m_exitTimeIn = checkinBefore;
        m_exitTimeOut = QDateTime::currentDateTime().toString(Qt::ISODate);
        emit exitInfoChanged();

        QDateTime tin = QDateTime::fromString(m_exitTimeIn, Qt::ISODate);
        QDateTime tout = QDateTime::fromString(m_exitTimeOut, Qt::ISODate);
        qint64 mins = qMax<qint64>(1, tin.secsTo(tout) / 60);
        qint64 hours = (mins + 59) / 60;
        qint64 fee = qMax<qint64>(5000, hours * 5000);
        m_moneyMessage = QStringLiteral("Cổng ra: Thu phí %1 VND (ước tính)").arg(fee);
        emit moneyMessageChanged();

        if (auto hid1 = qobject_cast<QObject *>(m_readerEntrance))
            QMetaObject::invokeMethod(hid1, "resetDebounce", Qt::QueuedConnection);
        if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
            QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);
    }
    else
    {
        m_message = QStringLiteral("Lỗi check-out");
        emit messageChanged();
    }
}

QString ParkingController::makeDataUrlFromBytes(const QByteArray &bytes, const QString &mime)
{
    if (bytes.isEmpty())
        return {};
    QByteArray b64 = bytes.toBase64();
    return QStringLiteral("data:%1;base64,%2").arg(mime, QString::fromLatin1(b64));
}

void ParkingController::loadExitReview(const QString &rfid)
{
    if (!m_db)
        return;
    auto m = m_db->fetchFullOpenSession(normalizeRfid(rfid));
    if (m.isEmpty())
    {
        m_exitImg1.clear();
        m_exitImg2.clear();
        emit exitReviewChanged();
        return;
    }
    QByteArray img1 = m.value("image1").toByteArray();
    QByteArray img2 = m.value("image2").toByteArray();
    m_exitImg1 = makeDataUrlFromBytes(img1);
    m_exitImg2 = makeDataUrlFromBytes(img2);
    emit exitReviewChanged();
    const QString dbPlate = m.value("plate").toString();
    if (!dbPlate.isEmpty() && dbPlate != m_plate)
    {
        m_plate = dbPlate;
        emit plateChanged();
    }
    m_checkInTime = m.value("checkin_time").toString();
    emit timesChanged();
}

bool ParkingController::approveAndOpenBarrier()
{
    if (!currentBarrier())
        return false;
    if (m_gateMode == 0)
    {
        // Cổng vào luôn dùng barrier1
        if (m_barrier1)
        {
            emit debugLog(QStringLiteral("IN: manual open -> pulse barrier1"));
            if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier1))
                relay->pulse(1000);
            else
            {
                m_barrier1->open();
                QTimer::singleShot(1000, this, [this]
                                   { if (m_barrier1) m_barrier1->close(); });
            }
            emit debugLog(QStringLiteral("IN: barrier1 pulsed 1000ms"));
            return true;
        }
        // Đóng ngay sau khi mở (xung ngắn)
        return false;
    }
    // Cổng ra: bắt buộc thẻ có trong DB
    if (m_lastRfid.isEmpty() || !m_db)
        return false;
    if (!m_db->hasOpenSession(normalizeRfid(m_lastRfid)))
    {
        emit showToast(QStringLiteral("Thẻ chưa được sử dụng"));
        return false;
    }
    QString coTime;
    const CheckOutResult r = m_db->checkOutRfidOnly(normalizeRfid(m_lastRfid), &coTime);
    if (r == CheckOutResult::OkMatched)
    {
        m_checkOutTime = coTime;
        emit timesChanged();
        m_db->deleteClosedSessions(normalizeRfid(m_lastRfid));
        // Cổng ra luôn dùng barrier2
        if (m_barrier2)
        {
            emit debugLog(QStringLiteral("OUT: pulse barrier2 500ms"));
            if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier2))
                relay->pulse(500);
            else
            {
                m_barrier2->open();
                QTimer::singleShot(500, this, [this]
                                   { if (m_barrier2) m_barrier2->close(); });
            }
        }
        if (auto hid1 = qobject_cast<QObject *>(m_readerEntrance))
            QMetaObject::invokeMethod(hid1, "resetDebounce", Qt::QueuedConnection);
        if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
            QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);
        return true;
    }
    return false;
}

void ParkingController::manualOpenBarrier()
{
    // Mở theo cổng hiện hành: 0 -> barrier1, 1 -> barrier2
    if (m_gateMode == 0)
    {
        if (m_barrier1)
        {
            emit debugLog(QStringLiteral("IN: manualOpen -> pulse barrier1 500ms"));
            if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier1))
                relay->pulse(500);
            else
            {
                m_barrier1->open();
                QTimer::singleShot(500, this, [this]
                                   { if (m_barrier1) m_barrier1->close(); });
            }
        }
    }
    else
    {
        if (m_barrier2)
        {
            emit debugLog(QStringLiteral("OUT: manualOpen -> pulse barrier2 500ms"));
            if (auto relay = dynamic_cast<UsbRelayBarrier *>(m_barrier2))
                relay->pulse(500);
            else
            {
                m_barrier2->open();
                QTimer::singleShot(500, this, [this]
                                   { if (m_barrier2) m_barrier2->close(); });
            }
        }
    }
}

void ParkingController::manualCloseBarrier()
{
    if (currentBarrier())
        currentBarrier()->close();
}

QString ParkingController::normalizeRfid(const QString &r) const
{
    static const QRegularExpression kReLeadingNonAlnum(QStringLiteral("^[^A-Za-z0-9]+"));
    static const QRegularExpression kReTrailingNonAlnum(QStringLiteral("[^A-Za-z0-9]+$"));
    static const QRegularExpression kReWhitespace(QStringLiteral("\\s+"));
    static const QRegularExpression kReDigitsOnly(QStringLiteral("^[0-9]+$"));

    QString s = r.trimmed();
    // Bỏ các ký tự dẫn/đuôi không phải chữ-số (ví dụ ';', '%', '?')
    s.remove(kReLeadingNonAlnum);
    s.remove(kReTrailingNonAlnum);
    // Xóa khoảng trắng giữa chừng nếu có và chuẩn hóa HOA
    s.remove(kReWhitespace);
    s = s.toUpper();
    // Nếu toàn là số và dài hơn 10, lấy 10 số cuối (loại bỏ facility/site code ở đầu)
    if (kReDigitsOnly.match(s).hasMatch() && s.size() > 10)
        s = s.right(10);
    return s;
}
