#include "gstreamerplayer.h"
#include <QDebug>
#include <QAtomicInt>
#include <QByteArray>
#include <QCoreApplication>
#include <QDir>

// GStreamer includes
#include <gst/gst.h>
#include <gst/app/app.h>
#include <gst/video/video.h>

GStreamerPlayer::GStreamerPlayer(QObject *parent) : QObject(parent)
{
    static QAtomicInt inited{0};
    if (inited.fetchAndAddRelaxed(0) == 0)
    {
        // Prefer the system-installed plugin directory; fall back to a local bundled folder
        if (qEnvironmentVariableIsEmpty("GST_PLUGIN_PATH"))
        {
            const QString systemPlugins = QStringLiteral("C:/Program Files/gstreamer/1.0/msvc_x86_64/lib/gstreamer-1.0");
            const QString appDir = QCoreApplication::applicationDirPath();
            const QString localPlugins = QDir::toNativeSeparators(appDir + "/gstreamer-1.0");

            const bool hasSystem = QDir(systemPlugins).exists();
            const bool hasLocal = QDir(localPlugins).exists();
            if (hasSystem && hasLocal)
            {
                // On Windows, ';' separates multiple paths
                const QString combined = QDir(systemPlugins).absolutePath() + ";" + localPlugins;
                qputenv("GST_PLUGIN_PATH", combined.toUtf8());
            }
            else if (hasSystem)
            {
                qputenv("GST_PLUGIN_PATH", QDir(systemPlugins).absolutePath().toUtf8());
            }
            else if (hasLocal)
            {
                qputenv("GST_PLUGIN_PATH", localPlugins.toUtf8());
            }
        }

        // Prefer RTSP over TCP to work reliably behind NAT/firewalls unless overridden
        if (qEnvironmentVariableIsEmpty("GST_RTSP_TCP"))
        {
            qputenv("GST_RTSP_TCP", QByteArray("1"));
        }
        // Allow user override; otherwise enable moderate debug
        if (qEnvironmentVariableIsEmpty("GST_DEBUG"))
        {
            qputenv("GST_DEBUG", QByteArray("2"));
        }

        // Ensure system GStreamer bin is on PATH for loader resolution when launched from IDE
        const QString gstBin = QStringLiteral("C:/Program Files/gstreamer/1.0/msvc_x86_64/bin");
        if (QDir(gstBin).exists())
        {
            const QByteArray currentPath = qgetenv("PATH");
            const QString prefix = QDir::toNativeSeparators(gstBin);
            if (!QString::fromUtf8(currentPath).contains(prefix, Qt::CaseInsensitive))
            {
                qputenv("PATH", (prefix + ";" + QString::fromUtf8(currentPath)).toUtf8());
            }
        }

        gst_init(nullptr, nullptr);
        inited.storeRelease(1);

        qDebug() << "GStreamer initialized. GST_PLUGIN_PATH=" << qEnvironmentVariable("GST_PLUGIN_PATH")
                 << " GST_RTSP_TCP=" << qEnvironmentVariable("GST_RTSP_TCP")
                 << " GST_DEBUG=" << qEnvironmentVariable("GST_DEBUG");

        // Quick diagnostics for common missing plugins
        auto warnMissing = [](const char *elem, const char *pkg)
        {
            if (!hasElement(elem))
            {
                qWarning() << "[GStreamer] Missing element" << elem << "- install package:" << pkg;
            }
        };
        warnMissing("rtspsrc", "gst-plugins-good");
        warnMissing("playbin", "gstreamer");
        warnMissing("uridecodebin", "gstreamer");
        warnMissing("videoconvert", "gst-plugins-base");
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

        // Try next attempt if available
        int nextAttempt = (attempt + 1) % 2;
        if (nextAttempt != attempt && nextAttempt != m_attempt)
        {
            scheduleRetry(500);
            return false;
        }

        return false;
    }

    GstBus *bus = gst_element_get_bus(m_pipeline);
    gst_bus_add_watch(bus, &GStreamerPlayer::onBusMessage, this);
    gst_object_unref(bus);

    gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
    emit stateChanged(QStringLiteral("PLAYING"));
    m_firstFrameSeen = false;
    // Allow more time for initial keyframe on some RTSP cams
    armNoFrameTimer(8000);
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
    // attempt 0: playbin(playbin3) with custom appsink video-sink (codec agnostic)
    // attempt 1: fallback using uridecodebin (also codec agnostic, simpler linking)
    const bool hasD3D11 = hasElement("d3d11h265dec") && hasElement("d3d11convert") && hasElement("d3d11download");
    bool useHw = m_preferHwDecode && hasD3D11;

    if (attempt == 0)
    {
        // Build playbin and route its video to our appsink; drop audio
        GstElement *player = gst_element_factory_make("playbin3", "player");
        if (!player)
            player = gst_element_factory_make("playbin", "player");
        if (!player)
        {
            emit errorOccured(QStringLiteral("Failed to create playbin"));
            return false;
        }

        // Video sink bin: convert to RGBA on CPU and push to appsink
        GError *err = nullptr;
        GstElement *videoBin = gst_parse_bin_from_description(
            "videoconvert ! video/x-raw,format=RGBA ! appsink name=mysink sync=false max-buffers=1 drop=true",
            TRUE, &err);
        if (!videoBin)
        {
            QString msg = QStringLiteral("Failed to create video sink bin: %1").arg(err ? QString::fromUtf8(err->message) : QString());
            if (err)
                g_error_free(err);
            gst_object_unref(player);
            emit errorOccured(msg);
            return false;
        }

        // Audio sink: fakesink to ignore audio
        GstElement *audioSink = gst_element_factory_make("fakesink", "audiosink0");
        if (!audioSink)
        {
            gst_object_unref(videoBin);
            gst_object_unref(player);
            emit errorOccured(QStringLiteral("Failed to create fakesink"));
            return false;
        }

        // Configure playbin
        QByteArray uriUtf8 = m_url.toUtf8();
        g_object_set(G_OBJECT(player), "uri", uriUtf8.constData(), nullptr);
        g_object_set(G_OBJECT(player), "video-sink", videoBin, nullptr);
        g_object_set(G_OBJECT(player), "audio-sink", audioSink, nullptr);

        m_pipeline = player;
        // Grab appsink from the video sink bin we just created
        m_appsink = gst_bin_get_by_name(GST_BIN(videoBin), "mysink");
        if (!m_appsink)
        {
            emit errorOccured(QStringLiteral("appsink not found in playbin"));
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
    else
    {
        // Simpler, codec-agnostic chain via uridecodebin
        QString qUrl = m_url;
        qUrl.replace("\"", "\\\"");
        QByteArray quotedUrl = QByteArray("\"") + qUrl.toUtf8() + QByteArray("\"");

        // uridecodebin handles RTSP and dynamic pads; link to videoconvert -> appsink
        // uridecodebin will internally use rtspsrc; prefer TCP via GST_RTSP_TCP env
        QByteArray pipeStr = QByteArray("uridecodebin uri=") + quotedUrl +
                             QByteArray(" ! videoconvert ! video/x-raw,format=RGBA ! appsink name=mysink sync=false max-buffers=1 drop=true");

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

    GstVideoInfo vinfo;
    if (!gst_video_info_from_caps(&vinfo, caps))
        return {};

    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_READ))
        return {};

    // Respect stride from caps
    int width = GST_VIDEO_INFO_WIDTH(&vinfo);
    int height = GST_VIDEO_INFO_HEIGHT(&vinfo);
    int stride = GST_VIDEO_INFO_PLANE_STRIDE(&vinfo, 0);
    if (stride <= 0)
        stride = width * 4; // fallback for RGBA

    QImage img((const uchar *)map.data, width, height, stride, QImage::Format_RGBA8888);
    QImage copy = img.copy();
    gst_buffer_unmap(buffer, &map);
    return copy;
}
