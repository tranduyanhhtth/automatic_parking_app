import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: searchDialog
    property bool triggerSearch: false
    property alias dpFrom: dpFrom
    property alias tpFrom: tpFrom
    property alias dpTo: dpTo
    property alias tpTo: tpTo
    property alias tfSearchRfid: tfSearchRfid
    property alias tfSearchPlate: tfSearchPlate
    property alias cbSearchStatus: cbSearchStatus
    property alias dialog: dlg

    Dialog {
        id: dlg
        title: "Tìm kiếm phiên gửi xe"
        modal: true
        standardButtons: Dialog.Close
        parent: (Overlay.overlay ? Overlay.overlay : searchDialog)
        anchors.centerIn: parent
        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10
            Rectangle {
                Layout.fillWidth: true
                color: "#1f1f1f"
                radius: 6
                border.color: "#444"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text {
                        text: "Bộ lọc"
                        color: "#ddd"
                        font.bold: true
                    }
                    GridLayout {
                        columns: 6
                        columnSpacing: 10
                        rowSpacing: 8
                        Layout.fillWidth: true
                        Text {
                            text: "Từ ngày"
                            color: "#ccc"
                        }
                        TextField {
                            id: dpFrom
                            placeholderText: "YYYY-MM-DD"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "Giờ"
                            color: "#ccc"
                        }
                        TextField {
                            id: tpFrom
                            placeholderText: "HH:mm"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "RFID"
                            color: "#ccc"
                        }
                        TextField {
                            id: tfSearchRfid
                            placeholderText: "RFID"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "Đến ngày"
                            color: "#ccc"
                        }
                        TextField {
                            id: dpTo
                            placeholderText: "YYYY-MM-DD"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "Giờ"
                            color: "#ccc"
                        }
                        TextField {
                            id: tpTo
                            placeholderText: "HH:mm"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "Biển số"
                            color: "#ccc"
                        }
                        TextField {
                            id: tfSearchPlate
                            placeholderText: "VD: 30A-123.45"
                            color: "white"
                            background: Rectangle {
                                color: "#111"
                                border.color: "#555"
                            }
                        }
                        Text {
                            text: "Trạng thái"
                            color: "#ccc"
                        }
                        ComboBox {
                            id: cbSearchStatus
                            model: ["", "in", "closed"]
                            currentIndex: 0
                            Layout.preferredWidth: 140
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            radius: 4
                            color: "#2b7"
                            width: 120
                            height: 30
                            Text {
                                anchors.centerIn: parent
                                text: "Tìm kiếm"
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: (searchDialog.triggerSearch
                                            = !searchDialog.triggerSearch)
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1f1f1f"
            radius: 6
            border.color: "#444"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Text {
                    text: "Kết quả"
                    color: "#ddd"
                    font.bold: true
                }
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Text {
                        text: "ID"
                        color: "#aaa"
                        Layout.preferredWidth: 60
                    }
                    Text {
                        text: "RFID"
                        color: "#aaa"
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: "Biển số"
                        color: "#aaa"
                        Layout.preferredWidth: 140
                    }
                    Text {
                        text: "Vào"
                        color: "#aaa"
                        Layout.preferredWidth: 180
                    }
                    Text {
                        text: "Ra"
                        color: "#aaa"
                        Layout.preferredWidth: 180
                    }
                    Text {
                        text: "Phút"
                        color: "#aaa"
                        Layout.preferredWidth: 60
                    }
                    Text {
                        text: "Phí"
                        color: "#aaa"
                        Layout.preferredWidth: 80
                    }
                    Text {
                        text: "TT"
                        color: "#aaa"
                        Layout.preferredWidth: 70
                    }
                }
                ListView {
                    id: resultsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: parent.parent.parent.parent.searchResults
                    delegate: RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Rectangle {
                            color: "#2a2a2a"
                            radius: 4
                            Layout.fillWidth: true
                            height: 34
                            border.color: "#444"
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8
                                Text {
                                    text: modelData.id
                                    color: "#fff"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: modelData.rfid
                                    color: "#fff"
                                    Layout.preferredWidth: 140
                                }
                                Text {
                                    text: modelData.plate
                                    color: "#fff"
                                    Layout.preferredWidth: 140
                                }
                                Text {
                                    text: modelData.checkin_time
                                    color: "#fff"
                                    Layout.preferredWidth: 180
                                }
                                Text {
                                    text: modelData.checkout_time
                                    color: "#fff"
                                    Layout.preferredWidth: 180
                                }
                                Text {
                                    text: modelData.duration_minutes
                                    color: "#fff"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: modelData.fee
                                    color: "#fff"
                                    Layout.preferredWidth: 80
                                }
                                Text {
                                    text: modelData.status
                                    color: "#fff"
                                    Layout.preferredWidth: 70
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
