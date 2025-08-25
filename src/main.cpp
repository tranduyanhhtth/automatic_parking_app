#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QScreen>
#include <QIcon>
#include <QQmlEngine>
#include <QtQuickControls2/QQuickStyle>
#include <QtQml/qqml.h>
#include <d3d11.h>
#include <dxgi.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#include "controller/parkingcontroller.h"
#include "utils/camera/cameramanager.h"
#include "utils/db/databasemanager.h"
#include "utils/io_barrier/usbrelaybarrier.h"
#include "utils/config/settings.h"
#include "utils/io_card/windows_rawinput_router.h"
#include "utils/io_card/hidkeyboardcardreader_device.h"
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Use a non-native style so background/customization on Controls works without warnings
    // Options: "Basic", "Fusion", "Material". Fusion gives a neutral cross-platform look.
    QQuickStyle::setStyle("Fusion");

    QCoreApplication::setOrganizationName("Multimodel-AIThings");
    QCoreApplication::setApplicationName("smart_parking_system");

    // Tải biểu tượng ứng dụng từ tài nguyên (qrc)
    app.setWindowIcon(QIcon(QStringLiteral(":/assets/logo_icon.jpg")));

    auto cameraLane1 = new CameraManager(&app);
    auto cameraLane2 = new CameraManager(&app);

    auto settings = new SettingsManager(&app);

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

    // Hai đầu đọc thẻ độc lập: cổng vào và cổng ra (Windows)
    auto rawRouter = new WindowsRawInputRouter(&app);

    auto cardReaderEntrance = new HidKeyboardCardReaderDevice(rawRouter, &app);
    auto cardReaderExit = new HidKeyboardCardReaderDevice(rawRouter, &app);

    // Bắt buộc dùng đường dẫn thiết bị từ cấu hình; KHÔNG tự chọn bàn phím PC

    QString entrancePath = settings->entranceReaderPath();
    QString exitPath = settings->exitReaderPath();

    cardReaderEntrance->setDevicePath(entrancePath);
    cardReaderExit->setDevicePath(exitPath);

    // Tuỳ chọn: siết thời gian quét để giảm lỗi đọc nhầm
    cardReaderEntrance->setInterKeyMsMax(30);
    cardReaderExit->setInterKeyMsMax(30);

    // Ghi log khi camera bị đứng (stalled) lên HID
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
        const QStringList present = rawRouter->keyboardDevicePaths();
        const bool eBound = !entrancePath.isEmpty();
        const bool xBound = !exitPath.isEmpty();
        const bool ePresent = eBound && present.contains(entrancePath);
        const bool xPresent = xBound && present.contains(exitPath);
        const QString me = QStringLiteral("[HID] Entrance Reader: %1%2%3")
                               .arg(eBound ? QStringLiteral("BOUND") : QStringLiteral("UNBOUND"))
                               .arg(eBound ? QStringLiteral(" ") : QString())
                               .arg(eBound ? (ePresent ? QStringLiteral("(PRESENT)") : QStringLiteral("(NOT FOUND)")) : QString());
        const QString mx = QStringLiteral("[HID] Exit Reader: %1%2%3")
                               .arg(xBound ? QStringLiteral("BOUND") : QStringLiteral("UNBOUND"))
                               .arg(xBound ? QStringLiteral(" ") : QString())
                               .arg(xBound ? (xPresent ? QStringLiteral("(PRESENT)") : QStringLiteral("(NOT FOUND)")) : QString());
        QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, me));
        QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, mx));
    }

    ParkingController controller(cameraLane1, cameraLane2, db, barrier1, barrier2, ocr, cardReaderEntrance, cardReaderExit);

    // Kiểm tra GPU và ghi log ý định giải mã video lên HID
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
                    hasGpu = true; // Tìm thấy ít nhất một adapter
                }
                pAdapter->Release();
                if (hasGpu)
                    break;
            }
            pFactory->Release();
        }
        auto logToHids = [&](const QString &m)
        {
            QMetaObject::invokeMethod(cardReaderEntrance, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
            QMetaObject::invokeMethod(cardReaderExit, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        };
        if (hasGpu)
            logToHids(QStringLiteral("[HID] Video Decode: GPU available (auto hardware decode if supported)"));
        else
            logToHids(QStringLiteral("[HID] Video Decode: No GPU detected – using software decode"));
    }

    QQmlApplicationEngine engine;
    // Đảm bảo engine có thể tìm thấy QML đã biên dịch và tài nguyên
    engine.addImportPath("qrc:/qt/qml");
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("cameraLane1", cameraLane1);
    engine.rootContext()->setContextProperty("cameraLane2", cameraLane2);
    engine.rootContext()->setContextProperty("repo", db);
    engine.rootContext()->setContextProperty("cardReaderEntrance", cardReaderEntrance);
    engine.rootContext()->setContextProperty("cardReaderExit", cardReaderExit);
    engine.rootContext()->setContextProperty("barrier1", barrier1);
    engine.rootContext()->setContextProperty("barrier2", barrier2);
    engine.rootContext()->setContextProperty("settings", settings);

    // Đăng ký đối tượng backend dạng QML singleton (tuỳ chọn, vẫn giữ context properties)
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "App", &controller);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "Settings", settings);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "Repo", db);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "CameraLane1", cameraLane1);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "CameraLane2", cameraLane2);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "Barrier1", barrier1);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "Barrier2", barrier2);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "CardReaderEntrance", cardReaderEntrance);
    qmlRegisterSingletonInstance("smart_parking_system", 1, 0, "CardReaderExit", cardReaderExit);

    // Phần này là để xử lý khi QML khởi tạo, bao gồm cả Window và Item
    QQuickWindow *createdWindow = nullptr;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&, cardReaderEntrance, cardReaderExit, rawRouter](QObject *obj, const QUrl &objUrl)
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
            // Đăng ký Raw Input để phân biệt thiết bị
            if (rawRouter)
                rawRouter->registerWindow(win);
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
            if (rawRouter)
                rawRouter->registerWindow(createdWindow);
        } }, Qt::QueuedConnection);

    // Nạp QML chính từ module đã biên dịch (URI smart_parking_system)
    engine.loadFromModule("smart_parking_system", "MainWindow");

    return app.exec();
}
