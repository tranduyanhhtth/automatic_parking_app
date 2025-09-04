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
    property alias fromHour: fromHour
    property alias fromMinute: fromMinute
    property alias toHour: toHour
    property alias toMinute: toMinute
    property alias resultsView: resultsView
    property alias resultsModel: resultsModel
    property alias lblSummary: lblSummary
    property alias lblRevenue: lblRevenue
    // detail dialog instance for logic to control
    property alias sessionDetailDialog: sessionDetail
    // Add aliases for date picker ComboBoxes
    property alias fromYear: fromDatePopup.fromYear
    property alias fromMonth: fromDatePopup.fromMonth
    property alias fromDay: fromDatePopup.fromDay
    property alias toYear: toDatePopup.toYear
    property alias toMonth: toDatePopup.toMonth
    property alias toDay: toDatePopup.toDay

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
                placeholderText: "Nhập biển số"
                placeholderTextColor: "white"
                color: "white"
                font.pixelSize: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
            }
            ComboBox {
                id: cbStatus
                model: ["Tất cả", "In", "Out"]
                font.pixelSize: 14
                Layout.preferredWidth: 140
                Layout.preferredHeight: 40
                background: Rectangle {
                    radius: 8
                    border.color: "#222"
                }
            }
            TextField {
                id: dpFrom
                placeholderText: "Từ ngày (YYYY-MM-DD)"
                placeholderTextColor: "white"
                color: "white"
                font.pixelSize: 14
                Layout.preferredWidth: 180
                Layout.preferredHeight: 40
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                validator: RegularExpressionValidator {
                    regularExpression: /^\d{4}-\d{2}-\d{2}$/
                }
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
                font.pixelSize: 14
                Layout.preferredWidth: 180
                Layout.preferredHeight: 40
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                validator: RegularExpressionValidator {
                    regularExpression: /^\d{4}-\d{2}-\d{2}$/
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.toPickerVisible = true
                }
            }
            RowLayout {
                spacing: 4
                TextField {
                    id: tfFromTime
                    readOnly: true
                    color: "white"
                    font.pixelSize: 28
                    text: (fromHour.currentIndex < 10 ? "0" : "") + fromHour.currentIndex + ":"
                          + (fromMinute.currentIndex < 10 ? "0" : "") + fromMinute.currentIndex
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: "#222"
                        border.color: "#555"
                        radius: 8
                    }
                }
                ComboBox {
                    id: fromHour
                    model: 24
                    currentIndex: 0
                    displayText: ""
                    popup.height: 240
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    background: Rectangle {
                        radius: 8
                        border.color: "#222"
                    }
                    delegate: ItemDelegate {
                        text: (index < 10 ? "0" : "") + index
                    }
                }
                ComboBox {
                    id: fromMinute
                    model: 60
                    currentIndex: 0
                    displayText: ""
                    popup.height: 240
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    background: Rectangle {
                        radius: 8
                        border.color: "#222"
                    }
                    delegate: ItemDelegate {
                        text: (index < 10 ? "0" : "") + index
                    }
                }
            }
            RowLayout {
                spacing: 4
                TextField {
                    id: tfToTime
                    readOnly: true
                    color: "white"
                    font.pixelSize: 28
                    text: (toHour.currentIndex < 10 ? "0" : "") + toHour.currentIndex + ":"
                          + (toMinute.currentIndex < 10 ? "0" : "") + toMinute.currentIndex
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: "#222"
                        border.color: "#555"
                        radius: 8
                    }
                }
                ComboBox {
                    id: toHour
                    model: 24
                    currentIndex: 0
                    displayText: ""
                    popup.height: 240
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    background: Rectangle {
                        radius: 8
                        border.color: "#222"
                    }
                    delegate: ItemDelegate {
                        text: (index < 10 ? "0" : "") + index
                    }
                }
                ComboBox {
                    id: toMinute
                    model: 60
                    currentIndex: 0
                    displayText: ""
                    popup.height: 240
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    background: Rectangle {
                        radius: 8
                        border.color: "#222"
                    }
                    delegate: ItemDelegate {
                        text: (index < 10 ? "0" : "") + index
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                width: 110
                height: 40
                radius: 8
                color: "#2b7"
                Text {
                    anchors.centerIn: parent
                    text: "Tìm kiếm"
                    color: "white"
                    font.pixelSize: 15
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.triggerSearch = !searchPage.triggerSearch
                }
            }
            Rectangle {
                width: 90
                height: 40
                radius: 8
                color: "#444"
                border.color: "#222"
                Text {
                    anchors.centerIn: parent
                    text: "Đóng"
                    color: "white"
                    font.pixelSize: 15
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
                        height: resultsScroll.height - headerRow.implicitHeight - 16
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
                                text: Qt.formatDateTime(checkin, "HH:mm:ss - dd/MM/yyyy")
                                color: "#ccc"
                                Layout.minimumWidth: 160
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: Qt.formatDateTime(checkout, "HH:mm:ss - dd/MM/yyyy")
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
                                    onClicked: searchPage.triggerShowDetail = !searchPage.triggerShowDetail
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

    // Simple Date Picker Popup for From date
    Popup {
        id: fromDatePopup
        modal: true
        focus: true
        visible: searchPage.fromPickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2

        property alias fromYear: fromYearCombo
        property alias fromMonth: fromMonthCombo
        property alias fromDay: fromDayCombo

        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Năm"; color: "black" }
                ComboBox {
                    id: fromYearCombo
                    model: 101 // 2000..2100
                    popup.height: 240
                    delegate: ItemDelegate { text: (2000 + index) }
                    Layout.preferredWidth: 100
                    currentIndex: 25 // Mặc định 2025
                }
                Text { text: "Tháng"; color: "black" }
                ComboBox {
                    id: fromMonthCombo
                    model: 12 // 0-11
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) // Hiển thị 01-12
                    }
                    Layout.preferredWidth: 90
                    currentIndex: 1 // Mặc định tháng 1
                }
                Text { text: "Ngày"; color: "black" }
                ComboBox {
                    id: fromDayCombo
                    model: 31 // 0-30
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) // Hiển thị 01-31
                    }
                    Layout.preferredWidth: 90
                    currentIndex: 1 // Mặc định ngày 1
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
                    Text { anchors.centerIn: parent; text: "Hủy"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.fromPickerVisible = false }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.triggerFromDateSelect = true }
                }
            }
        }
    }

    // Simple Date Picker Popup for To date
    Popup {
        id: toDatePopup
        modal: true
        focus: true
        visible: searchPage.toPickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2

        property alias toYear: toYearCombo
        property alias toMonth: toMonthCombo
        property alias toDay: toDayCombo

        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Năm"; color: "black" }
                ComboBox {
                    id: toYearCombo
                    model: 101 // 2000..2100
                    popup.height: 240
                    delegate: ItemDelegate { text: (2000 + index) }
                    Layout.preferredWidth: 100
                    currentIndex: 25 // Mặc định 2025
                }
                Text { text: "Tháng"; color: "black" }
                ComboBox {
                    id: toMonthCombo
                    model: 12 // 0-11
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) // Hiển thị 01-12
                    }
                    Layout.preferredWidth: 90
                    currentIndex: 1 // Mặc định tháng 1
                }
                Text { text: "Ngày"; color: "black" }
                ComboBox {
                    id: toDayCombo
                    model: 31 // 0-30
                    popup.height: 240
                    delegate: ItemDelegate {
                        text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) // Hiển thị 01-31
                    }
                    Layout.preferredWidth: 90
                    currentIndex: 1 // Mặc định ngày 1
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
                    Text { anchors.centerIn: parent; text: "Hủy"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.toPickerVisible = false }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.triggerToDateSelect = true }
                }
            }
        }
    }
}
