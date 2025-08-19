#include "cameramanager.h"
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QBuffer>

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
        QImage img = QVideoFrame(frame).toImage();
        if (!img.isNull()) m_lastInputImage = img; });
    connect(m_outputSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame)
            {
        if (!frame.isValid()) return;
        QImage img = QVideoFrame(frame).toImage();
        if (!img.isNull()) m_lastOutputImage = img; });
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
        QImage img = QVideoFrame(frame).toImage();
        if (!img.isNull()) m_lastInputImage = img; });
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
        QImage img = QVideoFrame(frame).toImage();
        if (!img.isNull()) m_lastOutputImage = img; });
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
    if (m_lastInputImage.isNull())
        return {};
    auto bytes = encodeJpeg(m_lastInputImage, quality);
    m_inputSnapshotDataUrl = makeDataUrl(bytes);
    emit inputSnapshotChanged();
    return bytes;
}

QByteArray CameraManager::captureOutputSnapshot(int quality)
{
    if (m_lastOutputImage.isNull())
        return {};
    auto bytes = encodeJpeg(m_lastOutputImage, quality);
    m_outputSnapshotDataUrl = makeDataUrl(bytes);
    emit outputSnapshotChanged();
    return bytes;
}
