import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQml

Item {
    id: window
    width: 1920
    height: 1080

    // UI layout
    MainWindowForm {
        id: form
        anchors.fill: parent
    }

    // Nhận tín hiệu toast từ controller
    Connections {
        target: app
        function onShowToast(message) {
            toast.show(message)
        }
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
        // Feed formatted times to the UI form (no logic inside .ui.qml)
        form.timeInText = formatIsoLocal(app.checkInTime)
        form.timeOutText = formatIsoLocal(app.checkOutTime)
    }

    function loadCongVao() {
        camera1.source = settings.camera1Url
        camera2.source = settings.camera2Url
        camera1.play()
        camera2.play()
    }

    // Bind sinks on startup; most apps don’t change sinks at runtime

    function loadCongRa() {
        // For now, reuse; could be separate settings if needed
        camera1.source = settings.camera1Url
        camera2.source = settings.camera2Url
        camera1.play()
        camera2.play()
    }
    
    function formatIsoLocal(iso) {
        if (!iso)
            return ""
        var d = new Date(iso)
        if (isNaN(d))
            return iso
        return Qt.formatDateTime(d, "dd/MM/yyyy HH:mm:ss")
    }

    // Button events from
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

    // Reload cameras if settings change
    Connections {
        target: settings
        function onCamera1UrlChanged() { loadCongVao() }
        function onCamera2UrlChanged() { loadCongVao() }
    }

    Connections {
        target: form.btnSettings
        function onClicked() {
            var p = form.btnSettings.mapToGlobal(0, form.btnSettings.height)
            form.settingsMenu.popup(p.x, p.y)
        }
    }
    Connections {
        target: form.miCamera
        function onTriggered() { form.cameraSettingsDialog.open() }
    }
    Connections {
        target: form.miBarrier
        function onTriggered() {
            // Sync baud selection to settings before showing
            var idx = form.cbBaud.model.indexOf(settings.barrierBaud)
            form.cbBaud.currentIndex = idx >= 0 ? idx : 0
            form.barrierSettingsDialog.open()
        }
    }
    Connections {
        target: form.miExit
        function onTriggered() { Qt.quit() }
    }
    Connections {
        target: form.cameraSettingsDialog
        function onAccepted() {
            settings.camera1Url = form.tfCam1.text
            settings.camera2Url = form.tfCam2.text
            settings.save()
        }
    }
    Connections {
        target: form.barrierSettingsDialog
        function onAccepted() {
            var newCom = form.tfCom.text
            var newBaud = parseInt(form.cbBaud.currentText)
            var oldCom = barrier.portName
            var oldBaud = barrier.baudRate
            settings.barrierPort = newCom
            settings.barrierBaud = newBaud
            settings.save()
            if (oldCom !== newCom) {
                barrier.disconnectPort()
                barrier.portName = newCom
                barrier.connectPort()
            }
            if (oldBaud !== newBaud) {
                barrier.setBaudRate(newBaud)
            }
        }
    }
    Connections {
        target: form.btnCongVao
        function onClicked() { app.gateMode = 0 }
    }
    Connections {
        target: form.btnCongRa
        function onClicked() { app.gateMode = 1 }
    }
    Connections {
        target: form.btnOpenButton
        function onClicked() {
            barrier.open()
        }
    }
    Connections {
        target: form.btnClose
        function onClicked() {
            barrier.close()
        }
    }

    // Toast thông báo
    Rectangle {
        id: toast
        width: parent.width
        height: visible ? 60 : 0
        anchors.top: parent.top
        color: "#88000000"
        visible: false
        opacity: 0
        z: 9999
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            id: toastText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 22
            text: ""
        }
        Timer { id: toastTimer; interval: 1800; running: false; repeat: false; onTriggered: { toast.visible = false; toast.opacity = 0 } }
        function show(msg) {
            toastText.text = msg
            toast.visible = true
            toast.opacity = 1
            toastTimer.restart()
        }
    }
    Connections {
        target: cardReader
        function onDebugLog(msg) {
            form.hidLogModel.append({
                "display": Qt.formatTime(new Date(), "hh:mm:ss") + " " + msg
            })
            if (form.hidLogModel.count > 200)
                form.hidLogModel.remove(0, form.hidLogModel.count - 200)
            form.hidLogView.positionViewAtEnd()
        }
    }
    Connections {
        target: app
        function onLastRfidChanged() {
            if (app.gateMode === 1 && app.lastRfid)
                app.loadExitReview(app.lastRfid)
        }
    }
    Connections {
        target: app
        function onGateModeChanged() {
            if (app.gateMode === 1) {
                loadCongRa()
            } else {
                loadCongVao()
            }
        }
    }
    Connections {
        target: app
        function onTimesChanged() {
            form.timeInText = formatIsoLocal(app.checkInTime)
            form.timeOutText = formatIsoLocal(app.checkOutTime)
        }
    }
}
