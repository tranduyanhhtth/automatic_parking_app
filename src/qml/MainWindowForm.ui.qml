import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./components"
import "./dialogs"

Item {
    id: root
    width: 1920
    height: 1080

    // Expose properties for logic
    property alias inputVideoLane1: lane1.inputVideo
    property alias outputVideoLane1: lane1.outputVideo
    property alias inputPreviewLane1: lane1.inputPreview
    property alias outputPreviewLane1: lane1.outputPreview
    property alias inputVideoLane2: lane2.inputVideo
    property alias outputVideoLane2: lane2.outputVideo
    property alias inputPreviewLane2: lane2.inputPreview
    property alias outputPreviewLane2: lane2.outputPreview
    property alias btnSettings: btnSettings
    property alias settingsMenu: settingsMenu
    // Expose dialog wrapper components and their fields (avoid aliasing to inner alias properties)
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
    property alias miCamera: miCamera
    property alias miBarrier: miBarrier
    property alias miExit: miExit
    property alias titleLabel: titleLabel
    property alias titleMenu: titleMenu
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
    property alias miSearch: miSearch
    property alias miAdmin: miAdmin
    property alias searchFromDatePicker: searchDialog.dpFrom
    property alias searchFromTimePicker: searchDialog.tpFrom
    property alias searchToDatePicker: searchDialog.dpTo
    property alias searchToTimePicker: searchDialog.tpTo
    property alias tfSearchRfid: searchDialog.tfSearchRfid
    property alias tfSearchPlate: searchDialog.tfSearchPlate
    property alias cbSearchStatus: searchDialog.cbSearchStatus
    property var searchResults: []
    property bool triggerOpenTitleMenu: false

    // Expose preview source bindings for logic
    property alias lane1InputPreviewSource: lane1.inputPreviewSource
    property alias lane1OutputPreviewSource: lane1.outputPreviewSource
    property alias lane2InputPreviewSource: lane2.inputPreviewSource
    property alias lane2OutputPreviewSource: lane2.outputPreviewSource

    property string timeInText: ""
    property string timeOutText: ""

    Rectangle {
        anchors.fill: parent
        color: "#f0f0f0"

        ColumnLayout {
            anchors.fill: parent
            spacing: 2

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: "black"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Text {
                        id: titleLabel
                        text: "BÃI ĐỖ XE TỰ ĐỘNG"
                        font.bold: true
                        font.pixelSize: 28
                        color: "white"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                        MouseArea {
                            anchors.fill: parent
                            onClicked: (root.triggerOpenTitleMenu = !root.triggerOpenTitleMenu)
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ToolButton {
                        id: btnSettings
                        text: "⚙"
                        font.pixelSize: 20
                        Accessible.name: "Settings"
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }
                    Menu {
                        id: settingsMenu
                        y: btnSettings.height
                        MenuItem {
                            id: miCamera
                            text: "Cấu hình Camera"
                        }
                        MenuItem {
                            id: miBarrier
                            text: "Cấu hình Barrier"
                        }
                        MenuSeparator {}
                        MenuItem {
                            id: miExit
                            text: "Thoát ứng dụng"
                        }
                    }
                    Menu {
                        id: titleMenu
                        y: titleLabel.height
                        MenuItem {
                            id: miSearch
                            text: "Tìm kiếm phiên"
                        }
                        MenuItem {
                            id: miAdmin
                            text: "Quản trị hệ thống"
                        }
                    }
                }
            }

            // Main content
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
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        color: "#FFF7E0"
                        border.color: "#E0C97A"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12
                            Text {
                                text: "THÔNG BÁO TIỀN:"
                                font.bold: true
                                font.pixelSize: 24
                                color: "#8A6D3B"
                            }
                            Text {
                                text: app.moneyMessage || ""
                                color: "#8A6D3B"
                                font.pixelSize: 24
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Dialogs
    AdminDialog {
        id: adminDialog
    }
    CameraSettingsDialog {
        id: cameraSettingsDialog
    }
    BarrierSettingsDialog {
        id: barrierSettingsDialog
    }
    SearchDialog {
        id: searchDialog
    }
}
