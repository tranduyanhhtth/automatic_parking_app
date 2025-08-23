#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QScreen>
#include <QIcon>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QSettings>
#ifdef _WIN32
#include <d3d11.h>
#include <dxgi.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#endif
#include "controller/parkingcontroller.h"
#include "utils/camera/cameramanager.h"
#include "utils/db/databasemanager.h"
#include "utils/io_barrier/usbrelaybarrier.h"
#include "utils/config/settings.h"
#ifdef _WIN32
#include "utils/io_card/windows_rawinput_router.h"
#include "utils/io_card/hidkeyboardcardreader_device.h"
#endif
#ifndef _WIN32
#include "utils/io_card/hidkeyboardcardreader.h"
#endif
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    // Sử dụng GStreamer để stream, không cần cấu hình biến môi trường FFmpeg

    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName("Multimodel-AIThings");
    QCoreApplication::setApplicationName("smart_parking_system");

    // Thiết lập mặc định cho Tesseract nếu người dùng chưa cấu hình
    {
        QSettings s("Multimodel-AIThings", "smart_parking_system");
        if (!s.contains("tesseract/enable"))
            s.setValue("tesseract/enable", true);
        if (!s.contains("tesseract/tessdataParent"))
            s.setValue("tesseract/tessdataParent", QStringLiteral("d:/smart_parking_system/lib/tesseract"));
        if (!s.contains("tesseract/lang"))
            s.setValue("tesseract/lang", QStringLiteral("eng"));
    }

    app.setWindowIcon(QIcon(QStringLiteral("assets/logo_icon.jpg")));

    auto cameraLane1 = new CameraManager(&app);
    auto cameraLane2 = new CameraManager(&app);

    auto settings = new SettingsManager(&app);
    // Tuỳ chọn: vẫn có thể dùng decode hardware trong GStreamer (cấu hình trong pipeline nếu cần)
    settings->useHardwareDecode();

    auto db = new DatabaseManager(&app);
    db->initialize();

    auto barrier1 = new UsbRelayBarrier(&app);
    barrier1->setBaudRate(settings->barrier1Baud());
    barrier1->setPortName(settings->barrier1Port());
    barrier1->connectPort();
    auto barrier2 = new UsbRelayBarrier(&app);
    barrier2->setBaudRate(settings->barrier2Baud());
    barrier2->setPortName(settings->barrier2Port());
    barrier2->connectPort();

    auto ocr = new OCRProcessor(db, &app);

    // Hai đầu đọc thẻ độc lập: cổng vào và cổng ra
#ifdef _WIN32
    auto rawRouter = new WindowsRawInputRouter(&app);
    // Ensure a window will be registered after QML creates it (done later)
    auto cardReaderEntrance = new HidKeyboardCardReaderDevice(rawRouter, &app);
    auto cardReaderExit = new HidKeyboardCardReaderDevice(rawRouter, &app);
    // Bind device paths from settings (if empty, auto-pick first two keyboards)
    auto keyboards = rawRouter->enumerateKeyboards();
    QString entrancePath = settings->entranceReaderPath();
    QString exitPath = settings->exitReaderPath();
    if (entrancePath.isEmpty() && !keyboards.isEmpty())
        entrancePath = keyboards.value(0).devicePath;
    if (exitPath.isEmpty() && keyboards.size() > 1)
        exitPath = keyboards.value(1).devicePath;
    cardReaderEntrance->setDevicePath(entrancePath);
    cardReaderExit->setDevicePath(exitPath);
#else
    auto cardReaderEntrance = new HidKeyboardCardReader(&app);
    auto cardReaderExit = new HidKeyboardCardReader(&app);
