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
}

bool GStreamerPlayer::start(const QString &rtspUrl)
{
    stop();
    m_url = rtspUrl;

    // Build pipeline: prefer hardware decoder when available
    bool useHw = m_preferHwDecode;
#ifdef _WIN32
    useHw = useHw && hasElement("d3d11h264dec");
#else
    // Extend for other platforms/codecs if needed
#endif
    QByteArray decoder = useHw ? QByteArray("d3d11h264dec !") : QByteArray("decodebin !");
    // Force RGBA at appsink to simplify mapping to QImage
    QByteArray pipeStr = QByteArray("rtspsrc location=") + rtspUrl.toUtf8() +
                         QByteArray(" latency=0 protocols=tcp drop-on-late=true ! ") +
                         QByteArray("rtpjitterbuffer drop-on-late=true do-lost=true latency=0 ! ") +
                         QByteArray("rtph264depay ! queue max-size-buffers=1 leaky=downstream ! ") +
                         decoder + QByteArray(" videoconvert ! video/x-raw,format=RGBA ! appsink name=mysink sync=false max-buffers=1 drop=true");

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

    GstBus *bus = gst_element_get_bus(m_pipeline);
    gst_bus_add_watch(bus, &GStreamerPlayer::onBusMessage, this);
    gst_object_unref(bus);

    gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
    emit stateChanged(QStringLiteral("PLAYING"));
    return true;
}

void GStreamerPlayer::stop()
{
    cleanup();
    emit stateChanged(QStringLiteral("STOPPED"));
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
        emit self->newFrame(img);
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
        break;
    }
    case GST_MESSAGE_EOS:
    {
        emit self->stateChanged(QStringLiteral("EOS"));
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
