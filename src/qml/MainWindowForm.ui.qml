import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia

Item {
    id: window
    // Expose internals for composition in MainWindow.qml
    property alias inputVideoOutput: inputVideo
    property alias outputVideoOutput: outputVideo
    property alias inputPreview: inputPreview
    property alias outputPreview: outputPreview
    property alias btnCongVao: btnCongVao
    property alias btnCongRa: btnCongRa
    width: 1920
    height: 1080

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
                Text {
                    anchors.centerIn: parent
                    text: "AUTOMATIC PARKING"
                    font.bold: true
                    font.pixelSize: 32
                    color: "white"
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
                                text: "Camera Vào\n(.45)"
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
                                text: "Camera Ra\n(.46)"
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
                            text: " BIỂN SỐ XE: "
                            font.pixelSize: 22
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
                            text: " TỔNG SỐ XE: "
                            font.pixelSize: 22
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
                            text: " THỜI GIAN VÀO: "
                            font.pixelSize: 22
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
                            text: " THỜI GIAN RA: "
                            font.pixelSize: 22
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
                            text: " ID THẺ: "
                            font.pixelSize: 22
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
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        height: 180
                        spacing: 20
                        Layout.fillWidth: true

                        RowLayout {
                            Button {
                                id: btnCongVao
                                height: 60
                                text: "CỔNG VÀO"
                                font.pixelSize: 18
                                Layout.fillWidth: true
                            }

                            Button {
                                id: btnCongRa
                                height: 60
                                text: "CỔNG RA"
                                font.pixelSize: 18
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            height: 60
                            text: "THÊM"
                            font.pixelSize: 18
                            Layout.fillWidth: true
                        }

                        Button {
                            height: 60
                            text: "XÓA"
                            font.pixelSize: 18
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
