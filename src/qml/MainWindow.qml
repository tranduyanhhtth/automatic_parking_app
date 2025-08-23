import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQml

Item {
    id: window
    width: 1920
    height: 1080
    focus: true
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F9) { hidLogPanel.visible = !hidLogPanel.visible; e.accepted = true }
        else if (e.key === Qt.Key_F5) {
            if (form && form.settingsMenu && form.btnSettings) {
                if (form.settingsMenu.visible) {
                    form.settingsMenu.close()
                } else {
                    var p = form.btnSettings.mapToGlobal(0, form.btnSettings.height)
                    form.settingsMenu.popup(p.x, p.y)
                }
                e.accepted = true
            }
        }
    }

    // UI layout
    MainWindowForm {
        id: form
        anchors.fill: parent
    }

    // Retry timers cho từng làn (input/output)
    property int lane1InRetryMs: 1000
    property int lane1OutRetryMs: 1000
    property int lane2InRetryMs: 1000
    property int lane2OutRetryMs: 1000

    // HID LOG model and helpers
    ListModel { id: hidLogModel }
    function addHidLog(source, msg) {
        var time = Qt.formatTime(new Date(), "HH:mm:ss")
        hidLogModel.append({ t: time, s: source, m: msg })
        if (hidLogModel.count > 200)
            hidLogModel.remove(0, hidLogModel.count - 200)
    }

    Timer { id: lane1InRetry; interval: window.lane1InRetryMs; repeat: false; onTriggered: cameraLane1.startInputStream(settings.camera1Url) }
    Timer { id: lane1OutRetry; interval: window.lane1OutRetryMs; repeat: false; onTriggered: cameraLane1.startOutputStream(settings.camera2Url) }
    Timer { id: lane2InRetry; interval: window.lane2InRetryMs; repeat: false; onTriggered: cameraLane2.startInputStream(settings.camera3Url) }
    Timer { id: lane2OutRetry; interval: window.lane2OutRetryMs; repeat: false; onTriggered: cameraLane2.startOutputStream(settings.camera4Url) }

    // Nhận tín hiệu toast từ controller
    Connections {
        target: app
        function onShowToast(message) {
            toast.show(message)
        }
    }

    // Controller debug logs to HID LOG
    Connections {
        target: app
        function onDebugLog(message) { addHidLog("APP", message) }
    }

    // Collect HID logs from both readers
    Connections {
        target: cardReaderEntrance
        function onDebugLog(msg) { addHidLog("IN", msg) }
    }
    Connections {
        target: cardReaderExit
        function onDebugLog(msg) { addHidLog("OUT", msg) }
    }

    // Không còn dùng MediaPlayer FFmpeg; VideoOutput vẫn nhận QVideoSink từ CameraManager

    // Khởi động cả 2 làn, mỗi làn 2 camera
    Component.onCompleted: {
        // Lane 1 sinks
        if (form.inputVideoLane1 && form.inputVideoLane1.videoSink)
            cameraLane1.setInputVideoSink(form.inputVideoLane1.videoSink)
        if (form.outputVideoLane1 && form.outputVideoLane1.videoSink)
            cameraLane1.setOutputVideoSink(form.outputVideoLane1.videoSink)
        // Lane 2 sinks
        if (form.inputVideoLane2 && form.inputVideoLane2.videoSink)
            cameraLane2.setInputVideoSink(form.inputVideoLane2.videoSink)
        if (form.outputVideoLane2 && form.outputVideoLane2.videoSink)
            cameraLane2.setOutputVideoSink(form.outputVideoLane2.videoSink)

        // Start streams for both lanes
        cameraLane1.startInputStream(settings.camera1Url)
        cameraLane1.startOutputStream(settings.camera2Url)
        cameraLane2.startInputStream(settings.camera3Url)
        cameraLane2.startOutputStream(settings.camera4Url)

    // Format times if needed (not used in new layout directly)
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

    // MediaPlayer health check không còn dùng sau khi chuyển sang GStreamer
    function isHealthy(player) { return true }

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
        function onCamera1UrlChanged() { cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url)) }
        function onCamera2UrlChanged() { cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url)) }
        function onCamera3UrlChanged() { cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url)) }
        function onCamera4UrlChanged() { cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url)) }
    }

    Connections {
        target: cameraLane1
        function onInputStreamStalled() {
            window.lane1InRetryMs = Math.min(window.lane1InRetryMs * 2, 10000)
            lane1InRetry.restart()
        }
    }
    Connections {
        target: cameraLane1
        function onOutputStreamStalled() {
            window.lane1OutRetryMs = Math.min(window.lane1OutRetryMs * 2, 10000)
            lane1OutRetry.restart()
        }
    }
    Connections {
        target: cameraLane2
        function onInputStreamStalled() {
            window.lane2InRetryMs = Math.min(window.lane2InRetryMs * 2, 10000)
            lane2InRetry.restart()
        }
    }
    Connections {
        target: cameraLane2
        function onOutputStreamStalled() {
            window.lane2OutRetryMs = Math.min(window.lane2OutRetryMs * 2, 10000)
            lane2OutRetry.restart()
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
            // Sync both barriers
            var idx1 = form.cbBaud1.model.indexOf(settings.barrier1Baud)
            form.cbBaud1.currentIndex = idx1 >= 0 ? idx1 : 0
            form.tfCom1.text = settings.barrier1Port
            var idx2 = form.cbBaud2.model.indexOf(settings.barrier2Baud)
            form.cbBaud2.currentIndex = idx2 >= 0 ? idx2 : 0
            form.tfCom2.text = settings.barrier2Port
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
            settings.camera3Url = form.tfCam3.text
            settings.camera4Url = form.tfCam4.text
            settings.useHardwareDecode = form.cbHwDecode.checked
            settings.save()
            cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url))
            cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url))
            cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url))
            cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url))
        }
    }
    Connections {
        target: form.barrierSettingsDialog
        function onAccepted() {
            var newCom1 = form.tfCom1.text
            var newBaud1 = parseInt(form.cbBaud1.currentText)
            var newCom2 = form.tfCom2.text
            var newBaud2 = parseInt(form.cbBaud2.currentText)

            var oldCom1 = barrier1.portName
            var oldBaud1 = barrier1.baudRate
            var oldCom2 = barrier2.portName
            var oldBaud2 = barrier2.baudRate

            settings.barrier1Port = newCom1
            settings.barrier1Baud = newBaud1
            settings.barrier2Port = newCom2
            settings.barrier2Baud = newBaud2
            settings.save()

            if (oldCom1 !== newCom1) { barrier1.disconnectPort(); barrier1.portName = newCom1; barrier1.connectPort() }
            if (oldBaud1 !== newBaud1) { barrier1.setBaudRate(newBaud1) }
            if (oldCom2 !== newCom2) { barrier2.disconnectPort(); barrier2.portName = newCom2; barrier2.connectPort() }
            if (oldBaud2 !== newBaud2) { barrier2.setBaudRate(newBaud2) }
        }
    }
    // Không còn các nút mở/đóng ở panel giữa

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
    // HID LOG overlay (center) for debugging
    Rectangle {
        id: hidLogPanel
        width: Math.min(parent.width * 0.5, 900)
        height: Math.min(parent.height * 0.42, 420)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: "#CC000000"
        border.color: "#66FFFFFF"
        border.width: 1
        radius: 8
        z: 9000
        visible: false
        Item {
            anchors.fill: parent
            anchors.margins: 8
            // Header row
            Row {
                id: hidHeader
                height: 28
                spacing: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                Text { text: "HID LOG"; color: "white"; font.bold: true; font.pixelSize: 16 }
                Item { width: 8; height: 1 }
                Rectangle {
                    radius: 3; color: "#333"; border.color: "#666"; height: 22
                    Text { anchors.centerIn: parent; text: "Clear"; color: "white"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: hidLogModel.clear() }
                }
                Rectangle {
                    radius: 3; color: "#333"; border.color: "#666"; height: 22
                    Text { anchors.centerIn: parent; text: "Hide (F9)"; color: "white"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: hidLogPanel.visible = false }
                }
                Item { width: 1; height: 1 }
            }
            // Separator
            Rectangle { height: 1; color: "#44FFFFFF"; anchors.left: parent.left; anchors.right: parent.right; anchors.top: hidHeader.bottom; anchors.topMargin: 4 }
            // Log list
            ListView {
                id: hidList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: hidHeader.bottom
                anchors.topMargin: 8
                clip: true
                model: hidLogModel
                delegate: Row {
                    spacing: 6
                    Text { text: t; color: "#A0FFA0"; font.pixelSize: 12; width: 60 }
                    Text { text: s; color: "#A0A0FF"; font.pixelSize: 12; width: 36 }
                    Text { text: m; color: "white"; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; width: hidList.width - 60 - 36 - 24 }
                }
                onCountChanged: positionViewAtEnd()
            }
        }
    }
    // UI không còn panel giữa; review ảnh cổng ra vẫn tự nạp khi lastRfid đổi
    Connections {
        target: app
        function onTimesChanged() {
            form.timeInText = formatIsoLocal(app.checkInTime)
            form.timeOutText = formatIsoLocal(app.checkOutTime)
        }
    }
}
