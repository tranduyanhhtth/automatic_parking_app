import QtQuick
import QtQuick.Controls

Item {
    id: toast
    anchors.fill: parent
    // Passive visual-only component; logic handled externally
    property color infoColor: '#1e88e5'
    property color successColor: '#64b568'
    property color warnColor: '#f9a825'
    property color errorColor: '#c62828'
    property color textColor: 'white'
    // External model must provide: id, text, sev, count, fading(optional)
    property var externalModel: null

    Repeater {
        id: repeater
        model: toast.externalModel
        delegate: Rectangle {
            width: parent.width
            height: txt.implicitHeight + 25
            opacity: (sev === 'fade' ? 0 : 0.8)
            anchors.horizontalCenter: parent.horizontalCenter
            y: index * height
            color: sev === 'success' ? successColor : (sev === 'warn' ? warnColor : (sev === 'error' ? errorColor : infoColor))
            Behavior on y {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (parent && model
                                   && model.removeIndex !== undefined)
                               parent.opacity = 0
            }
            Item {
                anchors.fill: parent
                anchors.margins: 10
                Text {
                    id: txt
                    anchors.centerIn: parent
                    text: (model.text + (model.count > 1 ? ' (x' + model.count + ')' : ''))
                    color: textColor
                    font.pixelSize: 20
                    font.bold: false
                }
            }
        }
    }
}
