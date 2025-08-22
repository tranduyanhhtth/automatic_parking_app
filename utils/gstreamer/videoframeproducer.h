#pragma once
#include <QObject>
#include <QPointer>
#include <QImage>
#include <QVideoSink>
#include <QVideoFrame>
#include <QVideoFrameFormat>

class VideoFrameProducer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink *videoSink READ videoSink WRITE setVideoSink NOTIFY videoSinkChanged)
public:
    explicit VideoFrameProducer(QObject *parent = nullptr) : QObject(parent) {}

    QVideoSink *videoSink() const { return m_sink.data(); }
    void setVideoSink(QVideoSink *s)
    {
        if (m_sink == s)
            return;
        m_sink = s;
        emit videoSinkChanged();
    }

public slots:
    void pushImage(const QImage &img)
    {
        if (!m_sink)
            return;
        // Convert source to RGBA8888 for a simple copy
        QImage src = (img.format() == QImage::Format_RGBA8888)
                         ? img
                         : img.convertToFormat(QImage::Format_RGBA8888);
        QVideoFrameFormat fmt(src.size(), QVideoFrameFormat::Format_RGBA8888);
        QVideoFrame frame(fmt);
        if (!frame.map(QVideoFrame::WriteOnly))
            return;
        uchar *dstPtr = frame.bits(0);
        const int dstStride = frame.bytesPerLine(0);
        const int srcStride = src.bytesPerLine();
        const int copyBytes = qMin(dstStride, srcStride);
        for (int y = 0; y < src.height(); ++y)
        {
            memcpy(dstPtr + y * dstStride, src.constScanLine(y), copyBytes);
        }
        frame.unmap();
        m_sink->setVideoFrame(frame);
    }

signals:
    void videoSinkChanged();

private:
    QPointer<QVideoSink> m_sink;
};
