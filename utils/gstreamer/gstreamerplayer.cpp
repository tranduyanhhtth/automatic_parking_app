#include "gstreamerplayer.h"
#include <QDebug>
#include <QAtomicInt>
#include <QByteArray>

// GStreamer includes
#include <gst/gst.h>
#include <gst/app/app.h>

GStreamerPlayer::GStreamerPlayer(QObject *parent) : QObject(parent)
{
    static QAtomicInt inited{0};
    if (inited.fetchAndAddRelaxed(0) == 0)
    {
        gst_init(nullptr, nullptr);
        inited.storeRelease(1);
    }

    // Timers
    m_retryTimer.setSingleShot(true);
    connect(&m_retryTimer, &QTimer::timeout, this, [this]()
            {
        // Always execute attempt on our own thread
        startAttempt(m_attempt); });
    m_noFrameTimer.setSingleShot(true);
    connect(&m_noFrameTimer, &QTimer::timeout, this, [this]()
            {
        if (!m_firstFrameSeen) {
            emit errorOccured(QStringLiteral("No frames received – retrying"));
            // Ensure retry happens on our thread
            scheduleRetry(1500);
        } });
}

GStreamerPlayer::~GStreamerPlayer()
{
    stop();
}

void GStreamerPlayer::cleanup()
{
    if (m_pipeline)
    {
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
        gst_object_unref(m_pipeline);
        m_pipeline = nullptr;
        m_appsink = nullptr;
    }
    // Stop timers on our thread
    QMetaObject::invokeMethod(this, [this]()
                              { m_noFrameTimer.stop(); m_retryTimer.stop(); }, Qt::QueuedConnection);
}

bool GStreamerPlayer::start(const QString &rtspUrl)
{
    stop();
    m_url = rtspUrl;
    if (rtspUrl.trimmed().isEmpty())
    {
        emit errorOccured(QStringLiteral("RTSP URL is empty"));
        return false;
    }
    m_attempt = 0;
    m_firstFrameSeen = false;
    return startAttempt(m_attempt);
}

void GStreamerPlayer::stop()
{
    cleanup();
    emit stateChanged(QStringLiteral("STOPPED"));
}

bool GStreamerPlayer::startAttempt(int attempt)
{
    teardownPipeline();
    if (!buildPipelineForAttempt(attempt))
    {
        emit errorOccured(QStringLiteral("Failed to build pipeline (attempt %1)").arg(attempt));
        return false;
    }

    GstBus *bus = gst_element_get_bus(m_pipeline);
    gst_bus_add_watch(bus, &GStreamerPlayer::onBusMessage, this);
    gst_object_unref(bus);

    gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
    emit stateChanged(QStringLiteral("PLAYING"));
    m_firstFrameSeen = false;
    armNoFrameTimer(3000);
    return true;
}

void GStreamerPlayer::teardownPipeline()
{
    if (m_pipeline)
    {
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
        gst_object_unref(m_pipeline);
        m_pipeline = nullptr;
        m_appsink = nullptr;
    }
}

bool GStreamerPlayer::buildPipelineForAttempt(int attempt)
{
    // attempt 0: uridecodebin (codec agnostic), attempt 1: explicit rtspsrc+h264
    const bool hasD3D11 = hasElement("d3d11h264dec") && hasElement("d3d11convert") && hasElement("d3d11download");
    bool useHw = m_preferHwDecode && hasD3D11;
    QString qUrl = m_url;
    qUrl.replace("\"", "\\\"");
    QByteArray quotedUrl = QByteArray("\"") + qUrl.toUtf8() + QByteArray("\"");

    QByteArray pipeStr;
    if (attempt == 0)
    {
        // uridecodebin handles rtsp:// gracefully and picks depay/parse/decoder
        pipeStr = QByteArray("uridecodebin uri=") + quotedUrl +
                  QByteArray(" ! videoconvert ! video/x-raw,format=RGBA ! appsink name=mysink sync=false max-buffers=1 drop=true");
    }
    else
    {
        QByteArray decoder;
        if (useHw && hasD3D11)
            decoder = QByteArray("d3d11h264dec ! d3d11convert ! d3d11download !");
        else
            decoder = QByteArray("decodebin !");
        pipeStr = QByteArray("rtspsrc location=") + quotedUrl +
                  QByteArray(" protocols=tcp latency=0 ! rtph264depay ! h264parse ! queue max-size-buffers=1 leaky=downstream ! ") +
                  decoder + QByteArray(" videoconvert ! video/x-raw,format=RGBA ! appsink name=mysink sync=false max-buffers=1 drop=true");
    }

    GError *err = nullptr;
    m_pipeline = gst_parse_launch(pipeStr.constData(), &err);
    if (!m_pipeline)
    {
        QString msg = QStringLiteral("GStreamer parse error: %1").arg(err ? QString::fromUtf8(err->message) : QStringLiteral("unknown"));
        if (err)
            g_error_free(err);
        emit errorOccured(msg);
        return false;
    }

    m_appsink = gst_bin_get_by_name(GST_BIN(m_pipeline), "mysink");
    if (!m_appsink)
    {
        emit errorOccured(QStringLiteral("appsink not found"));
        cleanup();
        return false;
    }
    gst_app_sink_set_emit_signals((GstAppSink *)m_appsink, true);
    gst_app_sink_set_drop((GstAppSink *)m_appsink, true);
    gst_app_sink_set_max_buffers((GstAppSink *)m_appsink, 1);

    GstAppSinkCallbacks cbs = {};
    cbs.new_sample = &GStreamerPlayer::onNewSample;
    gst_app_sink_set_callbacks(GST_APP_SINK(m_appsink), &cbs, this, nullptr);
    return true;
}

