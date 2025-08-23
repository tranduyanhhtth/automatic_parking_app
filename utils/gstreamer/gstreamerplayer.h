#pragma once
#include <QObject>
#include <QImage>
#include <QString>
#include <QTimer>

// GStreamer core headers are required here for callback typedefs (gboolean, gpointer, GstFlowReturn)
#include <gst/gst.h>
#include <gst/app/app.h>

class GStreamerPlayer : public QObject
{
    Q_OBJECT
public:
    explicit GStreamerPlayer(QObject *parent = nullptr);
    ~GStreamerPlayer() override;

    Q_INVOKABLE bool start(const QString &rtspUrl);
    Q_INVOKABLE void stop();
    void setPreferHardwareDecode(bool on) { m_preferHwDecode = on; }

signals:
    void newFrame(const QImage &frame);
    void errorOccured(const QString &message);
    void stateChanged(const QString &state);

private:
    bool startAttempt(int attempt);
    bool buildPipelineForAttempt(int attempt);
    void armNoFrameTimer(int ms);
    void scheduleRetry(int ms);
    void teardownPipeline();
    static QImage sampleToImage(GstSample *sample);
    static gboolean onBusMessage(GstBus *bus, GstMessage *message, gpointer user_data);
    static GstFlowReturn onNewSample(GstAppSink *sink, gpointer user_data);
    static bool hasElement(const char *name);
    void cleanup();

    GstElement *m_pipeline{nullptr};
    GstElement *m_appsink{nullptr};
    QString m_url;
    bool m_preferHwDecode{true};

    // Resilience
    int m_attempt{0};
    QTimer m_retryTimer;   // backoff retry when error/no frames
    QTimer m_noFrameTimer; // detect no frames after PLAYING
    bool m_firstFrameSeen{false};
};
