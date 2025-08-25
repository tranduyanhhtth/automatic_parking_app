import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: loginDialog
    // Expose inner dialog and fields
    property alias dialog: dlg
    property alias username: dlg.username
    property alias password: dlg.password
    property alias error: dlg.error
    property alias triggerLogin: dlg.triggerLogin
    property alias triggerClose: dlg.triggerClose

    Dialog {
        id: dlg
        title: "Đăng nhập"
        modal: true
        standardButtons: Dialog.Close
        parent: (Overlay.overlay ? Overlay.overlay : loginDialog)
        anchors.centerIn: parent

        // Fields for logic
        property string username: ""
        property string password: ""
        property string error: ""
        property bool triggerLogin: false
        property bool triggerClose: false

        contentItem: ColumnLayout {
            anchors.margins: 16
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Tài khoản"; color: "#222"; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                    TextField {
                        id: tfUser
                        placeholderText: "admin"
                        text: loginDialog.username
                        color: "#111"
                        Layout.fillWidth: true
                        onTextChanged: loginDialog.username = text
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Mật khẩu"; color: "#222"; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                    TextField {
                        id: tfPass
                        placeholderText: "••••••"
                        text: loginDialog.password
                        echoMode: TextInput.Password
                        color: "#111"
                        Layout.fillWidth: true
                        onTextChanged: loginDialog.password = text
                        Keys.onReturnPressed: loginDialog.triggerLogin = !loginDialog.triggerLogin
                    }
                }
                Text { text: loginDialog.error; color: "#c62828"; visible: loginDialog.error.length > 0 }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    Button {
                        text: "Hủy"
                        onClicked: dlg.close()
                    }
                    Button {
                        text: "Đăng nhập"
                        highlighted: true
                        onClicked: loginDialog.triggerLogin = !loginDialog.triggerLogin
                    }
                }
            }
        }
    }
}
