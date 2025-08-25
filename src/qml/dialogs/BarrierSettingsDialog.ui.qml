import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: barrierSettingsDialog
    // Expose fields
    property alias tfCom1: tfCom1
    property alias cbBaud1: cbBaud1
    property alias tfCom2: tfCom2
    property alias cbBaud2: cbBaud2
    // Expose inner dialog
    property alias dialog: dlg

    Dialog {
        id: dlg
        title: "Cấu hình Barrier"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        parent: (Overlay.overlay ? Overlay.overlay : barrierSettingsDialog)
        anchors.centerIn: parent
        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 14
            GroupBox {
                title: "Barrier 1 (Lane 1)"
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.margins: 8
                    spacing: 8
                    Label {
                        text: "Cổng COM"
                    }
                    TextField {
                        id: tfCom1
                        text: settings.barrier1Port
                        Layout.preferredWidth: 260
                        placeholderText: "VD: COM3"
                    }
                    Label {
                        text: "Baudrate"
                    }
                    ComboBox {
                        id: cbBaud1
                        model: [9600, 19200, 38400, 57600, 115200]
                    }
                }
            }
            GroupBox {
                title: "Barrier 2 (Lane 2)"
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.margins: 8
                    spacing: 8
                    Label {
                        text: "Cổng COM"
                    }
                    TextField {
                        id: tfCom2
                        text: settings.barrier2Port
                        Layout.preferredWidth: 260
                        placeholderText: "VD: COM4"
                    }
                    Label {
                        text: "Baudrate"
                    }
                    ComboBox {
                        id: cbBaud2
                        model: [9600, 19200, 38400, 57600, 115200]
                    }
                }
            }
        }
    }
}
