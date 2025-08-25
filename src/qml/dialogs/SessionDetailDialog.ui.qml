import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: sessionDetail
    // Expose inner dialog and data bindings for logic
    property alias dialog: dlg
    property string plate: ""
    property string checkin: ""
    property string checkout: ""
    property int fee: 0
    property string img1Source: ""
    property string img2Source: ""
    property string checkoutImg1Source: ""
    property string checkoutImg2Source: ""

    Dialog {
        id: dlg
        title: "Chi tiết phiên gửi xe"
        modal: true
        standardButtons: Dialog.Close
        parent: (Overlay.overlay ? Overlay.overlay : sessionDetail)
        anchors.centerIn: parent
        width: parent ? ((parent.width * 0.9) < 1100 ? (parent.width * 0.9) : 1100) : 1000
        height: parent ? ((parent.height * 0.9) < 700 ? (parent.height * 0.9) : 700) : 600
        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10
            RowLayout { Layout.fillWidth: true; spacing: 12
                ColumnLayout { spacing: 6
                    Text { text: "Biển số: " + (sessionDetail.plate || ""); color: "#000" }
                    Text { text: "Vào: " + (sessionDetail.checkin || ""); color: "#000" }
                    Text { text: "Ra: " + (sessionDetail.checkout || ""); color: "#000" }
                    Text { text: "Phí: " + (sessionDetail.fee || 0); color: "#000" }
                }
                Item { Layout.fillWidth: true }
            }
            Label { text: "Ảnh check-in"; color: "#000" }
            RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: "#111"; border.color: "#444"; radius: 6
                    Image { anchors.fill: parent; anchors.margins: 6; source: sessionDetail.img1Source; fillMode: Image.PreserveAspectFit; asynchronous: true; visible: sessionDetail.img1Source && sessionDetail.img1Source.length > 0 }
                    Label { anchors.centerIn: parent; text: "Không có ảnh 1"; color: "#aaa"; visible: !sessionDetail.img1Source || sessionDetail.img1Source.length === 0 }
                }
                Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: "#111"; border.color: "#444"; radius: 6
                    Image { anchors.fill: parent; anchors.margins: 6; source: sessionDetail.img2Source; fillMode: Image.PreserveAspectFit; asynchronous: true; visible: sessionDetail.img2Source && sessionDetail.img2Source.length > 0 }
                    Label { anchors.centerIn: parent; text: "Không có ảnh 2"; color: "#aaa"; visible: !sessionDetail.img2Source || sessionDetail.img2Source.length === 0 }
                }
            }
            Label { text: "Ảnh check-out"; color: "#000" }
            RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: "#111"; border.color: "#444"; radius: 6
                    Image { anchors.fill: parent; anchors.margins: 6; source: sessionDetail.checkoutImg1Source; fillMode: Image.PreserveAspectFit; asynchronous: true; visible: sessionDetail.checkoutImg1Source && sessionDetail.checkoutImg1Source.length > 0 }
                    Label { anchors.centerIn: parent; text: "Không có ảnh ra 1"; color: "#aaa"; visible: !sessionDetail.checkoutImg1Source || sessionDetail.checkoutImg1Source.length === 0 }
                }
                Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: "#111"; border.color: "#444"; radius: 6
                    Image { anchors.fill: parent; anchors.margins: 6; source: sessionDetail.checkoutImg2Source; fillMode: Image.PreserveAspectFit; asynchronous: true; visible: sessionDetail.checkoutImg2Source && sessionDetail.checkoutImg2Source.length > 0 }
                    Label { anchors.centerIn: parent; text: "Không có ảnh ra 2"; color: "#aaa"; visible: !sessionDetail.checkoutImg2Source || sessionDetail.checkoutImg2Source.length === 0 }
                }
            }
        }
    }
}
