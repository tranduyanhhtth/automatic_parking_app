import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import QtQml
import QtQml.Models

Item {
    id: window
    // Lane 1
    property alias inputVideoLane1: inputVideoLane1
    property alias outputVideoLane1: outputVideoLane1
    property alias inputPreviewLane1: inputPreviewLane1
    property alias outputPreviewLane1: outputPreviewLane1
    // Lane 2
    property alias inputVideoLane2: inputVideoLane2
    property alias outputVideoLane2: outputVideoLane2
    property alias inputPreviewLane2: inputPreviewLane2
    property alias outputPreviewLane2: outputPreviewLane2

    // Bỏ nút Mở/Đóng thủ công ở panel giữa (đã loại bỏ)
    property alias btnSettings: btnSettings
    property alias settingsMenu: settingsMenu
    property alias cameraSettingsDialog: cameraSettingsDialog
    property alias barrierSettingsDialog: barrierSettingsDialog
    property alias tfCam1: tfCam1
    property alias tfCam2: tfCam2
    property alias tfCam3: tfCam3
    property alias tfCam4: tfCam4
    // Barrier settings (two separate sections)
    property alias tfCom1: tfCom1
    property alias cbBaud1: cbBaud1
    property alias tfCom2: tfCom2
    property alias cbBaud2: cbBaud2
    property alias miCamera: miCamera
    property alias miBarrier: miBarrier
    property alias miExit: miExit

    width: 1920
    height: 1080
    property string timeInText: ""
    property string timeOutText: ""

    Rectangle {
        anchors.fill: parent
        color: "#f0f0f0"

        ColumnLayout {
            anchors.fill: parent
            spacing: 2

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
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                border.width: 1
                border.color: "#888"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // ===== LANE 1 =====
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 4
                        color: "transparent"
                        border.width: 1
                        border.color: "#aaa"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            anchors.bottomMargin: 38
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                height: 60
                                color: "white"
                                border.color: "gray"
                                border.width: 1
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: "CỔNG VÀO"
                                    font.bold: true
                                    font.pixelSize: 24
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Lane1 - Camera trước + preview
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Text {
                                        text: "CAMERA TRƯỚC"
                                        font.bold: true
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "#ddd"
                                        border.color: "#999"
                                        border.width: 2
                                        VideoOutput {
                                            id: inputVideoLane1
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            fillMode: VideoOutput.PreserveAspectFit
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Camera Vào L1"
                                                color: "black"
                                                font.pixelSize: 14
                                                visible: !inputVideoLane1.videoSink
                                                         || inputVideoLane1.videoSink.videoSize.width === 0
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "black"
                                        Image {
                                            id: inputPreviewLane1
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            cache: false
                                            source: (cameraLane1.inputSnapshotDataUrl
                                                     || "")
                                        }
                                    }
                                }

                                // Lane1 - Camera sau + preview
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Text {
                                        text: "CAMERA SAU"
                                        font.bold: true
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "#ddd"
                                        border.color: "#999"
                                        border.width: 2
                                        VideoOutput {
                                            id: outputVideoLane1
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            fillMode: VideoOutput.PreserveAspectFit
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Camera Ra L1"
                                                color: "black"
                                                font.pixelSize: 14
                                                visible: !outputVideoLane1.videoSink
                                                         || outputVideoLane1.videoSink.videoSize.width === 0
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "black"
                                        Image {
                                            id: outputPreviewLane1
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            cache: false
                                            source: (cameraLane1.outputSnapshotDataUrl
                                                     || "")
                                        }
                                    }
                                }
                            }

                            // Thông tin CỔNG VÀO
                            ColumnLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    color: "white"
                                    border.color: "#bbb"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 14
                                        Text {
                                            text: "SỐ THẺ:"
                                            font.bold: true
                                            Layout.preferredWidth: 110
                                        }
                                        Text {
                                            text: app.entranceCardId || ""
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "BIỂN SỐ:"
                                            font.bold: true
                                            Layout.preferredWidth: 110
                                        }
                                        Text {
                                            text: app.entrancePlate || ""
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    color: "white"
                                    border.color: "#bbb"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 14
                                        Text {
                                            text: "THỜI GIAN VÀO:"
                                            font.bold: true
                                            Layout.preferredWidth: 150
                                        }
                                        Text {
                                            text: app.entranceTimeIn || ""
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "LOẠI THẺ:"
                                            font.bold: true
                                            Layout.preferredWidth: 120
                                        }
                                        Text {
                                            text: app.entranceCardType
                                                  || "Vãng lai"
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Panel giữa bị loại bỏ
                    Item {
                        Layout.preferredWidth: 5
                        Layout.fillHeight: true
                    }

                    // ===== LANE 2 =====
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 4
                        color: "transparent"
                        border.width: 1
                        border.color: "#aaa"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            anchors.bottomMargin: 38
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                height: 60
                                color: "white"
                                border.color: "gray"
                                border.width: 1
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: "CỔNG RA"
                                    font.bold: true
                                    font.pixelSize: 24
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Lane2 - Camera trước + preview
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Text {
                                        text: "CAMERA TRƯỚC"
                                        font.bold: true
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "#ddd"
                                        border.color: "#999"
                                        border.width: 2
                                        VideoOutput {
                                            id: inputVideoLane2
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            fillMode: VideoOutput.PreserveAspectFit
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Camera Vào L2"
                                                color: "black"
                                                font.pixelSize: 14
                                                visible: !inputVideoLane2.videoSink
                                                         || inputVideoLane2.videoSink.videoSize.width === 0
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "black"
                                        Image {
                                            id: inputPreviewLane2
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            cache: false
                                            source: (app.exitReviewAvailable ? (app.exitImage1DataUrl || "") : (cameraLane2.inputSnapshotDataUrl || ""))
                                        }
                                    }
                                }

                                // Lane2 - Camera sau + preview
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Text {
                                        text: "CAMERA SAU"
                                        font.bold: true
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "#ddd"
                                        border.color: "#999"
                                        border.width: 2
                                        VideoOutput {
                                            id: outputVideoLane2
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            fillMode: VideoOutput.PreserveAspectFit
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Camera Ra L2"
                                                color: "black"
                                                font.pixelSize: 14
                                                visible: !outputVideoLane2.videoSink
                                                         || outputVideoLane2.videoSink.videoSize.width === 0
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 260
                                        color: "black"
                                        Image {
                                            id: outputPreviewLane2
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            cache: false
                                            source: (app.exitReviewAvailable ? (app.exitImage2DataUrl || "") : (cameraLane2.outputSnapshotDataUrl || ""))
                                        }
                                    }
                                }
                            }

                            // Thông tin CỔNG RA
                            ColumnLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    color: "white"
                                    border.color: "#bbb"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 14
                                        Text {
                                            text: "SỐ THẺ:"
                                            font.bold: true
                                            Layout.preferredWidth: 110
                                        }
                                        Text {
                                            text: app.exitCardId || ""
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "BIỂN SỐ:"
                                            font.bold: true
                                            Layout.preferredWidth: 110
                                        }
                                        Text {
                                            text: app.exitPlate || ""
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    color: "white"
                                    border.color: "#bbb"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 14
                                        Text {
                                            text: "THỜI GIAN VÀO:"
                                            font.bold: true
                                            Layout.preferredWidth: 150
                                        }
                                        Text {
                                            text: app.exitTimeIn || ""
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "THỜI GIAN RA:"
                                            font.bold: true
                                            Layout.preferredWidth: 150
                                        }
                                        Text {
                                            text: app.exitTimeOut || ""
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Khối thông báo tiền cho từng loại thẻ
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 46
                    color: "#FFF7E0"
                    border.color: "#E0C97A"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        Text {
                            text: "THÔNG BÁO TIỀN:"
                            font.bold: true
                            color: "#8A6D3B"
                        }
                        Text {
                            text: app.moneyMessage || ""
                            color: "#8A6D3B"
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
            Label {
                text: "Camera 3 URL"
            }
            TextField {
                id: tfCam3
                text: settings.camera3Url
                Layout.preferredWidth: 520
            }
            Label {
                text: "Camera 4 URL"
            }
            TextField {
                id: tfCam4
                text: settings.camera4Url
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
            spacing: 14
            GroupBox {
                title: "Barrier 1 (Làn 1)"
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.margins: 8
                    spacing: 8
                    Label {
                        text: "Cổng COM"
                    }
                    TextField {
                        id: tfCom1
                        text: settings.barrier1Port
                        Layout.preferredWidth: 260
                        placeholderText: "VD: COM3"
                    }
                    Label {
                        text: "Baudrate"
                    }
                    ComboBox {
                        id: cbBaud1
                        model: [9600, 19200, 38400, 57600, 115200]
                    }
                }
            }
            GroupBox {
                title: "Barrier 2 (Làn 2)"
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.margins: 8
                    spacing: 8
                    Label {
                        text: "Cổng COM"
                    }
                    TextField {
                        id: tfCom2
                        text: settings.barrier2Port
                        Layout.preferredWidth: 260
                        placeholderText: "VD: COM4"
                    }
                    Label {
                        text: "Baudrate"
                    }
                    ComboBox {
                        id: cbBaud2
                        model: [9600, 19200, 38400, 57600, 115200]
                    }
                }
            }
        }
    }
}
