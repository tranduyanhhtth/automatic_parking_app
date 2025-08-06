#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "databasemanager.h"
#include "barriercontroller.h"
#include "cardreader.h"
#include "cameramanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("automatic_parking_app", "Main");

    return app.exec();
}
