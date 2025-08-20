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
    m_barrierPort = s.value("barrierPort", QStringLiteral("COM3")).toString();
    m_barrierBaud = s.value("barrierBaud", 9600).toInt();
    m_ocrApiKey = s.value("ocrSpaceApiKey", QString()).toString();
    m_useHwDecode = s.value("useHardwareDecode", true).toBool();
    emit camera1UrlChanged();
    emit camera2UrlChanged();
    emit barrierPortChanged();
    emit barrierBaudChanged();
    emit ocrSpaceApiKeyChanged();
    emit useHardwareDecodeChanged();
}

void SettingsManager::save()
{
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    s.setValue("camera1Url", m_camera1Url);
    s.setValue("camera2Url", m_camera2Url);
    s.setValue("barrierPort", m_barrierPort);
    s.setValue("barrierBaud", m_barrierBaud);
    s.setValue("ocrSpaceApiKey", m_ocrApiKey);
    s.setValue("useHardwareDecode", m_useHwDecode);
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

void SettingsManager::setBarrierPort(const QString &port)
{
    if (m_barrierPort == port)
        return;
    m_barrierPort = port;
    emit barrierPortChanged();
}

void SettingsManager::setBarrierBaud(int baud)
{
    if (m_barrierBaud == baud)
        return;
    m_barrierBaud = baud;
    emit barrierBaudChanged();
}

void SettingsManager::setOcrSpaceApiKey(const QString &k)
{
    if (m_ocrApiKey == k)
        return;
    m_ocrApiKey = k;
    emit ocrSpaceApiKeyChanged();
}

void SettingsManager::setUseHardwareDecode(bool v)
{
    if (m_useHwDecode == v)
        return;
    m_useHwDecode = v;
    emit useHardwareDecodeChanged();
}
