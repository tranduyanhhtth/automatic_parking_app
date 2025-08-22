#include "cameramanager.h"
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QBuffer>
#include <QDateTime>

static QImage ensureFormat(const QImage &src)
{
    if (src.format() == QImage::Format_ARGB32 || src.format() == QImage::Format_RGB32 || src.format() == QImage::Format_RGB888)
        return src;
    return src.convertToFormat(QImage::Format_ARGB32);
}

CameraManager::CameraManager(QObject *parent)
    : QObject(parent), m_inputSink(new QVideoSink(this)), m_outputSink(new QVideoSink(this))
{
    // Theo dõi khung hình mới để lưu ảnh cuối cùng
    connect(m_inputSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame)
            {
        if (!frame.isValid()) return;
        m_lastInputFrame = frame;
        m_lastInputMs = QDateTime::currentMSecsSinceEpoch();
        if (m_inputStalled) { m_inputStalled = false; } });
    connect(m_outputSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame)
            {
        if (!frame.isValid()) return;
        m_lastOutputFrame = frame;
        m_lastOutputMs = QDateTime::currentMSecsSinceEpoch();
        if (m_outputStalled) { m_outputStalled = false; } });

    // Watchdog: phát hiện đứng hình (>3s no frames)
    m_watchdog.setInterval(1000);
    connect(&m_watchdog, &QTimer::timeout, this, [this]()
            {
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (m_inputSink && (now - m_lastInputMs) > 3000) {
            if (!m_inputStalled) { m_inputStalled = true; emit inputStreamStalled(); }
        }
        if (m_outputSink && (now - m_lastOutputMs) > 3000) {
            if (!m_outputStalled) { m_outputStalled = true; emit outputStreamStalled(); }
        } });
    m_watchdog.start();
}

void CameraManager::setInputVideoSink(QVideoSink *sink)
{
    if (!sink || m_inputSink == sink)
        return;
    m_inputSink = sink;
    if (m_inputSinkConn)
        QObject::disconnect(m_inputSinkConn);
    m_inputSinkConn = connect(m_inputSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame)
                              {
        if (!frame.isValid()) return;
        m_lastInputFrame = frame;
        m_lastInputMs = QDateTime::currentMSecsSinceEpoch();
        if (m_inputStalled) { m_inputStalled = false; } });
    emit inputVideoSinkChanged();
}

void CameraManager::setOutputVideoSink(QVideoSink *sink)
{
    if (!sink || m_outputSink == sink)
        return;
    m_outputSink = sink;
    if (m_outputSinkConn)
        QObject::disconnect(m_outputSinkConn);
    m_outputSinkConn = connect(m_outputSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame)
                               {
        if (!frame.isValid()) return;
        m_lastOutputFrame = frame;
        m_lastOutputMs = QDateTime::currentMSecsSinceEpoch();
        if (m_outputStalled) { m_outputStalled = false; } });
    emit outputVideoSinkChanged();
}

QByteArray CameraManager::encodeJpeg(const QImage &img, int quality)
{
    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    QImage toSave = ensureFormat(img);
    toSave.save(&buffer, "JPG", quality);
    return bytes;
}

QString CameraManager::makeDataUrl(const QByteArray &jpegBytes)
{
    return QString::fromLatin1("data:image/jpeg;base64,%1").arg(QString::fromLatin1(jpegBytes.toBase64()));
}

QByteArray CameraManager::captureInputSnapshot(int quality)
{
    if (!m_lastInputFrame.isValid())
        return {};
    QImage img = QVideoFrame(m_lastInputFrame).toImage();
    if (img.isNull())
        return {};
    auto bytes = encodeJpeg(img, quality);
    m_inputSnapshotDataUrl = makeDataUrl(bytes);
    emit inputSnapshotChanged();
    return bytes;
}

QByteArray CameraManager::captureOutputSnapshot(int quality)
{
    if (!m_lastOutputFrame.isValid())
        return {};
    QImage img = QVideoFrame(m_lastOutputFrame).toImage();
    if (img.isNull())
        return {};
    auto bytes = encodeJpeg(img, quality);
    m_outputSnapshotDataUrl = makeDataUrl(bytes);
    emit outputSnapshotChanged();
    return bytes;
}
