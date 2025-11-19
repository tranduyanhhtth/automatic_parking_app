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
#include <QVariant>
#include <QMetaObject>
#include <QLocale>
#include <QStringList>

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
    m_laneMoneyMessages.fill({});
    m_lanePreviewInput.fill({});
    m_lanePreviewOutput.fill({});
    m_laneSessionIds.fill(-1);
    m_laneTicketTypes.fill({});
    m_laneHasSubscriptions.fill(false);
    m_laneCardIds.fill({});
    m_feeUpdateTimer.setInterval(15000);
    m_feeUpdateTimer.setSingleShot(false);
    connect(&m_feeUpdateTimer, &QTimer::timeout, this, &ParkingController::refreshLiveFees);
    m_feeUpdateTimer.start();
    setLaneMoneyMessage(0, defaultLaneMessage(0));
    setLaneMoneyMessage(1, defaultLaneMessage(1));
    if (m_readerEntrance)
        connect(m_readerEntrance, &ICardReader::rfidScanned, this, &ParkingController::onEntranceRfidScanned);
    if (m_readerExit)
        connect(m_readerExit, &ICardReader::rfidScanned, this, &ParkingController::onExitRfidScanned);
}

void ParkingController::onEntranceRfidScanned(const QString &rfid)
{
    const QString normRfid = normalizeRfid(rfid);
    if (!m_db)
        return;
    // Route depending on dualMode: in AllExit, treat as OUT on lane 0; in AllEntrance, treat as IN on lane 0; Mixed -> lane 0 IN
    if (m_dualMode == 2)
    {
        processExitRfid(normRfid, 0);
        return;
    }
    const int laneIdx = (m_dualMode == 1 ? 0 : 0); // all entrance -> lane 0, mixed -> lane 0
    processEntranceRfid(normRfid, laneIdx);
}

