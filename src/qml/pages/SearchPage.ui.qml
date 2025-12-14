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
    // New triggers for Time selection
    property bool triggerFromTimeSelect: false
    property bool triggerToTimeSelect: false

    property bool triggerClose: false
    property bool triggerSearch: false
    property bool triggerShowDetail: false
    property bool triggerPrintInvoice: false
    property int selectedRowId: -1

    // Visibility flags
    property bool fromPickerVisible: false
    property bool toPickerVisible: false
    property bool fromTimePickerVisible: false
    property bool toTimePickerVisible: false

    property alias tfQuery: tfQuery
    property alias cbStatus: cbStatus
    property alias fromDatePopup: fromDatePopup
    property alias toDatePopup: toDatePopup
    property alias dpFrom: dpFrom
    property alias dpTo: dpTo

    // Aliases for Time TextFields
    property alias tfFromTime: tfFromTime
    property alias tfToTime: tfToTime

    // Updated Aliases: Pointing to the Popups' internal combos
    property alias fromHour: fromTimePopup.hourCombo
    property alias fromMinute: fromTimePopup.minuteCombo
    property alias toHour: toTimePopup.hourCombo
    property alias toMinute: toTimePopup.minuteCombo

    property alias resultsView: resultsView
    property alias resultsModel: resultsModel
    property alias lblSummary: lblSummary
    property alias lblRevenue: lblRevenue
    property alias sessionDetailDialog: sessionDetail

    // Add aliases for date picker ComboBoxes
    property alias fromYear: fromDatePopup.fromYear
    property alias fromMonth: fromDatePopup.fromMonth
    property alias fromDay: fromDatePopup.fromDay
    property alias toYear: toDatePopup.toYear
    property alias toMonth: toDatePopup.toMonth
    property alias toDay: toDatePopup.toDay

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        // Search Bar
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

            // Modified: From Time (Direct Click)
            TextField {
                id: tfFromTime
                readOnly: true
                color: "white"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                placeholderText: "00:00"
                Layout.preferredWidth: 90
                Layout.preferredHeight: 40
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.fromTimePickerVisible = true
                }
            }

            // Modified: To Time (Direct Click)
            TextField {
                id: tfToTime
                readOnly: true
                color: "white"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                placeholderText: "00:00"
                Layout.preferredWidth: 90
                Layout.preferredHeight: 40
                background: Rectangle {
                    color: "#222"
                    border.color: "#555"
                    radius: 8
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: searchPage.toTimePickerVisible = true
                }
            }

            Item { Layout.fillWidth: true }

            // Search Button
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
            // Close Button
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

        // Result List (Unchanged content, abbreviated for clarity)
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
                Column {
                    id: resultsContainer
                    spacing: 6
                    width: Math.max(headerRow.implicitWidth, resultsScroll.width)
                    RowLayout {
                        id: headerRow
                        spacing: 8
                        Text { text: "ID"; color: "white"; font.bold: true; Layout.preferredWidth: 60 }
                        Text { text: "Biển số"; color: "white"; font.bold: true; Layout.minimumWidth: 140; Layout.fillWidth: true }
                        Text { text: "ID thẻ"; color: "white"; font.bold: true; Layout.minimumWidth: 140; Layout.fillWidth: true }
                        Text { text: "Giờ vào"; color: "white"; font.bold: true; Layout.minimumWidth: 160; Layout.fillWidth: true }
                        Text { text: "Giờ ra"; color: "white"; font.bold: true; Layout.minimumWidth: 160; Layout.fillWidth: true }
                        Text { text: "Phí"; color: "white"; font.bold: true; Layout.preferredWidth: 80 }
                        Text { text: "TT"; color: "white"; font.bold: true; Layout.preferredWidth: 80 }
                        Text { text: "Phương thức thanh toán"; color: "white"; font.bold: true; Layout.preferredWidth: 100 }
                        Text { text: ""; Layout.preferredWidth: 75 } // Detail placeholder
                        Item { Layout.preferredWidth: 0 }
                    }
                    ListModel { id: resultsModel }
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
                            Text { text: idText; color: "white"; Layout.preferredWidth: 60 }
                            Text { text: plate; color: "#ddd"; Layout.minimumWidth: 140; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: rfid; color: "#ddd"; Layout.minimumWidth: 140; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: Qt.formatDateTime(checkin, "HH:mm:ss - dd/MM/yyyy"); color: "#ccc"; Layout.minimumWidth: 160; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: Qt.formatDateTime(checkout, "HH:mm:ss - dd/MM/yyyy"); color: "#ccc"; Layout.minimumWidth: 160; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: fee; color: "#ddd"; Layout.preferredWidth: 80 }
                            Text { text: status; color: "#ddd"; Layout.preferredWidth: 80 }
                            Text { text: payment_check; color: "#ddd"; Layout.preferredWidth: 110 }
                            Image { source: thumbnail; fillMode: Image.PreserveAspectFit; width: 72; height: 48 }
                            Rectangle {
                                width: 80; height: 28; radius: 4; color: "#2d2f33"
                                Text { anchors.centerIn: parent; text: "Chi tiết"; color: "white" }
                                MouseArea {
                                    anchors.fill: parent
                                    onPressed: searchPage.selectedRowId = idText
                                    onClicked: searchPage.triggerShowDetail = !searchPage.triggerShowDetail
                                }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { id: lblSummary; text: "0 kết quả"; color: "#aaa" }
            Item { Layout.fillWidth: true }
            Text { id: lblRevenue; text: "Tổng doanh thu trong kết quả: 0 VNĐ"; color: "#aaa" }
        }
    }

    SessionDetailDialog { id: sessionDetail }

    // Existing Date Popups (Unchanged)
    Popup {
        id: fromDatePopup
        modal: true; focus: true
        visible: searchPage.fromPickerVisible
        x: (parent ? parent.width : 800)/2 - width/2
        y: (parent ? parent.height : 600)/2 - height/2
        property alias fromYear: fromYearCombo
        property alias fromMonth: fromMonthCombo
        property alias fromDay: fromDayCombo
        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Năm"; color: "black" }
                ComboBox {
                    id: fromYearCombo;
                    model: 101;
                    delegate:
                        ItemDelegate {
                            text: 2000+index
                        }
                    Layout.preferredWidth: 100
                    currentIndex: 25
                }
                Text { text: "Tháng"; color: "black" }
                ComboBox { id: fromMonthCombo; model: 12; delegate: ItemDelegate { text: (index+1)<10?"0"+(index+1):""+(index+1) } Layout.preferredWidth: 90; currentIndex: 1 }
                Text { text: "Ngày"; color: "black" }
                ComboBox { id: fromDayCombo; model: 31; delegate: ItemDelegate { text: (index+1)<10?"0"+(index+1):""+(index+1) } Layout.preferredWidth: 90; currentIndex: 1 }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle { Layout.fillWidth: true; height: 32; radius: 6; color: "#444"; Text { anchors.centerIn: parent; text: "Hủy"; color: "white" } MouseArea { anchors.fill: parent; onClicked: searchPage.fromPickerVisible = false } }
                Rectangle { Layout.fillWidth: true; height: 32; radius: 6; color: "#2b7"; Text { anchors.centerIn: parent; text: "Chọn"; color: "white" } MouseArea { anchors.fill: parent; onClicked: searchPage.triggerFromDateSelect = true } }
            }
        }
    }

    Popup {
        id: toDatePopup
        modal: true; focus: true
        visible: searchPage.toPickerVisible
        x: (parent ? parent.width : 800)/2 - width/2
        y: (parent ? parent.height : 600)/2 - height/2
        property alias toYear: toYearCombo
        property alias toMonth: toMonthCombo
        property alias toDay: toDayCombo
        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Năm"; color: "black" }
                ComboBox { id: toYearCombo; model: 101; delegate: ItemDelegate { text: 2000+index } Layout.preferredWidth: 100; currentIndex: 25 }
                Text { text: "Tháng"; color: "black" }
                ComboBox { id: toMonthCombo; model: 12; delegate: ItemDelegate { text: (index+1)<10?"0"+(index+1):""+(index+1) } Layout.preferredWidth: 90; currentIndex: 1 }
                Text { text: "Ngày"; color: "black" }
                ComboBox { id: toDayCombo; model: 31; delegate: ItemDelegate { text: (index+1)<10?"0"+(index+1):""+(index+1) } Layout.preferredWidth: 90; currentIndex: 1 }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle { Layout.fillWidth: true; height: 32; radius: 6; color: "#444"; Text { anchors.centerIn: parent; text: "Hủy"; color: "white" } MouseArea { anchors.fill: parent; onClicked: searchPage.toPickerVisible = false } }
                Rectangle { Layout.fillWidth: true; height: 32; radius: 6; color: "#2b7"; Text { anchors.centerIn: parent; text: "Chọn"; color: "white" } MouseArea { anchors.fill: parent; onClicked: searchPage.triggerToDateSelect = true } }
            }
        }
    }

    // --- NEW: From Time Popup ---
    Popup {
        id: fromTimePopup
        modal: true
        focus: true
        visible: searchPage.fromTimePickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2

        property alias hourCombo: fromHourCombo
        property alias minuteCombo: fromMinuteCombo

        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Giờ"; color: "black" }
                ComboBox {
                    id: fromHourCombo
                    model: 24
                    popup.height: 240
                    Layout.preferredWidth: 80
                    delegate: ItemDelegate { text: (index < 10 ? "0" : "") + index }
                }
                Text { text: "Phút"; color: "black" }
                ComboBox {
                    id: fromMinuteCombo
                    model: 60
                    popup.height: 240
                    Layout.preferredWidth: 80
                    delegate: ItemDelegate { text: (index < 10 ? "0" : "") + index }
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
                    MouseArea { anchors.fill: parent; onClicked: searchPage.fromTimePickerVisible = false }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.triggerFromTimeSelect = true }
                }
            }
        }
    }

    // --- NEW: To Time Popup ---
    Popup {
        id: toTimePopup
        modal: true
        focus: true
        visible: searchPage.toTimePickerVisible
        x: (parent ? parent.width : 800) / 2 - width / 2
        y: (parent ? parent.height : 600) / 2 - height / 2

        property alias hourCombo: toHourCombo
        property alias minuteCombo: toMinuteCombo

        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                spacing: 8
                Text { text: "Giờ"; color: "black" }
                ComboBox {
                    id: toHourCombo
                    model: 24
                    popup.height: 240
                    Layout.preferredWidth: 80
                    delegate: ItemDelegate { text: (index < 10 ? "0" : "") + index }
                }
                Text { text: "Phút"; color: "black" }
                ComboBox {
                    id: toMinuteCombo
                    model: 60
                    popup.height: 240
                    Layout.preferredWidth: 80
                    delegate: ItemDelegate { text: (index < 10 ? "0" : "") + index }
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
                    MouseArea { anchors.fill: parent; onClicked: searchPage.toTimePickerVisible = false }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: "#2b7"
                    Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: searchPage.triggerToTimeSelect = true }
                }
            }
        }
    }
}
