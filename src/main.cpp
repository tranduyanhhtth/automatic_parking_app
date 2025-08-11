#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controller/parkingcontroller.h"
#include "utils/camera/cameramanager.h"
#include "utils/db/databasemanager.h"
#include "utils/io_barrier/barriercontroller.h"
#include "utils/io_card/cardreader.h"
#include "utils/ocr/ocrprocessor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Infrastructure services
    auto cameraManager = new CameraManager(&app);
    auto db = new DatabaseManager(&app);
    db->initialize();
    auto barrier = new BarrierController(&app);
    auto ocr = new OCRProcessor(&app);
    auto cardReader = new CardReader(&app);

    // Application controller (depends on domain ports)
    ParkingController controller(cameraManager, db, barrier, ocr, cardReader);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("cameraManager", cameraManager);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [](QObject *obj, const QUrl &objUrl)
                     {
        Q_UNUSED(objUrl)
        if (!obj)
            QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("automatic_parking_app", "MainWindow");

    return app.exec();
}
