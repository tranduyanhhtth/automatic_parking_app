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

    // External properties
    property url inputPreviewSource: ""
    property url outputPreviewSource: ""
    property string moneyMessage: ""
    property alias inputVideo: inputVideo
    property alias outputVideo: outputVideo
    property alias inputPreview: inputPreview
    property alias outputPreview: outputPreview

    // Interaction elements
    property alias exitPlateMouseArea: maExitPlate
    property alias exitPlateInput: tfExitPlate
    property alias entrancePlateMouseArea: maEntPlate
    property alias entrancePlateInput: tfEntPlate

    // --- [NEW] Local Session State ---
    property string displayCardId: ""
    property string displayPlate: ""
    property string displayTimeIn: ""
    property string displayTimeOut: ""
    property string displayCardType: ""

    // 1. Function to CLEAR this lane immediately
    function clearSession() {
        displayCardId = ""
        displayPlate = ""
        displayTimeIn = ""
        displayTimeOut = ""
        displayCardType = ""
        // Timer removed so we don't need to stop it
    }

    // 2. Function to REFRESH this lane with new data
    function refreshSession() {
        if (root.isEntrance) {
            root.displayCardId = app.entranceCardId || ""
            root.displayPlate = app.entrancePlate || ""
            root.displayTimeIn = app.entranceTimeIn || ""
            root.displayCardType = app.entranceCardType || ""
            root.displayTimeOut = ""
        } else {
            root.displayCardId = app.exitCardId || ""
            root.displayPlate = app.exitPlate || ""
            root.displayTimeIn = app.exitTimeIn || ""
            root.displayTimeOut = app.exitTimeOut || ""
            root.displayCardType = ""
        }
    }

    Connections {
        target: app

        function onEntranceCardIdChanged() {
            if (root.isEntrance) {
                root.refreshSession()
            }

        }

        function onExitCardIdChanged() {
            if (!root.isEntrance) {
                root.refreshSession()
            }
        }

        // Apply the same logic to Plate changes
        function onEntrancePlateChanged() {
            if (root.isEntrance) root.refreshSession()
        }
        function onExitPlateChanged() {
            if (!root.isEntrance) root.refreshSession()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 5

        Rectangle {
            Layout.fillWidth: true
            height: 40
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
                    Layout.preferredHeight: 200
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
                            visible: !inputVideo.videoSink || inputVideo.videoSink.videoSize.width === 0
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "black"
                    Image {
                        id: inputPreview
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        // UPDATED: Show image if source exists (since we removed timer)
                        source: root.inputPreviewSource
                        visible: root.inputPreviewSource != ""
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
                    Layout.preferredHeight: 200
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
                            visible: !outputVideo.videoSink || outputVideo.videoSink.videoSize.width === 0
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "black"
                    Image {
                        id: outputPreview
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        // UPDATED: Show image if source exists
                        source: root.outputPreviewSource
                        visible: root.outputPreviewSource != ""
                    }
                }
            }
        }

        // Info panels - EXIT MODE
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
                                text: root.displayCardId
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
                                MouseArea {
                                    id: maExitPlate
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                            TextField {
                                id: tfExitPlate
                                visible: false
                                Layout.fillWidth: true
                                placeholderText: "Nhập biển số..."
                                font.pixelSize: 14
                                height: 30
                            }
                            Text {
                                text: root.displayPlate
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: !tfExitPlate.visible
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
                                text: root.displayTimeIn
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
                                text: root.displayTimeOut
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Info panels - ENTRANCE MODE
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
                                text: root.displayCardId
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
                                MouseArea {
                                    id: maEntPlate
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                            TextField {
                                id: tfEntPlate
                                visible: false
                                Layout.fillWidth: true
                                placeholderText: "Nhập biển số..."
                                font.pixelSize: 14
                                height: 30
                            }
                            Text {
                                text: root.displayPlate
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: !tfEntPlate.visible
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
                                text: root.displayTimeIn
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
                                text: root.displayCardType
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Money Message Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: moneyMessage.length > 0 ? 48 : 0
            visible: moneyMessage.length > 0
            color: "#FFF7E0"
            border.color: "#E0C97A"
            radius: 4
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                Text {
                    text: moneyMessage
                    font.pixelSize: 22
                    font.bold: true
                    color: "#8A6D3B"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
