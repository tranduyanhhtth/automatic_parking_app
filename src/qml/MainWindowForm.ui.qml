import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./components"
import "./dialogs"

Item {
    id: root
    width: 1920
    height: 1080

    // --- LOGIC PROPERTIES ---
    property alias inputVideoLane1: lane1.inputVideo
    property alias outputVideoLane1: lane1.outputVideo
    property alias inputPreviewLane1: lane1.inputPreview
    property alias outputPreviewLane1: lane1.outputPreview
    property alias inputVideoLane2: lane2.inputVideo
    property alias outputVideoLane2: lane2.outputVideo
    property alias inputPreviewLane2: lane2.inputPreview
    property alias outputPreviewLane2: lane2.outputPreview

    // --- HEADER INTERACTION ALIASES ---
    property alias btnSearch: btnSearch
    property alias btnSettings: btnSettings
    property alias btnAdmin: btnAdmin
    property alias settingsMenu: settingsMenu
    property alias miEditInfo: miEditInfo
    property alias editInfoDialog: editInfoDialog

    // Logo Alias
    property alias logoSource: imgHeaderLogo.source
    // property alias btnChangeLogo: miChangeLogo
    // property alias logoMouseArea: logoMouseArea
    // property alias logoContextMenu: logoContextMenu

    // **NEW**: Header Text Field Aliases (Editable Info)
    property alias tfHeaderTitle: txtHeaderTitle
    property alias tfCompanyName: txtCompanyName
    property alias tfAddress: txtAddress
    property alias tfPhone: txtPhone
    property alias tfEmail: txtEmail

    // --- DIALOG ALIASES ---
    property alias cameraSettingsDialog: cameraSettingsDialog
    property alias barrierSettingsDialog: barrierSettingsDialog
    property alias adminDialog: adminDialog
    property alias searchDialog: searchDialog

    // Camera settings fields
    property alias tfCam1: cameraSettingsDialog.tfCam1
    property alias tfCam2: cameraSettingsDialog.tfCam2
    property alias tfCam3: cameraSettingsDialog.tfCam3
    property alias tfCam4: cameraSettingsDialog.tfCam4

    // Barrier settings fields
    property alias tfCom1: barrierSettingsDialog.tfCom1
    property alias cbBaud1: barrierSettingsDialog.cbBaud1
    property alias tfCom2: barrierSettingsDialog.tfCom2
    property alias cbBaud2: barrierSettingsDialog.cbBaud2

    // Menu Items
    property alias miCamera: miCamera
    property alias miBarrier: miBarrier
    property alias miExit: miExit

    // Admin (pricing) fields
    property alias pricingGrace: adminDialog.tfGrace
    property alias pricingBaseMinutes: adminDialog.tfBaseMinutes
    property alias pricingBasePrice: adminDialog.tfBasePrice
    property alias pricingIncMinutes: adminDialog.tfIncMinutes
    property alias pricingIncPrice: adminDialog.tfIncPrice
    property alias pricingCapPerDay: adminDialog.tfCapPerDay
    property alias pricingIncremental: adminDialog.cbIncremental
    property alias pricingOvernight: adminDialog.tfOvernight
    property alias pricingLostCard: adminDialog.tfLost
    property alias pricingSlotsModel: adminDialog.slotsModel
    property alias pricingVehicleCombo: adminDialog.cbVehicle
    property alias pricingTicketCombo: adminDialog.cbTicket

    // Search fields
    property alias searchFromDatePicker: searchDialog.dpFrom
    property alias searchFromTimePicker: searchDialog.tpFrom
    property alias searchToDatePicker: searchDialog.dpTo
    property alias searchToTimePicker: searchDialog.tpTo
    property alias tfSearchRfid: searchDialog.tfSearchRfid
    property alias tfSearchPlate: searchDialog.tfSearchPlate
    property alias cbSearchStatus: searchDialog.cbSearchStatus
    property var searchResults: []
    property bool triggerOpenTitleMenu: false

    // Preview source bindings
    property alias lane1InputPreviewSource: lane1.inputPreviewSource
    property alias lane1OutputPreviewSource: lane1.outputPreviewSource
    property alias lane2InputPreviewSource: lane2.inputPreviewSource
    property alias lane2OutputPreviewSource: lane2.outputPreviewSource
    property alias lane1MoneyMessage: lane1.moneyMessage
    property alias lane2MoneyMessage: lane2.moneyMessage

    property string timeInText: ""
    property string timeOutText: ""

    property alias lane1Obj: lane1
    property alias lane2Obj: lane2

    Rectangle {
        anchors.fill: parent
        color: "#f0f0f0"

        ColumnLayout {
            anchors.fill: parent
            spacing: 2

            // --- HEADER SECTION ---
            Rectangle {
                Layout.fillWidth: true
                height: 135
                color: "black"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 15

                    // 1. The Logo Image (Top Left)
                    Image {
                        id: imgHeaderLogo
                        // Default placeholder if empty, or binds to logoSource alias
                        source: "C:/Projects/automatic_parking_app/src/assets/logo_icon.jpg"
                        fillMode: Image.PreserveAspectFit
                        Layout.preferredHeight: 90
                        Layout.preferredWidth: 160
                    }

                    // 2. The Text Information (Now Editable TextFields)
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        // Header Title ("Contact us")
                        Text {
                            id: txtHeaderTitle
                            text: "Contact us"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Company Name
                        Text {
                                                id: txtCompanyName
                                                text: "AITHINGS TECHNOLOGY CO., LTD"
                                                color: "#cccccc"
                                                font.pixelSize: 14
                                                font.bold: true
                                                verticalAlignment: Text.AlignVCenter
                                            }

                        // Address
                        Text {
                                                id: txtAddress
                                                text: "Address: 4th floor, Minori Office Building, 67A Truong Dinh, Hanoi"
                                                color: "white"
                                                font.pixelSize: 12
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 600
                                            }

                        // Contact Row (Phone and Email)
                        RowLayout {
                            spacing: 15

                            Text {
                                                        id: txtPhone
                                                        text: "📞 +84 38 815 6494"
                                                        color: "white"
                                                        font.pixelSize: 12
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    Text {
                                                        id: txtEmail
                                                        text: "📧 info@aithings.vn"
                                                        color: "white"
                                                        font.pixelSize: 12
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                        }
                    }

                    // Spacer
                    Item {
                        Layout.fillWidth: true
                    }

                    // --- TOOL BUTTONS (Right Side) ---
                    ToolButton {
                        id: btnAdmin
                        text: "🧑‍💼"
                        font.pixelSize: 40
                        Accessible.name: "Admin"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }
                    ToolButton{
                        id: btnSearch
                        text: "🔍"
                        font.pixelSize: 40
                        Accessible.name: "Search"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }

                    ToolButton {
                        id: btnSettings
                        text: "⚙"
                        font.pixelSize: 40
                        Accessible.name: "Settings"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }

                    Menu {
                        id: settingsMenu
                        y: btnSettings.height
                        MenuItem {
                                                id: miEditInfo
                                                text: "Chỉnh sửa thông tin"
                                                icon.name: "document-edit"
                                            }
                                            MenuSeparator {}
                        MenuItem { id: miCamera; text: "Cấu hình Camera" }
                        MenuItem { id: miBarrier; text: "Cấu hình Barrier" }
                        MenuSeparator {}
                        MenuItem { id: miExit; text: "Thoát ứng dụng" }
                    }
                }
            }

            // --- MAIN CONTENT ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                border.width: 1
                border.color: "#888"
                radius: 4
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    // Lanes row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        // Lane 1
                        LaneComponent {
                            id: lane1
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            laneTitle: (app.dualMode === 2 ? "CỔNG RA" : "CỔNG VÀO")
                            isEntrance: app.dualMode !== 2
                        }
                        // Lane 2
                        LaneComponent {
                            id: lane2
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            laneTitle: (app.dualMode === 1 ? "CỔNG VÀO" : "CỔNG RA")
                            isEntrance: app.dualMode === 1
                        }
                    }
                }
            }
        }
    }

    // Dialogs
    AdminDialog { id: adminDialog }
    CameraSettingsDialog { id: cameraSettingsDialog }
    BarrierSettingsDialog { id: barrierSettingsDialog }
    SearchDialog { id: searchDialog }
    EditCompanyInfoDialog { id: editInfoDialog }
}
