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
                    text: "BÃI ĐỖ XE TỰ ĐỘNG"
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
                            text: " TỔNG SỐ XE: " + app.openCount
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
                            text: " THỜI GIAN VÀO: " + (app.checkInTime || "")
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
                            text: " THỜI GIAN RA: " + (app.checkOutTime || "")
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
                                onClicked: app.gateMode = 0
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
                                onClicked: app.gateMode = 1
                            }
                        }

                        Button {
                            height: 60
                            text: "MỞ"
                            font.pixelSize: 18
                            Layout.fillWidth: true
                            // onClicked: app.deleteClosed(app.lastRfid)
                        }
                    }
                }
            }
        }
    }
}
