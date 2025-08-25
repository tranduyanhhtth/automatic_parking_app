import QtQuick
import QtQuick.Controls

Rectangle {
    id: toast
    // Designer-safe: use trigger/message instead of function
    property bool triggerShow: false
    property string message: ""
    height: visible ? 60 : 0
    color: "#D04CAF50"
    visible: false
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Text {
        id: toastText
        anchors.centerIn: parent
        color: "white"
        font.pixelSize: 22
        text: toast.message
    }
    Timer {
        id: toastTimer
        interval: 1800
        running: false
        repeat: false
    }

    // Designer-safe handlers via Connections
    Connections {
        target: toastTimer
        function onTriggered() { toast.visible = false; toast.opacity = 0 }
    }
    Connections {
        target: toast
        function onTriggerShowChanged() {
            if (!toast.triggerShow) return
            toast.visible = true
            toast.opacity = 1
            toastTimer.restart()
        }
    }
}