import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: root
    color: "transparent"
    border.width: 1
    border.color: "#aaa"
    radius: 4

    property string laneTitle: "CỔNG VÀO"
    property bool isEntrance: true
    // Designer-safe: expose preview sources as properties set from logic outside
    property url inputPreviewSource: ""
    property url outputPreviewSource: ""
    property alias inputVideo: inputVideo
    property alias outputVideo: outputVideo
    property alias inputPreview: inputPreview
    property alias outputPreview: outputPreview

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 5

        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "white"
            border.color: "gray"
            border.width: 1
            radius: 4
            Text {
                anchors.centerIn: parent
                text: laneTitle
                font.bold: true
                font.pixelSize: 24
            }
        }

        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Camera trước + preview
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
                        id: inputVideo
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: VideoOutput.PreserveAspectFit
                        Text {
                            anchors.centerIn: parent
                            text: "Camera Vào"
                            color: "black"
                            font.pixelSize: 14
                            visible: !inputVideo.videoSink
                                     || inputVideo.videoSink.videoSize.width === 0
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 260
                    color: "black"
                    Image {
                        id: inputPreview
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        source: root.inputPreviewSource
                    }
                }
            }
            // Camera sau + preview
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
                        id: outputVideo
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: VideoOutput.PreserveAspectFit
                        Text {
                            anchors.centerIn: parent
                            text: "Camera Ra"
                            color: "black"
                            font.pixelSize: 14
                            visible: !outputVideo.videoSink
                                     || outputVideo.videoSink.videoSize.width === 0
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 260
                    color: "black"
                    Image {
                        id: outputPreview
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        source: root.outputPreviewSource
                    }
                }
            }
        }

        // Info panels switch by mode
        ColumnLayout {
            visible: !isEntrance
            spacing: 6
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "white"
                border.color: "#bbb"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 14
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "ID THẺ:"
                                font.bold: true
                                Layout.preferredWidth: 90
                            }
                            Text {
                                text: app.exitCardId || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "BIỂN SỐ:"
                                font.bold: true
                                Layout.preferredWidth: 90
                            }
                            Text {
                                text: app.exitPlate || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
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
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "THỜI GIAN VÀO:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            Text {
                                text: app.exitTimeIn || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "THỜI GIAN RA:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            Text {
                                text: app.exitTimeOut || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
        ColumnLayout {
            visible: isEntrance
            spacing: 6
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "white"
                border.color: "#bbb"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 14
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "ID THẺ:"
                                font.bold: true
                                Layout.preferredWidth: 90
                            }
                            Text {
                                text: app.entranceCardId || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "BIỂN SỐ:"
                                font.bold: true
                                Layout.preferredWidth: 90
                            }
                            Text {
                                text: app.entrancePlate || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
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
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "THỜI GIAN VÀO:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            Text {
                                text: app.entranceTimeIn || ""
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                text: "LOẠI THẺ:"
                                font.bold: true
                                Layout.preferredWidth: 90
                            }
                            Text {
                                text: app.entranceCardType || "Vãng lai"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
