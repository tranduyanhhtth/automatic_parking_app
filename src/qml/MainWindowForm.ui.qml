import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import QtQml
import QtQml.Models

Item {
    id: window
    property alias inputVideoOutput: inputVideo
    property alias outputVideoOutput: outputVideo
    property alias inputPreview: inputPreview
    property alias outputPreview: outputPreview
    property alias btnCongVao: btnCongVao
    property alias btnCongRa: btnCongRa
    property alias btnOpenButton: btnOpen
    property alias btnClose: btnClose

    property alias btnSettings: btnSettings
    property alias settingsMenu: settingsMenu
    property alias cameraSettingsDialog: cameraSettingsDialog
    property alias barrierSettingsDialog: barrierSettingsDialog
    property alias tfCam1: tfCam1
    property alias tfCam2: tfCam2
    property alias tfCom: tfCom
    property alias cbBaud: cbBaud
    property alias miCamera: miCamera
    property alias miBarrier: miBarrier
    property alias miExit: miExit

    // HID log aliases
    property alias hidLogModel: hidLogModel
    property alias hidLogView: hidLogView
    width: 1920
    height: 1080
    property string timeInText: ""
    property string timeOutText: ""

    Rectangle {
        anchors.fill: parent
        color: "#f0f0f0"

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: "black"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text {
                        text: "BÃI ĐỖ XE TỰ ĐỘNG"
                        font.bold: true
                        font.pixelSize: 28
                        color: "white"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ToolButton {
                        id: btnSettings
                        text: "⚙"
                        font.pixelSize: 20
                        Accessible.name: "Settings"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }
                    Menu {
                        id: settingsMenu
                        y: btnSettings.height
                        MenuItem {
                            id: miCamera
                            text: "Cấu hình Camera"
                        }
                        MenuItem {
                            id: miBarrier
                            text: "Cấu hình Barrier"
                        }
                        MenuSeparator {}
                        MenuItem {
                            id: miExit
                            text: "Thoát ứng dụng"
                        }
                    }
                }
            }

            // Main content
            RowLayout {
                height: 580
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Camera trước
                ColumnLayout {
                    spacing: 10
                    Layout.fillHeight: true
                    Layout.preferredWidth: 3

                    Text {
                        text: "CAMERA TRƯỚC"
                        font.bold: true
                        font.pixelSize: 24
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 360
                        color: "#ddd"
                        border.color: "#999"
                        border.width: 2

                        VideoOutput {
                            id: inputVideo
                            anchors.fill: parent
                            anchors.margins: 2
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            fillMode: VideoOutput.PreserveAspectFit

                            Text {
                                anchors.centerIn: parent
                                text: "Camera Vào\n"
                                color: "black"
                                font.pixelSize: 16
                                visible: !inputVideo.videoSink
                                         || inputVideo.videoSink.videoSize.width === 0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 712
                        height: 356
                        Layout.fillWidth: true
                        Layout.preferredHeight: 356
                        color: "black"
                        Image {
                            id: inputPreview
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            source: app.gateMode === 1
                                    && app.exitReviewAvailable ? app.exitImage1DataUrl : cameraManager.inputSnapshotDataUrl
                        }
                    }

                    Text {
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Camera
                ColumnLayout {
                    spacing: 10
                    Layout.fillHeight: true
                    Layout.preferredWidth: 3

                    Text {
                        text: "CAMERA SAU"
                        font.bold: true
                        font.pixelSize: 24
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 360
                        color: "#ddd"
                        border.color: "#999"
                        border.width: 2

                        VideoOutput {
                            id: outputVideo
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: VideoOutput.PreserveAspectFit

                            Text {
                                anchors.centerIn: parent
                                text: "Camera Ra\n"
                                color: "black"
                                font.pixelSize: 16
                                visible: !outputVideo.videoSink
                                         || outputVideo.videoSink.videoSize.width === 0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 356
                        color: "black"
                        Image {
                            id: outputPreview
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            source: app.gateMode === 1
                                    && app.exitReviewAvailable ? app.exitImage2DataUrl : cameraManager.outputSnapshotDataUrl
                        }
                    }

                    Text {
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Panel bên phải
                ColumnLayout {
                    spacing: 30
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "white"
                        border.color: "gray"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: " BIỂN SỐ XE: " + (app.plate || "")
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    // Rectangle {
                    //     Layout.fillWidth: true
                    //     height: 40
                    //     color: "white"
                    //     border.color: "gray"
                    //     Text {
                    //         anchors.left: parent.left
                    //         anchors.verticalCenter: parent.verticalCenter
                    //         text: " TỔNG SỐ XE: " + app.openCount
                    //         font.pixelSize: 18
                    //         font.bold: true
                    //     }
                    // }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "white"
                        border.color: "gray"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: " THỜI GIAN VÀO: " + (window.timeInText || "")
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "white"
                        border.color: "gray"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: " THỜI GIAN RA: " + (window.timeOutText || "")
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "white"
                        border.color: "gray"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: " ID THẺ: " + (app.lastRfid || "")
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "white"
                        border.color: "gray"
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: " TIỀN: "
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        height: 180
                        spacing: 20
                        Layout.fillWidth: true

                        // Log khu vực: hiển thị debugLog từ cardReader
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: "#111"
                            radius: 4
                            border.color: "#444"
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4
                                Text {
                                    text: "HID LOG"
                                    color: "#ccc"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                ListView {
                                    id: hidLogView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: hidLogModel
                                    delegate: Text {
                                        text: model.display
                                        font.pixelSize: 12
                                        color: "#9f9"
                                        wrapMode: Text.NoWrap
                                    }
                                }
                                ListModel {
                                    id: hidLogModel
                                }
                                Connections {
                                    target: cardReader
                                    function onDebugLog(msg) {
                                        hidLogModel.append({
                                                               "display": Qt.formatTime(
                                                                              new Date(),
                                                                              "hh:mm:ss") + " "
                                                                          + msg
                                                           })
                                        if (hidLogModel.count > 200)
                                            hidLogModel.remove(
                                                        0,
                                                        hidLogModel.count - 200)
                                        hidLogView.positionViewAtEnd()
                                    }
                                }
                                Connections {
                                    target: app
                                    function onLastRfidChanged() {
                                        if (app.gateMode === 1 && app.lastRfid)
                                            app.loadExitReview(app.lastRfid)
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Button {
                                id: btnCongVao
                                width: 237
                                height: 60
                                text: "CỔNG VÀO"
                                font.pixelSize: 18
                                Layout.fillWidth: true
                                background: Rectangle {
                                    radius: 4
                                    color: app.gateMode === 0 ? "#2d6cdf" : "#555"
                                }
                            }

                            Button {
                                id: btnCongRa
                                width: 237
                                height: 60
                                x: 236.5
                                text: "CỔNG RA"
                                font.pixelSize: 18
                                Layout.fillWidth: true

                                background: Rectangle {
                                    radius: 4
                                    color: app.gateMode === 1 ? "#c95020" : "#555"
                                }
                            }
                        }

                        Button {
                            id: btnOpen
                            height: 60
                            text: "MỞ"
                            font.pixelSize: 18
                            Layout.fillWidth: true
                        }

                        Button {
                            id: btnClose
                            height: 60
                            text: "ĐÓNG"
                            font.pixelSize: 18
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: cameraSettingsDialog
        title: "Cấu hình Camera"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10
            Label {
                text: "Camera 1 URL"
            }
            TextField {
                id: tfCam1
                text: settings.camera1Url
                Layout.preferredWidth: 520
            }
            Label {
                text: "Camera 2 URL"
            }
            TextField {
                id: tfCam2
                text: settings.camera2Url
                Layout.preferredWidth: 520
            }
        }
    }

    Dialog {
        id: barrierSettingsDialog
        title: "Cấu hình Barrier"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10
            Label {
                text: "Cổng COM"
            }
            TextField {
                id: tfCom
                text: settings.barrierPort
                Layout.preferredWidth: 260
                placeholderText: "VD: COM3"
            }
            Label {
                text: "Baudrate"
            }
            ComboBox {
                id: cbBaud
                model: [9600, 19200, 38400, 57600, 115200]
            }
        }
    }
}
