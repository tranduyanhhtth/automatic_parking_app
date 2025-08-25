import QtQuick
import QtQuick.Controls

Item {
    Connections {
        target: form.btnSettings
        function onClicked() {
            var p = form.btnSettings.mapToGlobal(0, form.btnSettings.height)
            form.settingsMenu.popup(p.x, p.y)
        }
    }
    Connections {
        target: form.miCamera
        function onTriggered() {
            form.tfCam1.text = urlHead(settings.camera1Url)
            form.tfCam2.text = urlHead(settings.camera2Url)
            form.tfCam3.text = urlHead(settings.camera3Url)
            form.tfCam4.text = urlHead(settings.camera4Url)
            form.cameraSettingsDialog.dialog.open()
        }
    }
    Connections {
        target: form.miBarrier
        function onTriggered() {
            var idx1 = form.cbBaud1.model.indexOf(settings.barrier1Baud)
            form.cbBaud1.currentIndex = idx1 >= 0 ? idx1 : 0
            form.tfCom1.text = settings.barrier1Port
            var idx2 = form.cbBaud2.model.indexOf(settings.barrier2Baud)
            form.cbBaud2.currentIndex = idx2 >= 0 ? idx2 : 0
            form.tfCom2.text = settings.barrier2Port
            form.barrierSettingsDialog.dialog.open()
        }
    }
    Connections {
        target: form.miExit
        function onTriggered() { Qt.quit() }
    }
    Connections {
        target: form.cameraSettingsDialog.dialog
        function onAccepted() {
            settings.camera1Url = applyRtspOptions(form.tfCam1.text)
            settings.camera2Url = applyRtspOptions(form.tfCam2.text)
            settings.camera3Url = applyRtspOptions(form.tfCam3.text)
            settings.camera4Url = applyRtspOptions(form.tfCam4.text)
            settings.save()
            cameraLane1.startInputStream(applyRtspOptions(settings.camera1Url))
            cameraLane1.startOutputStream(applyRtspOptions(settings.camera2Url))
            cameraLane2.startInputStream(applyRtspOptions(settings.camera3Url))
            cameraLane2.startOutputStream(applyRtspOptions(settings.camera4Url))
        }
    }
    Connections {
        target: form.barrierSettingsDialog.dialog
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

    function urlHead(u) {
        var s = sourceToString(u)
        if (!s) return ""
        var i = s.indexOf('?')
        return i === -1 ? s : s.substring(0, i)
    }

    function sourceToString(src) {
        if (!src) return ""
        try {
            return src.toString ? src.toString() : ("" + src)
        } catch (e) {
            return "" + src
        }
    }
}