#endif
    // Log camera stalls to HID
    QObject::connect(cameraLane1, &CameraManager::inputStreamStalled, cardReaderEntrance, [cardReaderEntrance]()
                     {
        const QString m = QStringLiteral("[HID] Camera Front: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(cameraLane1, &CameraManager::outputStreamStalled, cardReaderEntrance, [cardReaderEntrance]()
                     {
        const QString m = QStringLiteral("[HID] Camera Rear: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(cameraLane2, &CameraManager::inputStreamStalled, cardReaderExit, [cardReaderExit]()
                     {
        const QString m = QStringLiteral("[HID] Camera2 Front: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(cameraLane2, &CameraManager::outputStreamStalled, cardReaderExit, [cardReaderExit]()
                     {
        const QString m = QStringLiteral("[HID] Camera2 Rear: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    // Log trạng thái barrier lên HID LOG (sau khi đã có cardReader)
    QObject::connect(barrier1, &UsbRelayBarrier::barrierOpened, cardReaderEntrance, [cardReaderEntrance]()
                     {
        const QString m = QStringLiteral("[HID] Barrier: OPEN");
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier1, &UsbRelayBarrier::barrierClosed, cardReaderEntrance, [cardReaderEntrance]()
                     {
        const QString m = QStringLiteral("[HID] Barrier: CLOSED");
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier1, &UsbRelayBarrier::connectedChanged, cardReaderEntrance, [cardReaderEntrance, barrier1]()
                     {
        const bool ok = barrier1->isConnected();
        const QString m = QStringLiteral("[HID] Barrier Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier1, &UsbRelayBarrier::lastErrorChanged, cardReaderEntrance, [cardReaderEntrance, barrier1]()
                     {
        const QString m = QStringLiteral("[HID] Barrier Error: %1").arg(barrier1->lastError());
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier2, &UsbRelayBarrier::barrierOpened, cardReaderExit, [cardReaderExit]()
                     {
        const QString m = QStringLiteral("[HID] Barrier2: OPEN");
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier2, &UsbRelayBarrier::barrierClosed, cardReaderExit, [cardReaderExit]()
                     {
        const QString m = QStringLiteral("[HID] Barrier2: CLOSED");
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier2, &UsbRelayBarrier::connectedChanged, cardReaderExit, [cardReaderExit, barrier2]()
                     {
        const bool ok = barrier2->isConnected();
        const QString m = QStringLiteral("[HID] Barrier2 Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier2, &UsbRelayBarrier::lastErrorChanged, cardReaderExit, [cardReaderExit, barrier2]()
                     {
        const QString m = QStringLiteral("[HID] Barrier2 Error: %1").arg(barrier2->lastError());
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    // Log trạng thái ban đầu
    {
        const bool ok = barrier1->isConnected();
        const QString m = QStringLiteral("[HID] Barrier Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
    }
    {
        const bool ok = barrier2->isConnected();
        const QString m = QStringLiteral("[HID] Barrier2 Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
    }
    {
        const bool ok = cardReaderEntrance->isEnabled() && cardReaderExit->isEnabled();
        const QString m = QStringLiteral("[HID] Card Reader: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISABLED"));
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
    }

    ParkingController controller(cameraLane1, cameraLane2, db, barrier1, barrier2, ocr, cardReaderEntrance, cardReaderExit);

    // GPU availability + decode intent logging to HID
#ifdef _WIN32
    {
        bool hasGpu = false;
        IDXGIFactory *pFactory = nullptr;
        if (SUCCEEDED(CreateDXGIFactory(__uuidof(IDXGIFactory), (void **)&pFactory)))
        {
            IDXGIAdapter *pAdapter = nullptr;
            for (UINT i = 0; pFactory->EnumAdapters(i, &pAdapter) != DXGI_ERROR_NOT_FOUND; ++i)
            {
                DXGI_ADAPTER_DESC desc;
                if (SUCCEEDED(pAdapter->GetDesc(&desc)))
                {
                    hasGpu = true; // Found at least one adapter
                }
                pAdapter->Release();
                if (hasGpu)
                    break;
            }
            pFactory->Release();
        }
        const bool wantHw = settings->useHardwareDecode();
        auto logToHids = [&](const QString &m)
        {
            QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
            QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        };
        if (hasGpu && wantHw)
            logToHids(QStringLiteral("[HID] Video Decode: GPU available, using hardware decode"));
        else if (hasGpu && !wantHw)
            logToHids(QStringLiteral("[HID] Video Decode: GPU available, but hardware decode disabled in settings"));
        else
            logToHids(QStringLiteral("[HID] Video Decode: No GPU detected – falling back to software decode"));
    }
#endif

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("cameraLane1", cameraLane1);
    engine.rootContext()->setContextProperty("cameraLane2", cameraLane2);
    engine.rootContext()->setContextProperty("cardReaderEntrance", cardReaderEntrance);
    engine.rootContext()->setContextProperty("cardReaderExit", cardReaderExit);
    engine.rootContext()->setContextProperty("barrier1", barrier1);
    engine.rootContext()->setContextProperty("barrier2", barrier2);
    engine.rootContext()->setContextProperty("settings", settings);

    // Phần này là để xử lý khi QML khởi tạo, bao gồm cả Window và Item
    QQuickWindow *createdWindow = nullptr;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&, cardReaderEntrance, cardReaderExit
#ifdef _WIN32
                                                                            ,
                                                                            rawRouter
#endif
    ](QObject *obj, const QUrl &objUrl)
                     {
        Q_UNUSED(objUrl)
        if (!obj) {
            QCoreApplication::exit(-1);
            return;
        }
        if (auto win = qobject_cast<QQuickWindow *>(obj)) 
        {
            if (QScreen *screen = QGuiApplication::primaryScreen()) {
                win->setGeometry(screen->geometry());
            }
            win->showFullScreen();
            // Cài hai đầu đọc HID làm eventFilter để nhận phím từ cả hai thiết bị
            if (cardReaderEntrance)
                win->installEventFilter(cardReaderEntrance);
            if (cardReaderExit)
                win->installEventFilter(cardReaderExit);
#ifdef _WIN32
            // Also register for Raw Input so we can distinguish devices
            if (rawRouter)
                rawRouter->registerWindow(win);
#endif
        } 
        else if (auto item = qobject_cast<QQuickItem *>(obj)) 
        {
            createdWindow = new QQuickWindow();
            createdWindow->setTitle(QStringLiteral("automatic parking"));
            
            if (QScreen *screen = QGuiApplication::primaryScreen()) {
                createdWindow->setGeometry(screen->geometry());
            } else {
                createdWindow->resize(1024, 768);
            }

            item->setParentItem(createdWindow->contentItem());
            item->setParent(createdWindow);
            item->setWidth(createdWindow->width());
            item->setHeight(createdWindow->height());

            QObject::connect(createdWindow, &QQuickWindow::widthChanged, item, [item, createdWindow]{
                item->setWidth(createdWindow->width());
            });
            QObject::connect(createdWindow, &QQuickWindow::heightChanged, item, [item, createdWindow]{
                item->setHeight(createdWindow->height());
            });

            createdWindow->showFullScreen();
            if (cardReaderEntrance)
                createdWindow->installEventFilter(cardReaderEntrance);
            if (cardReaderExit)
                createdWindow->installEventFilter(cardReaderExit);
#ifdef _WIN32
            if (rawRouter)
                rawRouter->registerWindow(createdWindow);
#endif
        } },
                     Qt::QueuedConnection);

    engine.loadFromModule("smart_parking_system", "MainWindow");

    return app.exec();
}