void GStreamerPlayer::armNoFrameTimer(int ms)
{
    // Start timer on our own thread to avoid cross-thread warnings
    QMetaObject::invokeMethod(this, [this, ms]()
                              { m_noFrameTimer.start(ms); }, Qt::QueuedConnection);
}

void GStreamerPlayer::scheduleRetry(int ms)
{
    // Queue teardown and retry on our own thread
    QMetaObject::invokeMethod(this, [this, ms]()
                              {
        teardownPipeline();
        m_attempt = (m_attempt + 1) % 2; // alternate attempts 0 and 1
        m_retryTimer.start(ms); }, Qt::QueuedConnection);
}

GstFlowReturn GStreamerPlayer::onNewSample(GstAppSink *sink, gpointer user_data)
{
    auto *self = static_cast<GStreamerPlayer *>(user_data);
    GstSample *sample = gst_app_sink_pull_sample(sink);
    if (!sample)
        return GST_FLOW_OK;
    QImage img = sampleToImage(sample);
    gst_sample_unref(sample);
    if (!img.isNull())
    {
        if (!self->m_firstFrameSeen)
        {
            // Flip flag and stop timer on the QObject's thread
            QMetaObject::invokeMethod(self, [self]()
                                      {
                self->m_firstFrameSeen = true;
                self->m_noFrameTimer.stop();
                emit self->stateChanged(QStringLiteral("FIRST_FRAME")); }, Qt::QueuedConnection);
        }
        // Emit frame (Qt will queue across threads if needed)
        emit self->newFrame(img);
    }
    return GST_FLOW_OK;
}

gboolean GStreamerPlayer::onBusMessage(GstBus *bus, GstMessage *message, gpointer user_data)
{
    Q_UNUSED(bus)
    auto *self = static_cast<GStreamerPlayer *>(user_data);
    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_ERROR:
    {
        GError *err = nullptr;
        gchar *debug = nullptr;
        gst_message_parse_error(message, &err, &debug);
        const QString msg = QStringLiteral("Gst error: %1").arg(err ? QString::fromUtf8(err->message) : QString());
        if (err)
            g_error_free(err);
        if (debug)
            g_free(debug);
        emit self->errorOccured(msg);
        self->scheduleRetry(1500);
        break;
    }
    case GST_MESSAGE_EOS:
    {
        emit self->stateChanged(QStringLiteral("EOS"));
        self->scheduleRetry(1000);
        break;
    }
    default:
        break;
    }
    return TRUE;
}

bool GStreamerPlayer::hasElement(const char *name)
{
    GstElementFactory *f = gst_element_factory_find(name);
    if (f)
    {
        gst_object_unref(f);
        return true;
    }
    return false;
}

QImage GStreamerPlayer::sampleToImage(GstSample *sample)
{
    if (!sample)
        return {};
    GstBuffer *buffer = gst_sample_get_buffer(sample);
    GstCaps *caps = gst_sample_get_caps(sample);
    if (!buffer || !caps)
        return {};

    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_READ))
        return {};

    // Try to read video info from caps
    GstStructure *s = gst_caps_get_structure(caps, 0);
    int width = 0, height = 0;
    gst_structure_get_int(s, "width", &width);
    gst_structure_get_int(s, "height", &height);
    QImage img((const uchar *)map.data, width, height, QImage::Format_RGBA8888);
    img = img.copy();
    gst_buffer_unmap(buffer, &map);
    return img;
}
