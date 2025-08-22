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
            var u1 = applyRtspOptions(settings.camera1Url)
            setSourceAndRestart(camera1, u1)
        }
    }
    Timer {
        id: cam2Retry; interval: window.cam2RetryMs; repeat: false
        onTriggered: {
            var u2 = applyRtspOptions(settings.camera2Url)
            setSourceAndRestart(camera2, u2)
        }
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
        audioOutput: null
        autoPlay: false
        // Gợi ý độ trễ thấp cho các luồng mạng
        property bool lowLatency: true
    }
    MediaPlayer {
        id: camera2
        videoOutput: form.outputVideoOutput
        audioOutput: null
        autoPlay: false
        // Gợi ý độ trễ thấp cho các luồng mạng
        property bool lowLatency: true
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

    function setSourceAndRestart(player, url) {
        // Fully reset the backend to avoid stuck state when reusing same URL
        player.stop()
        player.source = "" // force detach
        player.source = url
        // Try to disable audio track entirely if supported by backend
        if (player.activeAudioTrack !== undefined)
            player.activeAudioTrack = -1
        player.play()
    }

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
    function setSourceIfChanged(player, url) {
        var cur = normalizeUrl(player.source)
        var tgt = normalizeUrl(url)
        var okState = (player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia)
        if (cur === tgt && okState) {
            if (player.activeAudioTrack !== undefined)
                player.activeAudioTrack = -1
            return
        }
        setSourceAndRestart(player, tgt)
    }

    function isHealthy(player) {
        return player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia
    }

    function loadCongVao() {
        var u1 = applyRtspOptions(settings.camera1Url)
        var u2 = applyRtspOptions(settings.camera2Url)
        var changed1 = normalizeUrl(camera1.source) !== normalizeUrl(u1)
        var changed2 = normalizeUrl(camera2.source) !== normalizeUrl(u2)
        if (changed1 || changed2) {
            cam1Retry.stop(); cam2Retry.stop();
            window.cam1RetryMs = 1000; window.cam2RetryMs = 1000
        }
        setSourceIfChanged(camera1, u1)
        setSourceIfChanged(camera2, u2)
    }

    function loadCongRa() {
        var u1 = applyRtspOptions(settings.camera1Url)
        var u2 = applyRtspOptions(settings.camera2Url)
        var changed1 = normalizeUrl(camera1.source) !== normalizeUrl(u1)
        var changed2 = normalizeUrl(camera2.source) !== normalizeUrl(u2)
        if (changed1 || changed2) {
            cam1Retry.stop(); cam2Retry.stop();
            window.cam1RetryMs = 1000; window.cam2RetryMs = 1000
        }
        setSourceIfChanged(camera1, u1)
        setSourceIfChanged(camera2, u2)
    }
    function sourcesMatchSettings() {
        var u1 = applyRtspOptions(settings.camera1Url)
        var u2 = applyRtspOptions(settings.camera2Url)
        return normalizeUrl(camera1.source) === normalizeUrl(u1)
               && normalizeUrl(camera2.source) === normalizeUrl(u2)
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
    Connections {
        target: camera1
        function onErrorChanged() {
            // backoff tới tối đa 10s
            window.cam1RetryMs = Math.min(window.cam1RetryMs * 2, 10000)
            if (form && form.hidLogModel)
                form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam1 error: " + camera1.error + " " + camera1.errorString})
            cam1Retry.restart()
        }
        function onMediaStatusChanged() {
            if (camera1.mediaStatus === MediaPlayer.StalledMedia || camera1.mediaStatus === MediaPlayer.InvalidMedia) {
                window.cam1RetryMs = Math.min(window.cam1RetryMs * 2, 10000)
                if (form && form.hidLogModel)
                    form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam1 status: " + camera1.mediaStatus})
                cam1Retry.restart()
            } else if (camera1.mediaStatus === MediaPlayer.LoadedMedia || camera1.mediaStatus === MediaPlayer.BufferedMedia) {
                window.cam1RetryMs = 1000
                if (camera1.activeAudioTrack !== undefined)
                    camera1.activeAudioTrack = -1
                if (form && form.hidLogModel)
                    form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam1 status: OK"})
            }
        }
    }
    Connections {
        target: camera2
        function onErrorChanged() {
            window.cam2RetryMs = Math.min(window.cam2RetryMs * 2, 10000)
            if (form && form.hidLogModel)
                form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam2 error: " + camera2.error + " " + camera2.errorString})
            cam2Retry.restart()
        }
        function onMediaStatusChanged() {
            if (camera2.mediaStatus === MediaPlayer.StalledMedia || camera2.mediaStatus === MediaPlayer.InvalidMedia) {
                window.cam2RetryMs = Math.min(window.cam2RetryMs * 2, 10000)
                if (form && form.hidLogModel)
                    form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam2 status: " + camera2.mediaStatus})
                cam2Retry.restart()
            } else if (camera2.mediaStatus === MediaPlayer.LoadedMedia || camera2.mediaStatus === MediaPlayer.BufferedMedia) {
                window.cam2RetryMs = 1000
                if (camera2.activeAudioTrack !== undefined)
                    camera2.activeAudioTrack = -1
                if (form && form.hidLogModel)
                    form.hidLogModel.append({"display": Qt.formatTime(new Date(), "hh:mm:ss") + " cam2 status: OK"})
            }
        }
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
