import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: root
    title: "Chỉnh sửa thông tin công ty"
    modal: true
    width: 700
    height: 650
    anchors.centerIn: parent
    standardButtons: Dialog.Ok | Dialog.Cancel

    // Properties to export data
    property alias headerTitle: tfHeader.text
    property alias companyName: tfName.text
    property alias address: tfAddress.text
    property alias phone: tfPhone.text
    property alias email: tfEmail.text
    property string logoSource: ""

    // Function to populate data when opening
    function loadData(title, name, addr, ph, mail, logo) {
        tfHeader.text = title
        tfName.text = name
        tfAddress.text = addr
        tfPhone.text = ph
        tfEmail.text = mail
        root.logoSource = logo
    }

    contentItem: ColumnLayout {
        spacing: 15

        // --- Logo Section ---
        GroupBox {
            title: "Logo công ty"
            Layout.fillWidth: true

            RowLayout {
                spacing: 20
                Image {
                    id: imgPreview
                    source: root.logoSource
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60
                    fillMode: Image.PreserveAspectFit
                    cache: false // Ensure refresh on change

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#ccc"
                        visible: imgPreview.status !== Image.Ready
                    }
                }

                Button {
                    text: "Chọn ảnh..."
                    icon.name: "document-open"
                    onClicked: fileDialog.open()
                }
            }
        }

        // --- Text Fields ---
        GroupBox {
            title: "Thông tin hiển thị"
            Layout.fillWidth: true

            GridLayout {
                width: parent.width
                columns: 2
                rowSpacing: 10
                columnSpacing: 10
                //Layout.fillWidth: true

                Label { text: "Tiêu đề (Header):" }
                TextField {
                    id: tfHeader
                    Layout.fillWidth: true
                    placeholderText: "Ví dụ: Contact us"
                }

                Label { text: "Tên công ty:" }
                TextField {
                    id: tfName
                    Layout.fillWidth: true
                    placeholderText: "Tên công ty hiển thị"
                }

                Label { text: "Địa chỉ:" }
                TextField {
                    id: tfAddress
                    Layout.fillWidth: true
                    placeholderText: "Địa chỉ hiển thị"
                }

                Label { text: "Số điện thoại:" }
                TextField {
                    id: tfPhone
                    Layout.fillWidth: true
                    placeholderText: "+84..."
                }

                Label { text: "Email:" }
                TextField {
                    id: tfEmail
                    Layout.fillWidth: true
                    placeholderText: "email@example.com"
                }
            }
        }
    }

    // Local File Dialog for picking image
    FileDialog {
        id: fileDialog
        title: "Chọn logo"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg)"]
        onAccepted: {
            // Update the local property, usually preprends file:///
            root.logoSource = selectedFile
        }
    }
}
