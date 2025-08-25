import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: hidLogPanel
    // Designer-safe: no ListModel or JS functions here
    property alias model: hidList.model
    property bool triggerClear: false
    color: "#CC000000"
    border.color: "#66FFFFFF"
    border.width: 1
    radius: 8
    Item {
        anchors.fill: parent
        anchors.margins: 8
        Row {
            id: hidHeader
            height: 28
            spacing: 8
            anchors.left: parent.left
            anchors.top: parent.top
            Text {
                text: "HID LOG"
                color: "white"
                font.bold: true
                font.pixelSize: 16
            }
            Item {
                width: 8
                height: 1
            }
            Rectangle {
                radius: 3
                color: "#333"
                border.color: "#666"
                height: 22

                MouseArea {
                    anchors.fill: parent
                    onClicked: hidLogPanel.triggerClear = !hidLogPanel.triggerClear
                }
            }
            Rectangle {
                radius: 3
                color: "#333"
                border.color: "#666"
                height: 22
                MouseArea {
                    anchors.fill: parent
                    onClicked: hidLogPanel.visible = false
                }
            }
            Item {
                width: 1
                height: 1
            }
        }
        Rectangle {
            height: 1
            color: "#44FFFFFF"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: hidHeader.bottom
            anchors.topMargin: 4
        }
        ListView {
            id: hidList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: hidHeader.bottom
            anchors.topMargin: 8
            clip: true
            // model is provided via alias: hidLogPanel.model
            currentIndex: (model && model.count > 0 ? model.count - 1 : -1)
            delegate: Row {
                spacing: 6
                Text {
                    text: t
                    color: "#A0FFA0"
                    font.pixelSize: 12
                    width: 60
                }
                Text {
                    text: s
                    color: "#A0A0FF"
                    font.pixelSize: 12
                    width: 36
                }
                Text {
                    text: m
                    color: "white"
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    width: hidList.width - 60 - 36 - 24
                }
            }
        }
    }
}
