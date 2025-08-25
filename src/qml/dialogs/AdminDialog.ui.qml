import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: adminDialog
    // Expose inner Dialog for open()/close()
    property alias dialog: dlg
    // Expose settings and triggers (aliases to inner dialog properties)
    property alias loggedIn: dlg.loggedIn
    property alias error: dlg.error
    property alias loginUser: dlg.loginUser
    property alias loginPass: dlg.loginPass
    property alias triggerLogin: dlg.triggerLogin
    property alias selVehicle: dlg.selVehicle
    property alias selTicket: dlg.selTicket
    property alias triggerLoadPricing: dlg.triggerLoadPricing
    property alias triggerSavePricing: dlg.triggerSavePricing
    property alias triggerAddSlot: dlg.triggerAddSlot
    property alias tfGrace: tfGrace
    property alias tfBaseMinutes: tfBaseMinutes
    property alias tfBasePrice: tfBasePrice
    property alias tfIncMinutes: tfIncMinutes
    property alias tfIncPrice: tfIncPrice
    property alias tfCapPerDay: tfCapPerDay
    property alias cbIncremental: cbIncremental
    property alias tfOvernight: tfOvernight
    property alias tfLost: tfLost
    property alias slotsModel: slotsModel
    property alias cbVehicle: cbVehicle
    property alias cbTicket: cbTicket

    Dialog {
        id: dlg
        title: "Quản trị hệ thống"
        modal: true
        standardButtons: Dialog.Close
        parent: (Overlay.overlay ? Overlay.overlay : adminDialog)
        anchors.centerIn: parent
        // Define properties on dialog to emit change signals on target object
        property bool loggedIn: false
        property string error: ""
        property string loginUser: ""
        property string loginPass: ""
        property bool triggerLogin: false
        property string selVehicle: "car"
        property string selTicket: "per_use"
        property bool triggerLoadPricing: false
        property bool triggerSavePricing: false
        property bool triggerAddSlot: false

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8
            Item {
                Layout.fillWidth: true
                height: adminDialog.loggedIn ? 0 : 220
                visible: !adminDialog.loggedIn
                Column {
                    width: 360
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        spacing: 8
                        Text { text: "Tài khoản:"; color: "#ddd"; width: 80; horizontalAlignment: Text.AlignRight }
                        TextField {
                            id: tfUser
                            text: "admin"
                            color: "white"
                            placeholderText: "admin"
                            width: 240
                            onTextChanged: adminDialog.loginUser = text
                            background: Rectangle { color: "#111"; border.color: "#555"; radius: 4 }
                        }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Mật khẩu:"; color: "#ddd"; width: 80; horizontalAlignment: Text.AlignRight }
                        Row {
                            id: tfPass
                            spacing: 6
                            property bool showPwd: true
                            TextField {
                                id: tfPassField
                                echoMode: tfPass.showPwd ? TextInput.Normal : TextInput.Password
                                color: "white"
                                width: 200
                                onTextChanged: adminDialog.loginPass = text
                                Keys.onReturnPressed: adminDialog.triggerLogin = !adminDialog.triggerLogin
                                background: Rectangle { color: "#111"; border.color: "#555"; radius: 4 }
                            }
                            Rectangle {
                                width: 34
                                height: 28
                                radius: 4
                                color: "#444"
                                Text { anchors.centerIn: parent; color: "white"; text: tfPass.showPwd ? "Ẩn" : "Hiện"; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; onClicked: tfPass.showPwd = !tfPass.showPwd }
                            }
                        }
                    }
                    Rectangle {
                        radius: 4
                        color: "#2b7"
                        width: 120
                        height: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text { anchors.centerIn: parent; text: "Đăng nhập"; color: "white"; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: adminDialog.triggerLogin = !adminDialog.triggerLogin }
                    }
                    Text { text: adminDialog.error; color: "#ff8080" }
                }
            }
            Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: adminDialog.loggedIn
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Text { text: "Cấu hình bảng giá"; color: "#eee"; font.pixelSize: 18; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "Loại xe:"; color: "#ccc" }
                    ComboBox { id: cbVehicle; model: ["car", "motorbike"]; currentIndex: 0; width: 140; onCurrentIndexChanged: adminDialog.selVehicle = currentText }
                    Text { text: "Loại vé:"; color: "#ccc" }
                    ComboBox { id: cbTicket; model: ["per_use"]; currentIndex: 0; width: 140; onCurrentIndexChanged: adminDialog.selTicket = currentText }
                    Rectangle {
                        radius: 4
                        color: "#444"
                        width: 120
                        height: 30
                        Text { anchors.centerIn: parent; text: "Tải cấu hình"; color: "white" }
                        MouseArea { anchors.fill: parent; onClicked: adminDialog.triggerLoadPricing = !adminDialog.triggerLoadPricing }
                    }
                    Rectangle {
                        radius: 4
                        color: "#2b7"
                        width: 120
                        height: 30
                        Text { anchors.centerIn: parent; text: "Lưu"; color: "white" }
                        MouseArea { anchors.fill: parent; onClicked: adminDialog.triggerSavePricing = !adminDialog.triggerSavePricing }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: "#1f1f1f"
                    radius: 6
                    border.color: "#444"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text { text: "Thiết lập cơ bản"; color: "#ddd"; font.bold: true }
                        GridLayout {
                            columns: 6
                            columnSpacing: 10
                            rowSpacing: 8
                            Layout.fillWidth: true
                            Text { text: "Miễn phí (phút)"; color: "#ccc" }
                            TextField { id: tfGrace; text: "15"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Thời gian base (phút)"; color: "#ccc" }
                            TextField { id: tfBaseMinutes; text: "60"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Giá base"; color: "#ccc" }
                            TextField { id: tfBasePrice; text: "5000"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Mỗi bước (phút)"; color: "#ccc" }
                            TextField { id: tfIncMinutes; text: "60"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Giá mỗi bước"; color: "#ccc" }
                            TextField { id: tfIncPrice; text: "5000"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Trần/ngày"; color: "#ccc" }
                            TextField { id: tfCapPerDay; text: "70000"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Kiểu tăng"; color: "#ccc" }
                            ComboBox { id: cbIncremental; model: ["flat", "increasing", "decreasing"]; currentIndex: 0; width: 140 }
                            Text { text: "Qua đêm"; color: "#ccc" }
                            TextField { id: tfOvernight; text: "10000"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
                            Text { text: "Mất thẻ"; color: "#ccc" }
                            TextField { id: tfLost; text: "100000"; color: "white"; background: Rectangle { color: "#111"; border.color: "#555" } }
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
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Khung giờ"; color: "#ddd"; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                radius: 4
                                color: "#333"
                                width: 100
                                height: 28
                                Text { anchors.centerIn: parent; text: "+ Thêm"; color: "white"; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; onClicked: adminDialog.triggerAddSlot = !adminDialog.triggerAddSlot }
                            }
                        }
                        ListModel { id: slotsModel }
                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "Bắt đầu"; color: "#aaa"; Layout.preferredWidth: 90 }
                            Text { text: "Kết thúc"; color: "#aaa"; Layout.preferredWidth: 90 }
                            Text { text: "Phút/bước"; color: "#aaa"; Layout.preferredWidth: 90 }
                            Text { text: "Giá/bước"; color: "#aaa"; Layout.preferredWidth: 90 }
                            Text { text: "Trần"; color: "#aaa"; Layout.preferredWidth: 90 }
                        }
                        ListView {
                            id: slotsView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: slotsModel
                            delegate: RowLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                TextField {
                                    text: start
                                    color: "white"
                                    background: Rectangle { color: "#111"; border.color: "#555" }
                                    onTextChanged: start = text
                                    Layout.preferredWidth: 90
                                }
                                TextField {
                                    text: end
                                    color: "white"
                                    background: Rectangle { color: "#111"; border.color: "#555" }
                                    onTextChanged: end = text
                                    Layout.preferredWidth: 90
                                }
                                TextField {
                                    text: inc_minutes
                                    color: "white"
                                    background: Rectangle { color: "#111"; border.color: "#555" }
                                    onTextChanged: inc_minutes = text
                                    Layout.preferredWidth: 90
                                }
                                TextField {
                                    text: inc_price
                                    color: "white"
                                    background: Rectangle { color: "#111"; border.color: "#555" }
                                    onTextChanged: inc_price = text
                                    Layout.preferredWidth: 90
                                }
                                TextField {
                                    text: cap
                                    color: "white"
                                    background: Rectangle { color: "#111"; border.color: "#555" }
                                    onTextChanged: cap = text
                                    Layout.preferredWidth: 90
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }
}