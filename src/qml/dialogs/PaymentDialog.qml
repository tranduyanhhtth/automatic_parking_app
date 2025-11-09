import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    title: "Xác nhận thanh toán"
    width: 450
    standardButtons: Dialog.NoButton
    padding: 20

    property int fee: 0
    property string rfid: ""
    property string plate: ""

    // Position in the center-right of screen
    // Position in the center of screen
    anchors.centerIn: parent

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        Label {
            text: "Khách hàng thanh toán: " + fee.toLocaleString('vi-VN') + " VNĐ"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Vui lòng chọn phương thức thanh toán:"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Button {
                text: "Chuyển khoản"
                highlighted: true
                Layout.preferredWidth: 150
                Layout.preferredHeight: 45
                font.pixelSize: 16
                onClicked: {
                    app.completeCheckout(root.rfid, root.plate, "Chuyển khoản", root.fee)
                    root.close()
                }
            }

            Button {
                text: "Tiền mặt"
                Layout.preferredWidth: 150
                Layout.preferredHeight: 45
                font.pixelSize: 16
                onClicked: {
                    app.completeCheckout(root.rfid, root.plate, "Tiền mặt", root.fee)
                    root.close()
                }
            }
        }
    }
}
