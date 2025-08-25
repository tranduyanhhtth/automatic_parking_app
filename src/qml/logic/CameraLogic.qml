import QtQuick
import QtMultimedia

Item {
    property int lane1InRetryMs: 1000
    property int lane1OutRetryMs: 1000
    property int lane2InRetryMs: 1000
    property int lane2OutRetryMs: 1000

    Timer { id: lane1InRetry; interval: lane1InRetryMs; repeat: false; onTriggered: cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url)) }
    Timer { id: lane1OutRetry; interval: lane1OutRetryMs; repeat: false; onTriggered: cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url)) }
    Timer { id: lane2InRetry; interval: lane2InRetryMs; repeat: false; onTriggered: cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url)) }
    Timer { id: lane2OutRetry; interval: lane2OutRetryMs; repeat: false; onTriggered: cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url)) }

    Connections {
        target: settings
        function onCamera1UrlChanged() { cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url)) }
        function onCamera2UrlChanged() { cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url)) }
        function onCamera3UrlChanged() { cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url)) }
        function onCamera4UrlChanged() { cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url)) }
    }

    Connections {
        target: cameraLane1
        function onInputStreamStalled() {
            lane1InRetryMs = Math.min(lane1InRetryMs * 2, 10000)
            lane1InRetry.restart()
        }
        function onOutputStreamStalled() {
            lane1OutRetryMs = Math.min(lane1OutRetryMs * 2, 10000)
            lane1OutRetry.restart()
        }
    }
    Connections {
        target: cameraLane2
        function onInputStreamStalled() {
            lane2InRetryMs = Math.min(lane2InRetryMs * 2, 10000)
            lane2InRetry.restart()
        }
        function onOutputStreamStalled() {
            lane2OutRetryMs = Math.min(lane2OutRetryMs * 2, 10000)
            lane2OutRetry.restart()
        }
    }

    function applyRtspOptions(url) {
        if (!url || url.indexOf('rtsp://') !== 0) return url
        var hasTcp = url.indexOf('rtsp_transport=') !== -1
        var hasTimeout = url.indexOf('stimeout=') !== -1
        var hasAudioFlag = url.indexOf('audio=') !== -1
        var hasFFlags = url.indexOf('fflags=') !== -1
        var hasProbe = url.indexOf('probesize=') !== -1
        var hasAnalyze = url.indexOf('analyzeduration=') !== -1
        var hasMaxDelay = url.indexOf('max_delay=') !== -1
        var hasBufSize = url.indexOf('buffer_size=') !== -1
        var hasReorder = url.indexOf('reorder_queue_size=') !== -1
        var sep = url.indexOf('?') === -1 ? '?' : '&'
        if (!hasTcp) { url += sep + 'rtsp_transport=tcp'; sep = '&' }
        if (!hasTimeout) url += sep + 'stimeout=5000000'
        if (!hasAudioFlag) url += sep + 'audio=0'
        if (!hasFFlags) url += sep + 'fflags=nobuffer'
        if (!hasProbe) url += sep + 'probesize=32768'
        if (!hasAnalyze) url += sep + 'analyzeduration=0'
        if (!hasMaxDelay) url += sep + 'max_delay=100000'
        if (!hasBufSize) url += sep + 'buffer_size=524288'
        if (!hasReorder) url += sep + 'reorder_queue_size=0'
        return url
    }

    function startStreams() {
        cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url))
        cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url))
        cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url))
        cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url))
    }
}