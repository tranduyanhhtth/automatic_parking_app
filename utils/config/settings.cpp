#include "settings.h"
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>
#include <QSet>
#include <QList>
#include <QPair>

// Remove FFmpeg-only query params that some cameras reject. Preserve vendor params.
static QString sanitizeRtspUrl(const QString &in)
{
    if (in.trimmed().isEmpty())
        return in;
    QUrl url(in);
    if (!url.isValid())
        return in; // keep as-is
    const QString scheme = url.scheme().toLower();
    if (scheme != QLatin1String("rtsp") && scheme != QLatin1String("rtsps"))
        return in;

    static const QSet<QString> blocked{
        QStringLiteral("rtsp_transport"),
        QStringLiteral("stimeout"),
        QStringLiteral("audio"),
        QStringLiteral("fflags"),
        QStringLiteral("probesize"),
        QStringLiteral("analyzeduration"),
        QStringLiteral("max_delay"),
        QStringLiteral("buffer_size"),
        QStringLiteral("reorder_queue_size")};

    QUrlQuery q(url);
    bool removed = false;
    QList<QPair<QString, QString>> kept;
    const auto items = q.queryItems(QUrl::FullyDecoded);
    for (const auto &kv : items)
    {
        const QString key = kv.first;
        if (blocked.contains(key))
        {
            removed = true;
            continue;
        }
        kept.append(kv);
    }

    // Rebuild query without blocked params
    QUrlQuery nq;
    for (const auto &kv : kept)
        nq.addQueryItem(kv.first, kv.second);

    // If this looks like vendor path and required params are missing, add defaults
    const QString p = url.path();
    const bool looksVendorStreaming = p.contains(QLatin1String("/rtsp/streaming"), Qt::CaseInsensitive) ||
                                      p.contains(QLatin1String("/Streaming/Channels"), Qt::CaseInsensitive);
    if (looksVendorStreaming)
    {
        const bool hasChannel = nq.hasQueryItem(QStringLiteral("channel"));
        const bool hasSubtype = nq.hasQueryItem(QStringLiteral("subtype"));
        if (!hasChannel)
            nq.addQueryItem(QStringLiteral("channel"), QStringLiteral("01"));
        if (!hasSubtype)
            nq.addQueryItem(QStringLiteral("subtype"), QStringLiteral("0"));
    }

    // If anything changed (blocked removed or defaults added), return modified URL
    if (removed || nq.query() != q.query())
    {
        url.setQuery(nq);
        return url.toString(QUrl::FullyEncoded);
    }
    return in; // unchanged
}

SettingsManager::SettingsManager(QObject *parent) : QObject(parent)
{
    load();
}

void SettingsManager::load()
{
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    const QString orig1 = s.value("camera1Url", QStringLiteral("rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0")).toString();
    const QString orig2 = s.value("camera2Url", QStringLiteral("rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0")).toString();
    const QString orig3 = s.value("camera3Url", QStringLiteral("rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0")).toString();
    const QString orig4 = s.value("camera4Url", QStringLiteral("rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0")).toString();

    m_camera1Url = sanitizeRtspUrl(orig1);
    m_camera2Url = sanitizeRtspUrl(orig2);
    m_camera3Url = sanitizeRtspUrl(orig3);
    m_camera4Url = sanitizeRtspUrl(orig4);

    // Persist sanitized values if they were changed from stored ones
    if (m_camera1Url != orig1)
        s.setValue("camera1Url", m_camera1Url);
    if (m_camera2Url != orig2)
        s.setValue("camera2Url", m_camera2Url);
    if (m_camera3Url != orig3)
        s.setValue("camera3Url", m_camera3Url);
    if (m_camera4Url != orig4)
        s.setValue("camera4Url", m_camera4Url);
    m_barrier1Port = s.value("barrier1Port", QStringLiteral("COM3")).toString();
    m_barrier1Baud = s.value("barrier1Baud", 9600).toInt();
    m_barrier2Port = s.value("barrier2Port", QStringLiteral("COM4")).toString();
    m_barrier2Baud = s.value("barrier2Baud", 9600).toInt();
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
    s.setValue("entranceReaderPath", m_entranceReaderPath);
    s.setValue("exitReaderPath", m_exitReaderPath);
}

void SettingsManager::setCamera1Url(const QString &url)
{
    const QString sanitized = sanitizeRtspUrl(url);
    if (m_camera1Url == sanitized)
        return;
    m_camera1Url = sanitized;
    emit camera1UrlChanged();
}

void SettingsManager::setCamera2Url(const QString &url)
{
    const QString sanitized = sanitizeRtspUrl(url);
    if (m_camera2Url == sanitized)
        return;
    m_camera2Url = sanitized;
    emit camera2UrlChanged();
}

void SettingsManager::setCamera3Url(const QString &url)
{
    const QString sanitized = sanitizeRtspUrl(url);
    if (m_camera3Url == sanitized)
        return;
    m_camera3Url = sanitized;
    emit camera3UrlChanged();
}

void SettingsManager::setCamera4Url(const QString &url)
{
    const QString sanitized = sanitizeRtspUrl(url);
    if (m_camera4Url == sanitized)
        return;
    m_camera4Url = sanitized;
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
