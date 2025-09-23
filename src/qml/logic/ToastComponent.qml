import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: parent.width
    height: parent.height
    z: 9999

    property alias externalModel: listView.model

    // Show toast only when model has items
    visible: listView.count > 0

    ListView {
        id: listView
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
        spacing: 10
        clip: true
        orientation: ListView.Vertical
        verticalLayoutDirection: ListView.BottomToTop
        width: Math.min(root.width * 0.8, 400)

        delegate: Rectangle {
            id: toastItem
            width: parent.width
            height: contentText.implicitHeight + 32
            radius: 10
            color: {
                switch(sev) {
                    case 'error': return '#e53935'
                    case 'warn': return '#fb8c00'
                    case 'success': return '#43a047'
                    case 'info': return '#1e88e5'
                    default: return '#757575'
                }
            }
            border.color: "#333"
            opacity: sev === 'fade' ? 0.5 : 1.0

            Behavior on opacity { NumberAnimation { duration: 300 } }

            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    id: contentText
                    text: count > 1 ? text + " (" + count + ")" : text
                    color: "white"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    width: parent.width - 24
                }
            }
        }
    }
}
