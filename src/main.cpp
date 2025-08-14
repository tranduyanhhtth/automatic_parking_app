#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include "controller/parkingcontroller.h"
#include "utils/camera/cameramanager.h"
#include "utils/db/databasemanager.h"
#include "utils/io_barrier/barriercontroller.h"
#include "utils/io_card/hidkeyboardcardreader.h"
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // // Set app icon (for window/taskbar)
    // app.setWindowIcon(QIcon(QStringLiteral("qrc:/automatic_parking_app/src/assets/logo_icon.jpg")));

    // Infrastructure services
    auto cameraManager = new CameraManager(&app);
    auto db = new DatabaseManager(&app);
    db->initialize();
    auto barrier = new BarrierController(&app);
    auto ocr = new OCRProcessor(&app);
    auto cardReader = new HidKeyboardCardReader(&app);

    // Application controller (depends on domain ports)
    ParkingController controller(cameraManager, db, barrier, ocr, cardReader);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("cameraManager", cameraManager);
    engine.rootContext()->setContextProperty("cardReader", cardReader);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [](QObject *obj, const QUrl &objUrl)
                     {
        Q_UNUSED(objUrl)
        if (!obj)
            QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("automatic_parking_app", "MainWindow");
    // Cài event filter sau khi load để nhận phím toàn cục
    if (!engine.rootObjects().isEmpty())
    {
        engine.rootObjects().first()->installEventFilter(cardReader);
    }

    return app.exec();
}
