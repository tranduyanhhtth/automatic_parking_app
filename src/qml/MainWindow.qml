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

    // Trạng thái quay lại với thời gian chờ tự động kết nối
    property int cam1RetryMs: 1000
    property int cam2RetryMs: 1000

    Timer {
        id: cam1Retry; interval: window.cam1RetryMs; repeat: false
        onTriggered: {
            cameraManager.startInputStream(settings.camera1Url)
        }
    }
    Timer {
        id: cam2Retry; interval: window.cam2RetryMs; repeat: false
        onTriggered: {
            cameraManager.startOutputStream(settings.camera2Url)
        }
    }

    // Nhận tín hiệu toast từ controller
    Connections {
        target: app
        function onShowToast(message) {
            toast.show(message)
        }
    }

    // Không còn dùng MediaPlayer FFmpeg; VideoOutput vẫn nhận QVideoSink từ CameraManager

    // Default: load entrance cameras (.45 and .46)
    Component.onCompleted: {
        // Give CameraManager access to the live sinks for snapshotting
        if (form.inputVideoOutput && form.inputVideoOutput.videoSink)
            cameraManager.setInputVideoSink(form.inputVideoOutput.videoSink)
        if (form.outputVideoOutput && form.outputVideoOutput.videoSink)
            cameraManager.setOutputVideoSink(form.outputVideoOutput.videoSink)
            
        // Khởi động GStreamer với URL hiện tại
        cameraManager.startInputStream(settings.camera1Url)
        cameraManager.startOutputStream(settings.camera2Url)
        // Feed formatted times to the UI form (no logic inside .ui.qml)
        form.timeInText = formatIsoLocal(app.checkInTime)
        form.timeOutText = formatIsoLocal(app.checkOutTime)
    }

    // setSourceAndRestart/player logic đã bỏ khi chuyển sang GStreamer

    function sourceToString(src) {
        if (!src)
            return ""
        try {
            return src.toString ? src.toString() : ("" + src)
        } catch (e) {
            return "" + src
        }
    }

    function normalizeUrl(u) {
        var s = sourceToString(u)
        if (!s)
            return ""
        var parts = s.split('?')
        var base = parts[0]
        if (parts.length === 1)
            return base
        var q = parts[1]
        if (!q)
            return base
        var items = q.split('&').filter(function(x){ return x && x.length > 0 })
        items.sort()
        return base + '?' + items.join('&')
    }

    // Chỉ khởi động lại cam khi url thay đổi hoặc luồng stream không ổn
    function setSourceIfChanged(url1, url2) {
        // Với GStreamer, nếu URL thay đổi thì dừng và start lại
        cameraManager.stopStreams()
        cameraManager.startInputStream(url1)
        cameraManager.startOutputStream(url2)
    }

    function isHealthy(player) {
        return player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia
    }

    function loadCongVao() {
        var u1 = applyRtspOptions(settings.camera1Url)
        var u2 = applyRtspOptions(settings.camera2Url)
    setSourceIfChanged(u1, u2)
    }

    function loadCongRa() {
        var u1 = applyRtspOptions(settings.camera1Url)
        var u2 = applyRtspOptions(settings.camera2Url)
    setSourceIfChanged(u1, u2)
    }
    function sourcesMatchSettings() {
    // Với GStreamer, coi như luôn cần khởi động lại khi URL thực sự đổi (đã xử lý ở setSourceIfChanged)
    return true
    }

    // Bổ sung tùy chọn RTSP cho độ ổn định/độ trễ thấp nếu thiếu trong URL
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
        if (!hasTcp) url += sep + 'rtsp_transport=tcp', sep = '&'
        if (!hasTimeout) url += sep + 'stimeout=5000000'
        // Hint many cameras/servers to skip audio; ignored if unsupported
        if (!hasAudioFlag) url += sep + 'audio=0'
        // Low-latency demux/parse options (best-effort; ignored if unsupported)
        if (!hasFFlags) url += sep + 'fflags=nobuffer'
        if (!hasProbe) url += sep + 'probesize=32768'
        if (!hasAnalyze) url += sep + 'analyzeduration=0'
        if (!hasMaxDelay) url += sep + 'max_delay=100000'
        if (!hasBufSize) url += sep + 'buffer_size=524288'
        if (!hasReorder) url += sep + 'reorder_queue_size=0'
        return url
    }
    
    function formatIsoLocal(iso) {
        if (!iso)
            return ""
        // Chuỗi lưu trong DB là ISO (local, không có 'Z'), coi như local time
        var d = new Date(iso)
        if (isNaN(d))
            return iso
        return Qt.formatDateTime(d, "dd/MM/yyyy HH:mm:ss")
    }

    Connections {
        target: settings
        function onCamera1UrlChanged() { app.gateMode === 1 ? loadCongRa() : loadCongVao() }
        function onCamera2UrlChanged() { app.gateMode === 1 ? loadCongRa() : loadCongVao() }
    }

    Connections {
        target: cameraManager
        function onInputStreamStalled() {
            window.cam1RetryMs = Math.min(window.cam1RetryMs * 2, 10000)
            cam1Retry.restart()
        }
    }
    Connections {
        target: cameraManager
        function onOutputStreamStalled() {
            window.cam2RetryMs = Math.min(window.cam2RetryMs * 2, 10000)
            cam2Retry.restart()
        }
    }

    // Tự động reconnect khi luồng báo lỗi hoặc bị Stalled
    // Bỏ kết nối theo dõi MediaPlayer vì đã chuyển sang GStreamer

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
            // settings.ocrSpaceApiKey = form.tfOcrKey.text
            settings.useHardwareDecode = form.cbHwDecode.checked
            settings.save()
            app.gateMode === 1 ? loadCongRa() : loadCongVao()
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
        color: "#D04CAF50"
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
            if (sourcesMatchSettings()) {
                if (isHealthy(camera1) && isHealthy(camera2)) {
                    cam1Retry.stop(); cam2Retry.stop();
                }
                return
            }
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
