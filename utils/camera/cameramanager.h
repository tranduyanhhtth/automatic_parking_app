#pragma once
#include <QObject>
#include <QVideoSink>
#include "domain/ports/icamerasnapshotprovider.h"
#include <QDebug>
#include <QImage>
#include <QVideoFrame>
#include <QBuffer>
#include <QElapsedTimer>
#include <QTimer>

class CameraManager : public QObject, public ICameraSnapshotProvider
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink *inputVideoSink READ inputVideoSink NOTIFY inputVideoSinkChanged)
    Q_PROPERTY(QVideoSink *outputVideoSink READ outputVideoSink NOTIFY outputVideoSinkChanged)
    Q_PROPERTY(QString inputSnapshotDataUrl READ inputSnapshotDataUrl NOTIFY inputSnapshotChanged)
    Q_PROPERTY(QString outputSnapshotDataUrl READ outputSnapshotDataUrl NOTIFY outputSnapshotChanged)

public:
    explicit CameraManager(QObject *parent = nullptr);

    QVideoSink *inputVideoSink() const { return m_inputSink; }
    QVideoSink *outputVideoSink() const { return m_outputSink; }
    QString inputSnapshotDataUrl() const { return m_inputSnapshotDataUrl; }
    QString outputSnapshotDataUrl() const { return m_outputSnapshotDataUrl; }

public slots:
    // Nhận QVideoSink từ QML (VideoOutput.videoSink)
    void setInputVideoSink(QVideoSink *sink) override;
    void setOutputVideoSink(QVideoSink *sink) override;

    // Chụp ảnh hiện tại (JPEG) từ mỗi camera;
    Q_INVOKABLE QByteArray captureInputSnapshot(int quality = 85) override;
    Q_INVOKABLE QByteArray captureOutputSnapshot(int quality = 85) override;

    // Xóa dữ liệu xem trước để UI trống ảnh ngay lập tức
    Q_INVOKABLE void clearSnapshots() override
    {
        if (!m_inputSnapshotDataUrl.isEmpty())
        {
            m_inputSnapshotDataUrl.clear();
            emit inputSnapshotChanged();
        }
        if (!m_outputSnapshotDataUrl.isEmpty())
        {
            m_outputSnapshotDataUrl.clear();
            emit outputSnapshotChanged();
        }
    }

signals:
    void inputVideoSinkChanged();
    void outputVideoSinkChanged();
    void inputSnapshotChanged();
    void outputSnapshotChanged();
    void inputStreamStalled();
    void outputStreamStalled();

private:
    QVideoSink *m_inputSink;
    QVideoSink *m_outputSink;

    // Khung hình cuối cùng và dữ liệu xem trước
    QVideoFrame m_lastInputFrame;
    QVideoFrame m_lastOutputFrame;
    QString m_inputSnapshotDataUrl;
    QString m_outputSnapshotDataUrl;

    // Chuyển ảnh sang JPEG và tạo data URL
    static QByteArray encodeJpeg(const QImage &img, int quality);
    static QString makeDataUrl(const QByteArray &jpegBytes);

    QMetaObject::Connection m_inputSinkConn;
    QMetaObject::Connection m_outputSinkConn;

    // Stall detection
    qint64 m_lastInputMs{0};
    qint64 m_lastOutputMs{0};
    bool m_inputStalled{false};
    bool m_outputStalled{false};
    QTimer m_watchdog;
};
