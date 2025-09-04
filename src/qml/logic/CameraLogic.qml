import QtQuick
import QtMultimedia

Item {
    property int lane1InRetryMs: 1000
    property int lane1OutRetryMs: 1000
    property int lane2InRetryMs: 1000
    property int lane2OutRetryMs: 1000

    Timer { id: lane1InRetry; interval: lane1InRetryMs; repeat: false; onTriggered: cameraLane1.startInputStream(settings.camera1Url) }
    Timer { id: lane1OutRetry; interval: lane1OutRetryMs; repeat: false; onTriggered: cameraLane1.startOutputStream(settings.camera2Url) }
    Timer { id: lane2InRetry; interval: lane2InRetryMs; repeat: false; onTriggered: cameraLane2.startInputStream(settings.camera3Url) }
    Timer { id: lane2OutRetry; interval: lane2OutRetryMs; repeat: false; onTriggered: cameraLane2.startOutputStream(settings.camera4Url) }

    Connections {
        target: settings
        function onCamera1UrlChanged() { cameraLane1.startInputStream(settings.camera1Url) }
        function onCamera2UrlChanged() { cameraLane1.startOutputStream(settings.camera2Url) }
        function onCamera3UrlChanged() { cameraLane2.startInputStream(settings.camera3Url) }
        function onCamera4UrlChanged() { cameraLane2.startOutputStream(settings.camera4Url) }
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

    function startStreams() {
        console.log("[QML] Starting all camera streams...")

        console.log("[QML] Starting Lane 1 input stream:", settings.camera1Url)
        cameraLane1.startInputStream(settings.camera1Url)

        console.log("[QML] Starting Lane 1 output stream:", settings.camera2Url)
        cameraLane1.startOutputStream(settings.camera2Url)

        console.log("[QML] Starting Lane 2 input stream:", settings.camera3Url)
        cameraLane2.startInputStream(settings.camera3Url)

        console.log("[QML] Starting Lane 2 output stream:", settings.camera4Url)
        cameraLane2.startOutputStream(settings.camera4Url)

        console.log("[QML] All camera streams started")
    }
}