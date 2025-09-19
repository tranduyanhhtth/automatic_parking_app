// import QtQuick
// import QtQuick.Controls

// Item {
//     id: toast
//     anchors.fill: parent
//     // Passive visual-only component; logic handled externally
//     property color infoColor: '#323232'
//     property color successColor: '#2e7d32'
//     property color warnColor: '#f9a825'
//     property color errorColor: '#c62828'
//     property color textColor: 'white'
//     // External model must provide: id, text, sev, count, fading(optional)
//     property var externalModel: null

//     Repeater {
//         id: repeater
//         model: toast.externalModel
//         delegate: Rectangle {
//             width: parent.width * 0.28
//             height: txt.implicitHeight + 20
//             radius: 8
//             opacity: (sev === 'fade' ? 0 : 0.95)
//             anchors.horizontalCenter: parent.horizontalCenter
//             y: parent.height - (index + 1) * (height + 10) - 16
//             color: sev === 'success' ? successColor : (sev === 'warn' ? warnColor : (sev === 'error' ? errorColor : infoColor))
//             Behavior on y {
//                 NumberAnimation {
//                     duration: 180
//                     easing.type: Easing.OutCubic
//                 }
//             }
//             Behavior on opacity {
//                 NumberAnimation {
//                     duration: 220
//                 }
//             }
//             MouseArea {
//                 anchors.fill: parent
//                 onClicked: if (parent && model
//                                    && model.removeIndex !== undefined)
//                                parent.opacity = 0
//             }
//             Row {
//                 anchors.fill: parent
//                 anchors.margins: 10
//                 spacing: 8
//                 Rectangle {
//                     width: 6
//                     radius: 2
//                     color: (sev === 'success' ? '#81c784' : (sev === 'warn' ? '#ffe082' : (sev === 'error' ? '#ef9a9a' : '#90a4ae')))
//                     anchors.top: parent.top
//                     anchors.bottom: parent.bottom
//                 }
//                 Text {
//                     id: txt
//                     text: (model.text + (model.count > 1 ? ' (x' + model.count + ')' : ''))
//                     color: textColor
//                     wrapMode: Text.Wrap
//                     font.pixelSize: 14
//                     width: parent.width - 30
//                 }
//             }
//         }
//     }
// }
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
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                // Rectangle {
                //     width: 6
                //     radius: 2
                //     color: (sev === 'success' ? '#81c784' : (sev === 'warn' ? '#ffe082' : (sev === 'error' ? '#ef9a9a' : '#90a4ae')))
                //     anchors.top: parent.top
                //     anchors.bottom: parent.bottom
                // }
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
