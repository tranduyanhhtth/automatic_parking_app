import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQml

ApplicationWindow {
    id: window
    width: 1920
    height: 1080
    visible: true
    title: qsTr("automatic parking")

    // UI layout
    MainWindowForm {
        id: form
        anchors.fill: parent
    }

    // Players for two RTSP cameras
    MediaPlayer {
        id: camera1
        videoOutput: form.inputVideoOutput
        audioOutput: AudioOutput {}
    }
    MediaPlayer {
        id: camera2
        videoOutput: form.outputVideoOutput
        audioOutput: AudioOutput {}
    }

    // Default: load entrance cameras (.45 and .46)
    Component.onCompleted: {
        // Give CameraManager access to the live sinks for snapshotting
        if (form.inputVideoOutput && form.inputVideoOutput.videoSink)
            cameraManager.setInputVideoSink(form.inputVideoOutput.videoSink)
        if (form.outputVideoOutput && form.outputVideoOutput.videoSink)
            cameraManager.setOutputVideoSink(form.outputVideoOutput.videoSink)
        loadCongVao()
    }

    function loadCongVao() {
        camera1.source = "rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0"
        camera2.source = "rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0"
        camera1.play()
        camera2.play()
    }

    // Rebind sinks if they change
    Connections {
        target: form.inputVideoOutput
        function onVideoSinkChanged() {
            if (form.inputVideoOutput.videoSink)
                cameraManager.setInputVideoSink(form.inputVideoOutput.videoSink)
        }
    }
    Connections {
        target: form.outputVideoOutput
        function onVideoSinkChanged() {
            if (form.outputVideoOutput.videoSink)
                cameraManager.setOutputVideoSink(form.outputVideoOutput.videoSink)
        }
    }

    function loadCongRa() {
        // If you have different IPs for exit, set them here; else reuse
        camera1.source = "rtsp://192.168.1.45:554/rtsp/streaming?channel=01&subtype=0"
        camera2.source = "rtsp://192.168.1.46:554/rtsp/streaming?channel=01&subtype=0"
        camera1.play()
        camera2.play()
    }

    // Button events from form
    Connections {
        target: form.btnCongVao
        function onClicked() { loadCongVao() }
    }
    Connections {
        target: form.btnCongRa
        function onClicked() { loadCongRa() }
    }

    // Reflect snapshot previews from CameraManager
    Connections {
        target: cameraManager
        function onInputSnapshotChanged() { form.inputPreview.source = cameraManager.inputSnapshotDataUrl }
        function onOutputSnapshotChanged() { form.outputPreview.source = cameraManager.outputSnapshotDataUrl }
    }

    // // Optional: test simulate swipe
    // footer: ToolBar {
    //     Row {
    //         spacing: 8
    //         anchors.margins: 8
    //         anchors.fill: parent
    //         Button { text: "Simulate Swipe RFID123"; onClicked: app.simulateSwipe("RFID123") }
    //     }
    // }
}
