#include "parkingcontroller.h"
#include "domain/ports/icamerasnapshotprovider.h"
#include "domain/ports/iparkingrepository.h"
#include "domain/ports/ibarrier.h"
#include "domain/ports/iocr.h"
#include "domain/ports/icardreader.h"
#include <QDateTime>
#include <QBuffer>
#include <QRegularExpression>

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

void ParkingController::onRfidScanned(const QString &rfid)
{
    const QString normRfid = normalizeRfid(rfid);
    // Log mapping nếu có thay đổi để dễ chẩn đoán (ví dụ reader thêm site code '65')
    if (m_reader && normRfid != rfid)
    {
        if (auto hid = qobject_cast<QObject *>(m_reader))
        {
            const QString msg = QStringLiteral("[HID] RFID raw '%1' -> normalized '%2'").arg(rfid, normRfid);
            QMetaObject::invokeMethod(hid, "debugLog", Qt::QueuedConnection, Q_ARG(QString, msg));
        }
    }
    // Cổng ra: chỉ cập nhật lastRfid khi thẻ có phiên mở; cổng vào cập nhật khi check-in hợp lệ
    if (!m_cam || !m_db || !m_barrier)
        return; // OCR có thể tạm thời null

    // Giao dịch DB + điều khiển barrier
    if (m_gateMode == 0) // Cổng vào
    {
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
            // Từ đây thẻ chắc chắn chưa sử dụng -> tiến hành chụp ảnh và OCR
            QByteArray img1 = m_cam->captureInputSnapshot(85);
            QByteArray img2 = m_cam->captureOutputSnapshot(85);
            QString detectedPlate;
            // if (m_ocr)
            // {
            //     const QVariantMap res = m_ocr->recognizePlates(img1, img2);
            //     detectedPlate = res.value("front").toString();
            //     if (detectedPlate.isEmpty())
            //         detectedPlate = res.value("rear").toString();
            //     // HID log OCR ở cổng vào
            //     if (auto hid = qobject_cast<QObject *>(m_reader))
            //     {
            //         const QString msg = QStringLiteral("[HID] OCR entrance RFID %1 -> plate: %2")
            //                                 .arg(normRfid, detectedPlate.isEmpty() ? QStringLiteral("(none)") : detectedPlate);
            //         QMetaObject::invokeMethod(hid, "debugLog", Qt::QueuedConnection, Q_ARG(QString, msg));
            //     }
            // }

            // Cập nhật lastRfid cho UI khi thực sự tiến hành check-in
            m_lastRfid = normRfid;
            emit lastRfidChanged();

            m_plate = detectedPlate;
            emit plateChanged();
            const CheckInResult ok = m_db->checkIn(normRfid, m_plate, img1, img2);
            if (ok == CheckInResult::Ok)
            {
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

                // Sau check-in, cập nhật plate bằng OCR nếu có; nếu trống -> "unknown"
                if (m_ocr)
                {
                    QString plateText = detectedPlate;
                    if (plateText.isEmpty())
                    {
                        // Chạy lại trên ảnh DB để nhất quán
                        const QString updated = m_ocr->processOpenSessionAndUpdatePlate(normRfid);
                        plateText = updated;
                    }
                    if (plateText.isEmpty())
                        plateText = QStringLiteral("unknown");
                    if (plateText != m_plate)
                    {
                        m_plate = plateText;
                        emit plateChanged();
                    }
                    if (auto hid = qobject_cast<QObject *>(m_reader))
                    {
                        const QString msg = QStringLiteral("[HID] Check-in OCR RFID %1 -> plate: %2").arg(normRfid, m_plate);
                        QMetaObject::invokeMethod(hid, "debugLog", Qt::QueuedConnection, Q_ARG(QString, msg));
                    }
                }
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
    else // Cổng ra
    {
        // Yêu cầu quẹt thẻ để tra DB. Không quẹt -> không tương tác DB
        if (normRfid.isEmpty())
            return;

        if (!m_db->hasOpenSession(normRfid))
        {
            // // Không tạo phiên mới tại cổng ra; dọn hiển thị
            // m_exitImg1.clear();
            // m_exitImg2.clear();
            // emit exitReviewChanged();
            // m_checkInTime.clear();
            // m_checkOutTime.clear();
            // emit timesChanged();
            // m_plate.clear();
            // emit plateChanged();
            // m_lastRfid.clear();
            // emit lastRfidChanged();
            // Thông báo: thẻ chưa được được sử dụng
            emit showToast(QStringLiteral("Thẻ chưa được được sử dụng"));
            // Cho phép quẹt lại ngay
            if (auto hid = qobject_cast<QObject *>(m_reader))
                QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
            return;
        }
        /***************************************************************************************************/
        // // Có phiên mở -> so khớp bằng AI từ CAMERA HIỆN TẠI
        // // (Nạp ảnh DB để review UI nếu muốn)
        // loadExitReview(normRfid);

        // QVariantMap full = m_db->fetchFullOpenSession(normRfid);
        // const QString storedPlate = full.value("plate").toString();
        // QString ocrPlate;
        // if (m_ocr)
        // {
        //     // Chụp ảnh hiện tại từ camera
        //     QByteArray live1 = m_cam->captureInputSnapshot(85);
        //     QByteArray live2 = m_cam->captureOutputSnapshot(85);
        //     const QVariantMap res = m_ocr->recognizePlates(live1, live2);
        //     ocrPlate = res.value("front").toString();
        //     if (ocrPlate.isEmpty())
        //         ocrPlate = res.value("rear").toString();
        //     if (ocrPlate.isEmpty())
        //         ocrPlate = QStringLiteral("unknown");
        // }

        // // HID log kết quả so khớp
        // if (auto hid = qobject_cast<QObject *>(m_reader))
        // {
        //     const QString msg = QStringLiteral("[HID] Exit RFID %1 -> stored: %2 | ocr: %3")
        //                             .arg(normRfid,
        //                                  storedPlate.isEmpty() ? QStringLiteral("(none)") : storedPlate,
        //                                  ocrPlate.isEmpty() ? QStringLiteral("(none)") : ocrPlate);
        //     QMetaObject::invokeMethod(hid, "debugLog", Qt::QueuedConnection, Q_ARG(QString, msg));
        // }

        // if (!storedPlate.isEmpty() && !ocrPlate.isEmpty() && storedPlate.compare(ocrPlate, Qt::CaseInsensitive) == 0)
        // {
        //     emit showToast(QStringLiteral("Biển số khớp: %1").arg(ocrPlate));
        //     QString checkoutTime;
        //     const CheckOutResult r = m_db->checkOutRfidOnly(normRfid, &checkoutTime);
        //     if (r == CheckOutResult::OkMatched)
        //     {
        //         m_message = QStringLiteral("Check-out thành công");
        //         if (checkoutTime.isEmpty())
        //             checkoutTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        //         m_checkOutTime = checkoutTime;
        //         emit timesChanged();
        //         // Giải phóng để tái sử dụng thẻ: xóa/cleanup các phiên đã đóng
        //         m_db->deleteClosedSessions(normRfid);
        //         // Cho phép quẹt lại ngay: reset debounce
        //         if (auto hid = qobject_cast<QObject *>(m_reader))
        //             QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
        //     }
        // }
        // else
        // {
        //     m_message = QStringLiteral("Biển số không khớp");
        //     emit messageChanged();
        //     return;
        // }
        /***************************************************************************************************/
        // Có phiên mở -> cập nhật lastRfid và nạp ảnh DB để review UI
        m_lastRfid = normRfid;
        emit lastRfidChanged();
        loadExitReview(normRfid);

        // Kết thúc phiên theo RFID ngay lập tức
        QString checkoutTime;
        const CheckOutResult r = m_db->checkOutRfidOnly(normRfid, &checkoutTime);
        if (r == CheckOutResult::OkMatched)
        {
            m_message = QStringLiteral("Check-out thành công");
            if (checkoutTime.isEmpty())
                checkoutTime = QDateTime::currentDateTime().toString(Qt::ISODate);
            m_checkOutTime = checkoutTime;
            emit timesChanged();

            // Giải phóng để tái sử dụng thẻ: xóa/cleanup các phiên đã đóng
            m_db->deleteClosedSessions(normRfid);

            emit showToast(QStringLiteral("Kết thúc phiên"));

            // HID thông báo checkout theo RFID
            if (auto hid = qobject_cast<QObject *>(m_reader))
            {
                const QString msg = QStringLiteral("[HID] Exit RFID %1 -> checkout by RFID").arg(normRfid);
                QMetaObject::invokeMethod(hid, "debugLog", Qt::QueuedConnection, Q_ARG(QString, msg));
                QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
            }
        }
        else
        {
            m_message = QStringLiteral("Lỗi check-out");
            emit messageChanged();
        }
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
    if (!m_barrier)
        return false;
    if (m_gateMode == 0)
    {
        m_barrier->open();
        return true;
    }
    // Cổng ra: bắt buộc thẻ có trong DB
    if (m_lastRfid.isEmpty() || !m_db)
        return false;
    if (!m_db->hasOpenSession(normalizeRfid(m_lastRfid)))
    {
        emit showToast(QStringLiteral("Thẻ chưa được được sử dụng"));
        return false;
    }
    QString coTime;
    const CheckOutResult r = m_db->checkOutRfidOnly(normalizeRfid(m_lastRfid), &coTime);
    if (r == CheckOutResult::OkMatched)
    {
        m_checkOutTime = coTime;
        emit timesChanged();
        m_db->deleteClosedSessions(normalizeRfid(m_lastRfid));
        m_barrier->open();
        if (auto hid = qobject_cast<QObject *>(m_reader))
            QMetaObject::invokeMethod(hid, "resetDebounce", Qt::QueuedConnection);
        return true;
    }
    return false;
}

void ParkingController::manualOpenBarrier()
{
    if (m_barrier)
        m_barrier->open();
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
