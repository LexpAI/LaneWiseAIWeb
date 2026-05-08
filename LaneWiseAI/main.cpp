#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QVariant>

#include "lanewisecontroller.hpp"

int main(int argc, char *argv[]) 
{
    QGuiApplication app(argc, argv);

    LaneWiseController controller;

    QQmlApplicationEngine engine;

    engine.setInitialProperties({
        {QStringLiteral("controller"), QVariant::fromValue(static_cast<QObject *>(&controller))}
    });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("LaneWiseAI", "Main");

    return QCoreApplication::exec();
}
