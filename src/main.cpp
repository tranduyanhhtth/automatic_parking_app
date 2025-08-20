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
#include "utils/io_card/hidkeyboardcardreader.h"
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    // Configure Qt Multimedia (FFmpeg) for low-latency RTSP before creating the app
    qputenv("QT_MEDIA_BACKEND", QByteArray("ffmpeg"));
    qputenv("QT_FFMPEG_RTSP_TRANSPORT", QByteArray("tcp"));
    qputenv("QT_FFMPEG_MAX_DELAY", QByteArray("100000"));   // 100ms
    qputenv("QT_FFMPEG_BUFFER_SIZE", QByteArray("524288")); // 512KB
    qputenv("QT_FFMPEG_ANALYZE_DURATION", QByteArray("0"));
    qputenv("QT_FFMPEG_PROBE_SIZE", QByteArray("32768"));

    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName("Multimodel-AIThings");
    QCoreApplication::setApplicationName("smart_parking_system");

    app.setWindowIcon(QIcon(QStringLiteral("assets/logo_icon.jpg")));

    auto cameraManager = new CameraManager(&app);

    auto settings = new SettingsManager(&app);
    // Hint FFmpeg/Qt to use hardware decoding when available (D3D11VA on Windows)
    if (settings->useHardwareDecode())
    {
        // These envs are advisory; Qt may ignore unknown keys
        qputenv("QT_MEDIA_FFMPEG_HWACCEL", QByteArray("d3d11va"));
        qputenv("QT_FFMPEG_HWACCEL", QByteArray("d3d11va"));
        qputenv("QT_MEDIA_USE_HARDWARE_DECODER", QByteArray("1"));
    }
    else
    {
        qunsetenv("QT_MEDIA_FFMPEG_HWACCEL");
        qunsetenv("QT_FFMPEG_HWACCEL");
        qputenv("QT_MEDIA_USE_HARDWARE_DECODER", QByteArray("0"));
    }

    auto db = new DatabaseManager(&app);
    db->initialize();

    auto barrier = new UsbRelayBarrier(&app);
    barrier->setBaudRate(settings->barrierBaud());
    barrier->setPortName(settings->barrierPort());
    barrier->connectPort();

    auto ocr = new OCRProcessor(db, &app);

    auto cardReader = new HidKeyboardCardReader(&app);
    // Log camera stalls to HID
    QObject::connect(cameraManager, &CameraManager::inputStreamStalled, cardReader, [cardReader]()
                     {
        const QString m = QStringLiteral("[HID] Camera Front: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(cameraManager, &CameraManager::outputStreamStalled, cardReader, [cardReader]()
                     {
        const QString m = QStringLiteral("[HID] Camera Rear: STALLED (no frames)");
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    // Log trạng thái barrier lên HID LOG (sau khi đã có cardReader)
    QObject::connect(barrier, &UsbRelayBarrier::barrierOpened, cardReader, [cardReader]()
                     {
        const QString m = QStringLiteral("[HID] Barrier: OPEN");
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier, &UsbRelayBarrier::barrierClosed, cardReader, [cardReader]()
                     {
        const QString m = QStringLiteral("[HID] Barrier: CLOSED");
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier, &UsbRelayBarrier::connectedChanged, cardReader, [cardReader, barrier]()
                     {
        const bool ok = barrier->isConnected();
        const QString m = QStringLiteral("[HID] Barrier Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    QObject::connect(barrier, &UsbRelayBarrier::lastErrorChanged, cardReader, [cardReader, barrier]()
                     {
        const QString m = QStringLiteral("[HID] Barrier Error: %1").arg(barrier->lastError());
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m)); });
    // Log trạng thái ban đầu
    {
        const bool ok = barrier->isConnected();
        const QString m = QStringLiteral("[HID] Barrier Port: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISCONNECTED"));
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
    }
    {
        const bool ok = cardReader->isEnabled();
        const QString m = QStringLiteral("[HID] Card Reader: %1").arg(ok ? QStringLiteral("CONNECTED") : QStringLiteral("DISABLED"));
        QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
    }

    ParkingController controller(cameraManager, db, barrier, ocr, cardReader);

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
        if (hasGpu && wantHw)
        {
            const QString m = QStringLiteral("[HID] Video Decode: GPU available, using hardware decode");
            QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        }
        else if (hasGpu && !wantHw)
        {
            const QString m = QStringLiteral("[HID] Video Decode: GPU available, but hardware decode disabled in settings");
            QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        }
        else
        {
            const QString m = QStringLiteral("[HID] Video Decode: No GPU detected – falling back to software decode");
            QMetaObject::invokeMethod(cardReader, "debugLog", Qt::QueuedConnection, Q_ARG(QString, m));
        }
    }
#endif

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("cameraManager", cameraManager);
    engine.rootContext()->setContextProperty("cardReader", cardReader);
    engine.rootContext()->setContextProperty("barrier", barrier);
    engine.rootContext()->setContextProperty("settings", settings);

    // Phần này là để xử lý khi QML khởi tạo, bao gồm cả Window và Item
    QQuickWindow *createdWindow = nullptr;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&, cardReader](QObject *obj, const QUrl &objUrl)
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
            win->installEventFilter(cardReader);
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
            createdWindow->installEventFilter(cardReader);
        } }, Qt::QueuedConnection);

    engine.loadFromModule("smart_parking_system", "MainWindow");

    return app.exec();
}
