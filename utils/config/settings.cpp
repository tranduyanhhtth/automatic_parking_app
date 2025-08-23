#include "settings.h"
#include <QSettings>

SettingsManager::SettingsManager(QObject *parent) : QObject(parent)
{
    load();
}

void SettingsManager::load()
{
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    m_camera1Url = s.value("camera1Url", QStringLiteral("rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0&rtsp_transport=tcp&stimeout=5000000")).toString();
    m_camera2Url = s.value("camera2Url", QStringLiteral("rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0&rtsp_transport=tcp&stimeout=5000000")).toString();
    m_camera3Url = s.value("camera3Url", QStringLiteral("rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0&rtsp_transport=tcp&stimeout=5000000")).toString();
    m_camera4Url = s.value("camera4Url", QStringLiteral("rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0&rtsp_transport=tcp&stimeout=5000000")).toString();
    m_barrier1Port = s.value("barrier1Port", QStringLiteral("COM3")).toString();
    m_barrier1Baud = s.value("barrier1Baud", 9600).toInt();
    m_barrier2Port = s.value("barrier2Port", QStringLiteral("COM4")).toString();
    m_barrier2Baud = s.value("barrier2Baud", 9600).toInt();
    m_useHwDecode = s.value("useHardwareDecode", true).toBool();
    m_entranceReaderPath = s.value("entranceReaderPath", QString()).toString();
    m_exitReaderPath = s.value("exitReaderPath", QString()).toString();
    emit camera1UrlChanged();
    emit camera2UrlChanged();
    emit camera3UrlChanged();
    emit camera4UrlChanged();
    emit barrier1PortChanged();
    emit barrier1BaudChanged();
    emit barrier2PortChanged();
    emit barrier2BaudChanged();
    emit useHardwareDecodeChanged();
    emit entranceReaderPathChanged();
    emit exitReaderPathChanged();
}

void SettingsManager::save()
{
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    s.setValue("camera1Url", m_camera1Url);
    s.setValue("camera2Url", m_camera2Url);
    s.setValue("camera3Url", m_camera3Url);
    s.setValue("camera4Url", m_camera4Url);
    s.setValue("barrier1Port", m_barrier1Port);
    s.setValue("barrier1Baud", m_barrier1Baud);
    s.setValue("barrier2Port", m_barrier2Port);
    s.setValue("barrier2Baud", m_barrier2Baud);
    s.setValue("useHardwareDecode", m_useHwDecode);
    s.setValue("entranceReaderPath", m_entranceReaderPath);
    s.setValue("exitReaderPath", m_exitReaderPath);
}

void SettingsManager::setCamera1Url(const QString &url)
{
    if (m_camera1Url == url)
        return;
    m_camera1Url = url;
    emit camera1UrlChanged();
}

void SettingsManager::setCamera2Url(const QString &url)
{
    if (m_camera2Url == url)
        return;
    m_camera2Url = url;
    emit camera2UrlChanged();
}

void SettingsManager::setCamera3Url(const QString &url)
{
    if (m_camera3Url == url)
        return;
    m_camera3Url = url;
    emit camera3UrlChanged();
}

void SettingsManager::setCamera4Url(const QString &url)
{
    if (m_camera4Url == url)
        return;
    m_camera4Url = url;
    emit camera4UrlChanged();
}

void SettingsManager::setBarrier1Port(const QString &port)
{
    if (m_barrier1Port == port)
        return;
    m_barrier1Port = port;
    emit barrier1PortChanged();
}

void SettingsManager::setBarrier1Baud(int baud)
{
    if (m_barrier1Baud == baud)
        return;
    m_barrier1Baud = baud;
    emit barrier1BaudChanged();
}

void SettingsManager::setBarrier2Port(const QString &port)
{
    if (m_barrier2Port == port)
        return;
    m_barrier2Port = port;
    emit barrier2PortChanged();
}

void SettingsManager::setBarrier2Baud(int baud)
{
    if (m_barrier2Baud == baud)
        return;
    m_barrier2Baud = baud;
    emit barrier2BaudChanged();
}

void SettingsManager::setUseHardwareDecode(bool v)
{
    if (m_useHwDecode == v)
        return;
    m_useHwDecode = v;
    emit useHardwareDecodeChanged();
}

void SettingsManager::setEntranceReaderPath(const QString &p)
{
    if (m_entranceReaderPath == p)
        return;
    m_entranceReaderPath = p;
    emit entranceReaderPathChanged();
}

void SettingsManager::setExitReaderPath(const QString &p)
{
    if (m_exitReaderPath == p)
        return;
    m_exitReaderPath = p;
    emit exitReaderPathChanged();
}
