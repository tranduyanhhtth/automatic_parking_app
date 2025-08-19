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
#include "controller/parkingcontroller.h"
#include "utils/camera/cameramanager.h"
#include "utils/db/databasemanager.h"
#include "utils/io_barrier/usbrelaybarrier.h"
#include "utils/config/settings.h"
#include "utils/io_card/hidkeyboardcardreader.h"
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName("Multimodel-AIThings");
    QCoreApplication::setApplicationName("smart_parking_system");

    app.setWindowIcon(QIcon(QStringLiteral("assets/logo_icon.jpg")));

    auto cameraManager = new CameraManager(&app);

    auto settings = new SettingsManager(&app);

    auto db = new DatabaseManager(&app);
    db->initialize();

    auto barrier = new UsbRelayBarrier(&app);
    barrier->setBaudRate(settings->barrierBaud());
    barrier->setPortName(settings->barrierPort());
    barrier->connectPort();

    auto ocr = new OCRProcessor(db, &app);

    auto cardReader = new HidKeyboardCardReader(&app);
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
