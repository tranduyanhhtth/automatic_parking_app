import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../dialogs"
import "../logic"

Item {
    id: searchPage
    // Triggers for logic
    property bool triggerFromDateSelect: false
    property bool triggerToDateSelect: false
    property bool triggerClose: false
    property bool triggerSearch: false
    property bool triggerShowDetail: false
    property bool triggerPrintInvoice: false
    property int selectedRowId: -1
    // Date picker visibility flags (UI-only)
    property bool fromPickerVisible: false
    property bool toPickerVisible: false
    // Expose inputs/outputs via aliases
    property alias tfQuery: tfQuery
    property alias cbStatus: cbStatus
    property alias dpFrom: dpFrom
    property alias dpTo: dpTo
    property alias resultsView: resultsView
    property alias resultsModel: resultsModel
    property alias lblSummary: lblSummary
    property alias lblRevenue: lblRevenue
    // Expose user info labels for logic to fill
    property alias userNameLabel: userNameLabel
    property alias userPhoneLabel: userPhoneLabel
    property alias userVehicleTypeLabel: userVehicleTypeLabel
    property alias userNoteLabel: userNoteLabel
    // detail dialog instance for logic to control
    property alias sessionDetailDialog: sessionDetail

    // Full-page content pane
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        // Thanh tìm kiếm
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: tfQuery
                placeholderText: "Nhập biển số hoặc RFID hoặc chọn thời gian vào"
                placeholderTextColor: "white"
                color: "white"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
            }
            ComboBox {
                id: cbStatus
                model: ["Tất cả", "In", "Out"]
                Layout.preferredWidth: 140
                Layout.preferredHeight: 30
                background: Rectangle {
                    radius: 8
                    border.color: "#222"
                }
            }
            TextField {
                id: dpFrom
                placeholderText: "Từ ngày (YYYY-MM-DD)"
                placeholderTextColor: "white"
                color: "red"
                Layout.preferredWidth: 180
                Layout.preferredHeight: 30
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                // Open DatePicker on click
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.fromPickerVisible = true
                }
            }
            TextField {
                id: dpTo
                placeholderText: "Đến ngày (YYYY-MM-DD)"
                placeholderTextColor: "white"
                color: "white"
                Layout.preferredWidth: 180
                Layout.preferredHeight: 30
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                // Open DatePicker on click
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.toPickerVisible = true
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                width: 110
                height: 30
                radius: 8
                color: "#2b7"
                Text {
                    anchors.centerIn: parent
                    text: "Tìm kiếm"
                    color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.triggerSearch = !searchPage.triggerSearch
                }
            }
            Rectangle {
                width: 90
                height: 30
                radius: 8
                color: "#444"
                border.color: "#222"
                Text {
                    anchors.centerIn: parent
                    text: "Đóng"
                    color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.triggerClose = !searchPage.triggerClose
                }
            }
        }
        // Danh sách kết quả
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#222"
            radius: 8
            border.color: "#333"
            ScrollView {
                id: resultsScroll
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                Column {
                    id: resultsContainer
                    spacing: 6
                    // Stretch to at least viewport width; allow wider if columns need more
                    width: headerRow.implicitWidth
                           > resultsScroll.width ? headerRow.implicitWidth : resultsScroll.width

                    // Header cột
                    RowLayout {
                        id: headerRow
                        width: resultsContainer.width
                        spacing: 8
                        Text {
                            text: "ID"
                            color: "white"
                            font.bold: true
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "Biển số"
                            color: "white"
                            font.bold: true
                            Layout.minimumWidth: 140
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "ID thẻ"
                            color: "white"
                            font.bold: true
                            Layout.minimumWidth: 140
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Giờ vào"
                            color: "white"
                            font.bold: true
                            Layout.minimumWidth: 160
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Giờ ra"
                            color: "white"
                            font.bold: true
                            Layout.minimumWidth: 160
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Phí"
                            color: "white"
                            font.bold: true
                            Layout.preferredWidth: 80
                        }
                        Text {
                            text: "TT"
                            color: "white"
                            font.bold: true
                            Layout.preferredWidth: 80
                        }
                        Text {
                            text: ""
                            color: "white"
                            Layout.preferredWidth: 75
                        }
                        Text {
                            text: ""
                            color: "white"
                            Layout.preferredWidth: 75
                        }
                        Item {
                            Layout.preferredWidth: 0
                        }
                    }

                    ListModel {
                        id: resultsModel
                    }

                    ListView {
                        id: resultsView
                        width: resultsContainer.width
                        height: resultsScroll.height - headerRow.implicitHeight
                                - userInfoRect.height - 16
                        clip: true
                        model: resultsModel
                        delegate: RowLayout {
                            spacing: 8
                            width: resultsView.width
                            height: 54
                            Text {
                                text: idText
                                color: "white"
                                Layout.preferredWidth: 60
                            }
                            Text {
                                text: plate
                                color: "#ddd"
                                Layout.minimumWidth: 140
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: rfid
                                color: "#ddd"
                                Layout.minimumWidth: 140
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: checkin
                                color: "#ccc"
                                Layout.minimumWidth: 160
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: checkout
                                color: "#ccc"
                                Layout.minimumWidth: 160
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: fee
                                color: "#ddd"
                                Layout.preferredWidth: 80
                            }
                            Text {
                                text: status
                                color: "#ddd"
                                Layout.preferredWidth: 80
                            }
                            Image {
                                source: thumbnail
                                fillMode: Image.PreserveAspectFit
                                width: 72
                                height: 48
                            }
                            Rectangle {
                                width: 80
                                height: 28
                                radius: 4
                                color: "#2d2f33"
                                Text {
                                    anchors.centerIn: parent
                                    text: "Chi tiết"
                                    color: "white"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onPressed: searchPage.selectedRowId = idText
                                    onClicked: searchPage.triggerShowDetail
                                               = !searchPage.triggerShowDetail
                                }
                            }
                            // Rectangle {
                            //     width: 90
                            //     height: 28
                            //     radius: 4
                            //     color: "#2b7"
                            //     Text {
                            //         anchors.centerIn: parent
                            //         text: "In hóa đơn"
                            //         color: "white"
                            //     }
                            //     MouseArea {
                            //         anchors.fill: parent
                            //         onPressed: searchPage.selectedRowId = idText
                            //         onClicked: searchPage.triggerPrintInvoice
                            //                    = !searchPage.triggerPrintInvoice
                            //     }
                            // }
                        }
                    }

                    // Thông tin người dùng (nếu có liên kết)
                    Rectangle {
                        id: userInfoRect
                        width: resultsContainer.width
                        height: 100
                        radius: 6
                        color: "white"
                        border.color: "#333"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 20
                            Text {
                                text: "Thông tin người dùng:"
                                color: "black"
                                font.bold: true
                            }
                            Text {
                                id: userNameLabel
                                text: "Họ tên: -"
                                color: "black"
                                Layout.fillWidth: true
                            }
                            Text {
                                id: userPhoneLabel
                                text: "SĐT: -"
                                color: "black"
                                Layout.fillWidth: true
                            }
                            Text {
                                id: userVehicleTypeLabel
                                text: "Loại xe: -"
                                color: "black"
                                Layout.fillWidth: true
                            }
                            Text {
                                id: userNoteLabel
                                text: "Ghi chú: -"
                                color: "black"
                                Layout.fillWidth: true
                            }
                            Item {
                                Layout.preferredWidth: 0
                            }
                        }
                    }
                }
            }
        }
        // Thanh trạng thái
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                id: lblSummary
                text: "0 kết quả"
                color: "#aaa"
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                id: lblRevenue
                text: "Tổng doanh thu trong kết quả: 0 VNĐ"
                color: "#aaa"
            }
        }
    }

    // Detail dialog component instance
    SessionDetailDialog {
        id: sessionDetail
    }

    // Simple Date Picker Popup for From date (SpinBox-based)
    Popup {
        id: fromDatePopup
        modal: true
        focus: true
        visible: searchPage.fromPickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2
        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text {
                    text: "Năm"
                    color: "#ddd"
                }
                ComboBox {
                    id: fromYear
                    model: 101 // 2000..2100
                    currentIndex: 25 // 2025
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (2000 + index)
                    }
                    Layout.preferredWidth: 100
                }
                Text {
                    text: "Tháng"
                    color: "#ddd"
                }
                ComboBox {
                    id: fromMonth
                    model: 12 // 1..12
                    popup.height: 240
                    currentIndex: 0
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? ("0" + (index + 1)) : ("" + (index + 1))
                    }
                    Layout.preferredWidth: 90
                }
                Text {
                    text: "Ngày"
                    color: "#ddd"
                }
                ComboBox {
                    id: fromDay
                    model: 31 // 1..31
                    popup.height: 240
                    currentIndex: 0
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? ("0" + (index + 1)) : ("" + (index + 1))
                    }
                    Layout.preferredWidth: 90
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#444"
                    Text {
                        anchors.centerIn: parent
                        text: "Hủy"
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchPage.fromPickerVisible = false
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text {
                        anchors.centerIn: parent
                        text: "Chọn"
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchPage.triggerFromDateSelect = true
                    }
                }
            }
        }
    }

    // Simple Date Picker Popup for To date (SpinBox-based)
    Popup {
        id: toDatePopup
        modal: true
        focus: true
        visible: searchPage.toPickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2
        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text {
                    text: "Năm"
                    color: "#ddd"
                }
                ComboBox {
                    id: toYear
                    model: 101 // 2000..2100
                    currentIndex: 25 // 2025
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (2000 + index)
                    }
                    Layout.preferredWidth: 100
                }
                Text {
                    text: "Tháng"
                    color: "#ddd"
                }
                ComboBox {
                    id: toMonth
                    model: 12 // 1..12
                    popup.height: 240
                    currentIndex: 0
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? ("0" + (index + 1)) : ("" + (index + 1))
                    }
                    Layout.preferredWidth: 90
                }
                Text {
                    text: "Ngày"
                    color: "#ddd"
                }
                ComboBox {
                    id: toDay
                    model: 31 // 1..31
                    popup.height: 240
                    currentIndex: 0
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? ("0" + (index + 1)) : ("" + (index + 1))
                    }
                    Layout.preferredWidth: 90
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#444"
                    Text {
                        anchors.centerIn: parent
                        text: "Hủy"
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchPage.toPickerVisible = false
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text {
                        anchors.centerIn: parent
                        text: "Chọn"
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchPage.triggerToDateSelect = true
                    }
                }
            }
        }
    }
}