void ParkingController::processEntranceRfid(const QString &normRfid, int laneIdx)
{
    clearLaneState(laneIdx);
    if (!m_db)
        return;
    // Require RFID to be registered in rfid_cards (short-term cards are allowed without user/subscription)
    auto getCard = [this](const QString &code) -> QVariantMap
    {
        QObject *dbObj = dynamic_cast<QObject *>(m_db);
        if (!dbObj)
            return {};
        QVariantMap ret;
        bool ok = QMetaObject::invokeMethod(dbObj, "getRfidCard",
                                            Q_RETURN_ARG(QVariantMap, ret),
                                            Q_ARG(QString, code));
        return ok ? ret : QVariantMap{};
    };
    const QVariantMap card = getCard(normRfid);
    if (card.isEmpty())
    {
        m_message = QStringLiteral("Thẻ chưa đăng ký trong hệ thống");
        emit messageChanged();
        emit showToast(m_message);
        return;
    }
    if (m_db->hasOpenSession(normRfid))
    {
        m_message = QStringLiteral("Thẻ đang sử dụng");
        emit messageChanged();
        emit showToast(m_message);
        return;
    }
    else
    {
        ICameraSnapshotProvider *cam = camForLane(laneIdx);
        IBarrier *bar = barrierForLane(laneIdx);
        if (!cam || !bar)
            return;
        QByteArray img1 = cam->captureInputSnapshot(85);
        QByteArray img2 = cam->captureOutputSnapshot(85);
        QString detectedPlate;
        QByteArray ann1, ann2;
        // OCR/YOLO temporarily disabled
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
        // }        // Always update entrance preview with raw images
        const QString preview1 = makeDataUrlFromBytes(img1);
        const QString preview2 = makeDataUrlFromBytes(img2);
        setLanePreview(laneIdx, preview1, preview2);

        // Cập nhật lastRfid cho UI khi thực sự tiến hành check-in
        m_lastRfid = normRfid;
        emit lastRfidChanged();

        m_plate = detectedPlate;
        emit plateChanged();
        const QByteArray store1 = img1;
        const QByteArray store2 = img2;
        const CheckInResult ok = m_db->checkIn(normRfid, m_plate, store1, store2);
        if (ok == CheckInResult::Ok)
        {
            emit debugLog(QStringLiteral("IN: check-in %1 -> pulse barrier(L%2)").arg(normRfid).arg(laneIdx + 1));
            m_message = QStringLiteral("Check-in thành công");
            // Set giờ vào tức thời (LOCAL) rồi đồng bộ lại từ DB nếu có
            m_checkInTime = QDateTime::currentDateTime().toString(Qt::ISODate);
            auto openSession = m_db->fetchOpenSession(normRfid);
            const QString dbTime = openSession.value("checkin_time").toString();
            if (!dbTime.isEmpty())
                m_checkInTime = dbTime;
            m_checkOutTime.clear();
            emit timesChanged();
            ++m_openCount;
            emit openCountChanged();

            if (bar)
            {
                if (auto relay = dynamic_cast<UsbRelayBarrier *>(bar))
                    relay->pulse(1000);
                else
                {
                    bar->open();
                    QTimer::singleShot(1000, this, [this, laneIdx]
                                       { if (auto b = barrierForLane(laneIdx)) b->close(); });
                }
                emit debugLog(QStringLiteral("IN: barrier(L%1) pulsed 1000ms").arg(laneIdx + 1));
            }

            // Cập nhật khối hiển thị cổng vào
            m_entrancePlate = m_plate;
            m_entranceTimeIn = m_checkInTime;
            m_entranceCardId = normRfid;
            // Set card type from registration (hourly/daily_day/daily_night/overnight/etc.)
            m_entranceCardType = card.value(QStringLiteral("ticket_type")).toString();
            emit entranceInfoChanged();
            m_laneCardIds[laneIdx] = normRfid;
            m_laneTicketTypes[laneIdx] = m_entranceCardType;
            const QVariantMap openInfo = m_db->fetchOpenSession(normRfid);
            const int sessionId = openInfo.value(QStringLiteral("id")).toInt();
            m_laneSessionIds[laneIdx] = (sessionId > 0) ? sessionId : -1;
            bool hasSubscription = false;
            {
                QObject *dbObj = dynamic_cast<QObject *>(m_db);
                if (dbObj)
                {
                    bool ans = false;
                    const bool okInvoke = QMetaObject::invokeMethod(dbObj, "hasActiveSubscription",
                                                                    Q_RETURN_ARG(bool, ans),
                                                                    Q_ARG(QString, normRfid),
                                                                    Q_ARG(QString, m_plate),
                                                                    Q_ARG(QString, QString()));
                    Q_UNUSED(okInvoke);
                    hasSubscription = ans;
                }
            }
            m_laneHasSubscriptions[laneIdx] = hasSubscription;
            if (hasSubscription)
            {
                setLaneMoneyMessage(laneIdx, QStringLiteral("%1: Vé đăng ký - không thu phí").arg(laneLabel(laneIdx)));
            }
            else
            {
                const int fee = computeFeeForSessionNow(sessionId);
                setLaneMoneyMessage(laneIdx, formatLaneFeeMessage(laneIdx, fee));
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
            emit messageChanged();
            setLaneMoneyMessage(laneIdx, QString());
        }
    }
}

// [NEW] Implementation - 18/11
void ParkingController::updateManualPlate(int laneIdx, const QString &newPlate)
{
    QString upperPlate = normalizeRfid(newPlate); // Reuse normalize for uppercase/trim

    // Determine if this lane is currently acting as Entrance or Exit
    // Based on dualMode and laneIdx logic:
    // Mode 0 (Mixed): Lane 0 = IN, Lane 1 = OUT
    // Mode 1 (All In): Lane 0 = IN, Lane 1 = IN
    // Mode 2 (All Out): Lane 0 = OUT, Lane 1 = OUT

    bool isEntrance = false;
    if (m_dualMode == 0) isEntrance = (laneIdx == 0);
    else if (m_dualMode == 1) isEntrance = true;
    else if (m_dualMode == 2) isEntrance = false;

    // Update operational variable used for CheckIn/CheckOut calls
    m_plate = upperPlate;
    emit plateChanged();

    if (isEntrance) {
        m_entrancePlate = upperPlate;
        emit entranceInfoChanged();
    } else {
        m_exitPlate = upperPlate;
        emit exitInfoChanged();
    }

    emit debugLog(QStringLiteral("Manual Plate Update (L%1): %2")
                      .arg(laneIdx + 1)
                      .arg(upperPlate));
    }

void ParkingController::onExitRfidScanned(const QString &rfid)
{
    const QString normRfid = normalizeRfid(rfid);
    if (!m_db)
        return;
    if (m_dualMode == 1)
    {
        // AllEntrance: exit reader acts as entrance for lane 1
        processEntranceRfid(normRfid, 1);
        return;
    }
    const int laneIdx = (m_dualMode == 2 ? 1 : 1); // all exit -> lane 1, mixed -> lane 1
    processExitRfid(normRfid, laneIdx);
}

void ParkingController::processExitRfid(const QString &normRfid, int laneIdx)
{
    clearLaneState(laneIdx);
    if (!m_db) return;
    if (normRfid.isEmpty()) return;

    m_activeExitLane = laneIdx;
    if (!m_db->hasOpenSession(normRfid)) {
        emit showToast(QStringLiteral("Thẻ chưa được sử dụng"));
        return;
    }

    m_lastRfid = normRfid;
    emit lastRfidChanged();
    loadExitReview(normRfid);

    QVariantMap openBefore = m_db->fetchFullOpenSession(normRfid);
    const QString plateBefore = openBefore.value("plate").toString();
    const int sessionId = openBefore.value("id").toInt();

    // Determine if the user has a subscription
    bool hasSubscription = m_db->hasActiveSubscription(normRfid, plateBefore, QString());

    // Compute the fee
    int fee = 0;
    if (!hasSubscription && sessionId > 0) {
        fee = m_db->computeFeeForSession(sessionId, QDateTime::currentDateTime().toString(Qt::ISODate), false);
    }

    if (fee > 0) {
        // If there's a fee, emit signal to QML to show the payment dialog
        emit checkoutRequiresPayment(normRfid, plateBefore, fee);
    } else {
        // If no fee (or subscription), checkout immediately
        QString paymentNote = hasSubscription ? "Vé tháng" : "Miễn phí";
        completeCheckout(normRfid, plateBefore, paymentNote, fee);
    }
}
//     const int sessionId = openBefore.value("id").toInt();
//     // Resolve card for pricing hint
//     auto getCard = [this](const QString &code) -> QVariantMap
//     {
//         QObject *dbObj = dynamic_cast<QObject *>(m_db);
//         if (!dbObj)
//             return {};
//         QVariantMap ret;
//         bool ok = QMetaObject::invokeMethod(dbObj, "getRfidCard",
//                                             Q_RETURN_ARG(QVariantMap, ret),
//                                             Q_ARG(QString, code));
//         return ok ? ret : QVariantMap{};
//     };
//     const QVariantMap card = getCard(normRfid);
//     // Helper: check active subscription for this card/plate at current time
//     auto hasSubNow = [this](const QString &code, const QString &pl) -> bool
//     {
//         QObject *dbObj = dynamic_cast<QObject *>(m_db);
//         if (!dbObj)
//             return false;
//         bool ans = false;
//         bool ok = QMetaObject::invokeMethod(dbObj, "hasActiveSubscription",
//                                             Q_RETURN_ARG(bool, ans),
//                                             Q_ARG(QString, code),
//                                             Q_ARG(QString, pl),
//                                             Q_ARG(QString, QString()));
//         Q_UNUSED(ok);
//         return ans;
//     };
//     QString coTime;
//     // Lưu ảnh checkout vào DB như cổng vào
//     // Store annotated images if we have them
//     const QByteArray store1 = live1;
//     const QByteArray store2 = live2;
//     const CheckOutResult r = m_db->checkOutRfidWithImages(normRfid, &coTime, store1, store2);
//     if (r == CheckOutResult::OkMatched)
//     {
//         m_checkOutTime = coTime;
//         emit timesChanged();
//         m_db->deleteClosedSessions(normRfid);
//         if (bar)
//         {
//             emit debugLog(QStringLiteral("OUT: pulse barrier(L%1) 500ms").arg(laneIdx + 1));
//             if (auto relay = dynamic_cast<UsbRelayBarrier *>(bar))
//                 relay->pulse(500);
//             else
//             {
//                 bar->open();
//                 QTimer::singleShot(500, this, [this, laneIdx]
//                                    { if (auto b = barrierForLane(laneIdx)) b->close(); });
//             }
//         }
//         m_message = QStringLiteral("Check-out thành công");
//         emit messageChanged();
//         const bool isSub = hasSubNow(normRfid, plateBefore);
//         int fee = 0;
//         if (!isSub && sessionId > 0)
//             fee = m_db->computeFeeForSession(sessionId, coTime, false);
//         if (fee < 0)
//         {
//             // Fallback simple estimation only if compute failed
//             QDateTime tin = QDateTime::fromString(checkinBefore, Qt::ISODate);
//             QDateTime tout = QDateTime::fromString(coTime, Qt::ISODate);
//             qint64 mins = qMax<qint64>(1, tin.secsTo(tout) / 60);
//             qint64 hours = (mins + 59) / 60;
//             fee = qMax<qint64>(5000, hours * 5000);
//         }
//         // If card is a short-term type, we still charge per-use via pricing rules (no subscription needed)
//         const QString tt = card.value(QStringLiteral("ticket_type")).toString();
//         if (!tt.isEmpty() && (tt == QLatin1String("hourly") || tt == QLatin1String("daily_day") || tt == QLatin1String("daily_night") || tt == QLatin1String("overnight")))
//         {
//             // Price already computed via session pricing; just adjust display label if needed
//         }
//         if (isSub)
//         {
//             m_laneHasSubscriptions[laneIdx] = true;
//             m_laneSessionIds[laneIdx] = -1;
//             m_laneTicketTypes[laneIdx].clear();
//             m_laneCardIds[laneIdx] = normRfid;
//             setLaneMoneyMessage(laneIdx, QStringLiteral("%1: Vé đăng ký - không thu phí").arg(laneLabel(laneIdx)));
//         }
//         else
//         {
//             m_laneHasSubscriptions[laneIdx] = false;
//             m_laneSessionIds[laneIdx] = -1;
//             m_laneTicketTypes[laneIdx].clear();
//             m_laneCardIds[laneIdx] = normRfid;
//             setLaneMoneyMessage(laneIdx,
//                                 QStringLiteral("%1: Thu phí %2 VND")
//                                     .arg(laneLabel(laneIdx), QLocale::system().toString(fee)));
//         }
//         m_exitCardId = normRfid;
//         m_exitPlate = plateBefore;
//         m_exitTimeIn = checkinBefore;
//         m_exitTimeOut = QDateTime::currentDateTime().toString(Qt::ISODate);
//         emit exitInfoChanged();
//         if (auto hid1 = qobject_cast<QObject *>(m_readerEntrance))
//             QMetaObject::invokeMethod(hid1, "resetDebounce", Qt::QueuedConnection);
//         if (auto hid2 = qobject_cast<QObject *>(m_readerExit))
//             QMetaObject::invokeMethod(hid2, "resetDebounce", Qt::QueuedConnection);
//     }
//     else
//     {
//         m_message = QStringLiteral("Lỗi check-out");
//         emit messageChanged();
//     }
// }

void ParkingController::refreshLiveFees()
{
    if (!m_db)
        return;
    const QString nowIso = QDateTime::currentDateTime().toString(Qt::ISODate);
    for (int laneIdx = 0; laneIdx < static_cast<int>(m_laneSessionIds.size()); ++laneIdx)
    {
        const int sessionId = m_laneSessionIds[laneIdx];
        if (sessionId <= 0)
            continue;
        if (m_laneHasSubscriptions[laneIdx])
        {
            setLaneMoneyMessage(laneIdx, QStringLiteral("%1: Vé đăng ký - không thu phí").arg(laneLabel(laneIdx)));
            continue;
        }
        const int fee = computeFeeForSessionNow(sessionId, nowIso);
        setLaneMoneyMessage(laneIdx, formatLaneFeeMessage(laneIdx, fee));
    }
}

void ParkingController::setLaneMoneyMessage(int laneIdx, const QString &message)
{
    if (laneIdx < 0 || laneIdx >= static_cast<int>(m_laneMoneyMessages.size()))
        return;
    QString effective = message;
    if (effective.trimmed().isEmpty())
        effective = defaultLaneMessage(laneIdx);
    const bool laneChanged = (m_laneMoneyMessages[laneIdx] != effective);
    m_laneMoneyMessages[laneIdx] = effective;
    QStringList parts;
    for (const auto &msg : m_laneMoneyMessages)
    {
        if (!msg.isEmpty())
            parts << msg;
    }
    const QString aggregated = parts.join(QStringLiteral(" | "));
    const bool aggregatedChanged = (m_moneyMessage != aggregated);
    if (laneChanged || aggregatedChanged)
    {
        m_moneyMessage = aggregated;
        emit moneyMessageChanged();
    }
}

void ParkingController::setLanePreview(int laneIdx, const QString &inputUrl, const QString &outputUrl)
{
    if (laneIdx < 0 || laneIdx >= static_cast<int>(m_lanePreviewInput.size()))
        return;
    bool changed = false;
    if (m_lanePreviewInput[laneIdx] != inputUrl)
    {
        m_lanePreviewInput[laneIdx] = inputUrl;
        changed = true;
    }
    if (m_lanePreviewOutput[laneIdx] != outputUrl)
    {
        m_lanePreviewOutput[laneIdx] = outputUrl;
        changed = true;
    }
    if (laneIdx == 0)
    {
        if (m_entranceImg1 != inputUrl)
        {
            m_entranceImg1 = inputUrl;
            changed = true;
        }
        if (m_entranceImg2 != outputUrl)
        {
            m_entranceImg2 = outputUrl;
            changed = true;
        }
    }
    if (changed)
        emit entrancePreviewChanged();
}

void ParkingController::clearLaneState(int laneIdx)
{
    if (laneIdx < 0 || laneIdx >= static_cast<int>(m_laneSessionIds.size()))
        return;
    setLanePreview(laneIdx, QString(), QString());
    m_laneSessionIds[laneIdx] = -1;
    m_laneTicketTypes[laneIdx].clear();
    m_laneHasSubscriptions[laneIdx] = false;
    m_laneCardIds[laneIdx].clear();
    setLaneMoneyMessage(laneIdx, QString());
}

int ParkingController::computeFeeForSessionNow(int sessionId, const QString &nowIso) const
{
    if (!m_db || sessionId <= 0)
        return 0;
    QString ts = nowIso;
    if (ts.isEmpty())
        ts = QDateTime::currentDateTime().toString(Qt::ISODate);
    int fee = m_db->computeFeeForSession(sessionId, ts, false);
    if (fee < 0)
        fee = 0;
    return fee;
}

QString ParkingController::formatLaneFeeMessage(int laneIdx, int fee) const
{
    const QString label = laneLabel(laneIdx);
    if (fee < 0)
        fee = 0;
    const QString amountText = QLocale::system().toString(fee);
    const QString cardType = m_laneTicketTypes[laneIdx];
    const QString cardId = m_laneCardIds[laneIdx];
    if (!cardType.isEmpty() && !cardId.isEmpty())
        return QStringLiteral("%1: %2 (%3) - tạm tính %4 VND").arg(label, cardType, cardId, amountText);
    if (!cardType.isEmpty())
        return QStringLiteral("%1: %2 - tạm tính %3 VND").arg(label, cardType, amountText);
    if (!cardId.isEmpty())
        return QStringLiteral("%1: %2 - tạm tính %3 VND").arg(label, cardId, amountText);
    return QStringLiteral("%1: Tạm tính %2 VND").arg(label, amountText);
}

QString ParkingController::laneLabel(int laneIdx) const
{
    return QStringLiteral("Làn %1").arg(laneIdx + 1);
}

QString ParkingController::defaultLaneMessage(int laneIdx) const
{
    return QStringLiteral("%1: ").arg(laneLabel(laneIdx));
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
        setLanePreview(m_activeExitLane, QString(), QString());
        emit exitReviewChanged();
        return;
    }
    QByteArray img1 = m.value("image1").toByteArray();
    QByteArray img2 = m.value("image2").toByteArray();
    m_exitImg1 = makeDataUrlFromBytes(img1);
    m_exitImg2 = makeDataUrlFromBytes(img2);
    setLanePreview(m_activeExitLane, m_exitImg1, m_exitImg2);
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
    m_activeExitLane = 1;
    loadExitReview(m_lastRfid);
    QString coTime;
    // Chụp ảnh checkout tại cổng ra và lưu DB
    QByteArray exit1;
    QByteArray exit2;
    if (auto cam = camForLane(1))
    { // lane 1 là cổng ra
        exit1 = cam->captureInputSnapshot(85);
        exit2 = cam->captureOutputSnapshot(85);
    }
    const CheckOutResult r = m_db->checkOutRfidWithImages(normalizeRfid(m_lastRfid), &coTime, exit1, exit2, QStringLiteral("Tiền mặt (thủ công)"));
    if (r == CheckOutResult::OkMatched)
    {
        m_checkOutTime = coTime;
        emit timesChanged();
        m_db->deleteClosedSessions(normalizeRfid(m_lastRfid));
        // Show actual fee on main display
        int fee = -1;
        {
            auto before = m_db->fetchFullOpenSession(normalizeRfid(m_lastRfid));
            const int sid = before.value("id").toInt();
            if (sid > 0)
                fee = m_db->computeFeeForSession(sid, coTime, false);
        }
        if (fee >= 0)
        {
            setLaneMoneyMessage(1,
                                QStringLiteral("%1: Thu phí %2 VND")
                                    .arg(laneLabel(1), QLocale::system().toString(fee)));
            m_laneSessionIds[1] = -1;
            m_laneTicketTypes[1].clear();
            m_laneHasSubscriptions[1] = false;
            m_laneCardIds[1] = m_lastRfid;
        }
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

void ParkingController::completeCheckout(const QString &rfid, const QString &plate, const QString &paymentMethod, int fee)
{
    int laneIdx = m_activeExitLane;
    ICameraSnapshotProvider *cam = camForLane(laneIdx);
    IBarrier *bar = barrierForLane(laneIdx);
    if (!cam || !bar) return;

    // Capture checkout images
    QByteArray live1 = cam->captureInputSnapshot(85);
    QByteArray live2 = cam->captureOutputSnapshot(85);

    QString coTime;
    // Pass the paymentMethod to the database function
    const CheckOutResult r = m_db->checkOutRfidWithImages(rfid, &coTime, live1, live2, paymentMethod);

    if (r == CheckOutResult::OkMatched) {
        m_checkOutTime = coTime;
        emit timesChanged();
        m_db->deleteClosedSessions(rfid);

        if (bar) {
            emit debugLog(QStringLiteral("OUT: pulse barrier(L%1) 500ms").arg(laneIdx + 1));
            bar->open();
            QTimer::singleShot(500, this, [this, laneIdx] {
                if (auto b = barrierForLane(laneIdx)) b->close();
            });
        }

        m_message = QStringLiteral("Check-out thành công");
        emit messageChanged();

        // Re-fetch session info to get final fee and check-in time for UI display
        QVariantMap finalSession = m_db->fetchFullOpenSession(rfid);
        const QString checkinBefore = finalSession.value("checkin_time").toString();

        bool isSub = m_db->hasActiveSubscription(rfid, plate, QString());

        if (isSub) {
            setLaneMoneyMessage(laneIdx, QStringLiteral("%1: Vé đăng ký - không thu phí").arg(laneLabel(laneIdx)));
        } else {
            setLaneMoneyMessage(laneIdx,
                                QStringLiteral("%1: Đã thu %2 VND (%3)")
                                    .arg(laneLabel(laneIdx), QLocale::system().toString(fee), paymentMethod));
        }

        m_exitCardId = rfid;
        m_exitPlate = plate;
        m_exitTimeIn = checkinBefore;
        m_exitTimeOut = coTime;
        emit exitInfoChanged();
    } else {
        m_message = QStringLiteral("Lỗi check-out");
        emit messageChanged();
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
