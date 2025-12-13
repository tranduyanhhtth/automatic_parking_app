import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQml
import QtQuick.Layouts
import QtQuick.Dialogs
import "./components"
import "./dialogs"
import "./logic"
import "./pages"
// Import qua qrc để đảm bảo phân giải type khi chạy từ resource
import "qrc:/qt/qml/smart_parking_system/src/qml/logic" as AdminLogic
import "qrc:/qt/qml/smart_parking_system/src/qml/pages" as Pages

Item {
    id: root
    width: 1920
    height: 1080
    focus: true
    Keys.enabled: true

    // Hardcoded accounts
    readonly property var allowedAccounts: [
        { username: "admin", password: "123" },
        { username: "manager", password: "123" }
    ]
    // Simple auth state for Admin access
    property bool isAuthenticated: false

    // Key handling for mode switching
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F9) {
            hidLogPanel.visible = !hidLogPanel.visible
            e.accepted = true
        } else if (e.key === Qt.Key_F1) {
            const newMode = (app.dualMode === 1 ? 0 : 1)
            app.setDualMode(newMode)
            root.showToast(newMode === 1 ? "Chế độ: Cả hai CỔNG VÀO" : "Chế độ: Cổng Vào/Ra")
            e.accepted = true
        } else if (e.key === Qt.Key_F2) {
            const newMode = (app.dualMode === 2 ? 0 : 2)
            app.setDualMode(newMode)
            root.showToast(newMode === 2 ? "Chế độ: Cả hai CỔNG RA" : "Chế độ: Cổng Vào/Ra")
            e.accepted = true
        } else if (e.key === Qt.Key_F3) {
            app.setDualMode(0)
            root.showToast("Chế độ: Cổng Vào/Ra")
            e.accepted = true
        } else if (e.key === Qt.Key_F5) {
            // Toggle Navigation Drawer
            navDrawer.opened = !navDrawer.opened
            e.accepted = true
        }
    }

    FileDialog {
            id: logoFileDialog
            title: "Select Company Logo"
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg)"]
            onAccepted: {
                // Update the source in the form
                // 'selectedFile' usually returns a URL (file:///...)
                app.logoSource = selectedFile

                // Optional: You can save this URL to your 'app' settings here
                // app.saveLogoSetting(selectedFile)
            }
        }

    // Khu vực nội dung chính (Content Pane) bên phải
    StackLayout {
        id: contentStack
        anchors.fill: parent
        currentIndex: 0 // 0: Trang chính, 1: Tìm kiếm, 2: Quản trị
        // Trang chính (làn xe)
        Item {
            id: homePage
            Layout.fillWidth: true
            Layout.fillHeight: true
            MainWindowForm {
                id: form
                anchors.fill: parent
                Connections {
                            target: form.lane1Obj.exitPlateMouseArea
                            function onClicked() {
                                form.lane1Obj.exitPlateInput.visible = true
                                form.lane1Obj.exitPlateInput.forceActiveFocus()
                            }
                        }
                        Connections {
                            target: form.lane1Obj.exitPlateInput
                            function onAccepted() {
                                // Lane 1 is index 0
                                app.updateManualPlate(0, form.lane1Obj.exitPlateInput.text)
                                form.lane1Obj.exitPlateInput.visible = false
                                form.lane1Obj.exitPlateInput.text = ""
                            }
                        }

                        // Logic for Lane 1 (Entrance Plate)
                        Connections {
                            target: form.lane1Obj.entrancePlateMouseArea
                            function onClicked() {
                                form.lane1Obj.entrancePlateInput.visible = true
                                form.lane1Obj.entrancePlateInput.forceActiveFocus()
                            }
                        }
                        Connections {
                            target: form.lane1Obj.entrancePlateInput
                            function onAccepted() {
                                app.updateManualPlate(0, form.lane1Obj.entrancePlateInput.text)
                                form.lane1Obj.entrancePlateInput.visible = false
                                form.lane1Obj.entrancePlateInput.text = ""
                            }
                        }

                        // Repeat Logic for Lane 2 (Index 1)
                        Connections {
                            target: form.lane2Obj.exitPlateMouseArea
                            function onClicked() {
                                form.lane2Obj.exitPlateInput.visible = true
                                form.lane2Obj.exitPlateInput.forceActiveFocus()
                            }
                        }
                        Connections {
                            target: form.lane2Obj.exitPlateInput
                            function onAccepted() {
                                app.updateManualPlate(1, form.lane2Obj.exitPlateInput.text)
                                form.lane2Obj.exitPlateInput.visible = false
                                form.lane2Obj.exitPlateInput.text = ""
                            }
                        }

                        Connections {
                            target: form.lane2Obj.entrancePlateMouseArea
                            function onClicked() {
                                form.lane2Obj.entrancePlateInput.visible = true
                                form.lane2Obj.entrancePlateInput.forceActiveFocus()
                            }
                        }
                        Connections {
                            target: form.lane2Obj.entrancePlateInput
                            function onAccepted() {
                                app.updateManualPlate(1, form.lane2Obj.entrancePlateInput.text)
                                form.lane2Obj.entrancePlateInput.visible = false
                                form.lane2Obj.entrancePlateInput.text = ""
                            }
                        }
            }
        }
        // Trang Tìm kiếm
        SearchPage {
            id: searchPage
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        // Trang Quản trị
        AdminPage {
            id: adminPage
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // Toast component
    ToastComponent {
        id: toast
        width: parent.width
        anchors.top: parent.top
        z: 9999
    }

    NotifyLogic {
        id: notifyLogic
        toast: toast
    }

    Connections {
        target: app
        function onShowToast(message) {
            if (notifyLogic && notifyLogic.push)
                notifyLogic.push(message)
        }
    }

    // HID Log panel
    HidLogPanel {
        id: hidLogPanel
        width: Math.min(parent.width * 0.5, 900)
        height: Math.min(parent.height * 0.42, 420)
        anchors.centerIn: parent
        z: 9000
        visible: false
        // Bind model from logic
        model: hidLogLogic.hidLogModel
        // Clear trigger handler
        onTriggerClearChanged: if (triggerClear) hidLogLogic.clear()
    }

    // Navigation Drawer (modal)
    NavDrawer {
        id: navDrawer
        anchors.fill: parent
        z: 9500
    }

    // Login Dialog removed in favor of Admin full-screen overlay

    // Wiring cho Drawer và thao tác tiêu đề
    // Connections {
    //     target: form
    //     function onTriggerOpenTitleMenuChanged() {
    //         if (navDrawer.opened) {
    //             navDrawer.opened = false
    //             contentStack.currentIndex = 0
    //         } else {
    //             navDrawer.opened = true
    //         }
    //     }
    // }
    // Connections {
    //         target: form.btnChangeLogo
    //         function onTriggered() {
    //             logoFileDialog.open()
    //         }
    //     }
    // Connections {
    //         target: form.logoMouseArea
    //         function onClicked(mouse) {
    //             // Open the menu programmatically here
    //             form.logoContextMenu.popup()
    //         }
    //     }
    Connections {
            target: form.miEditInfo
            function onTriggered() {
                // Load current app data into the dialog
                form.editInfoDialog.loadData(
                    app.headerTitle,
                    app.companyName,
                    app.companyAddress,
                    app.companyPhone,
                    app.companyEmail,
                    app.logoSource
                )
                form.editInfoDialog.open()
            }
        }

        // 2. Save Data on Dialog Accepted
        Connections {
            target: form.editInfoDialog
            function onAccepted() {
                // Update C++ / Backend app properties
                app.headerTitle = form.editInfoDialog.headerTitle
                app.companyName = form.editInfoDialog.companyName
                app.companyAddress = form.editInfoDialog.address
                app.companyPhone = form.editInfoDialog.phone
                app.companyEmail = form.editInfoDialog.email

                // Only update logo if it changed and is not empty
                if (form.editInfoDialog.logoSource !== "" && form.editInfoDialog.logoSource !== app.logoSource) {
                    app.logoSource = form.editInfoDialog.logoSource
                    // Optional: Trigger saving settings to disk here if your C++ app class requires it
                    // app.saveSettings()
                }

                root.showToast("Đã cập nhật thông tin công ty thành công")
            }
        }
    Connections {
        target: navDrawer
        function onTriggerSearchChanged() {
            if (!navDrawer.triggerSearch) return
            contentStack.currentIndex = 1
            if (navDrawer.opened) navDrawer.opened = false
        }
        function onTriggerAdminChanged() {
            if (!navDrawer.triggerAdmin) return
            // Go to Admin; if not authenticated, show overlay
            contentStack.currentIndex = 2
            adminPage.loginVisible = !root.isAuthenticated
            if (navDrawer.opened) navDrawer.opened = false
        }
        function onTriggerCloseChanged() {
            if (!navDrawer.triggerClose) return
            navDrawer.opened = false
            contentStack.currentIndex = 0
        }
    }

    // Admin orchestrator (handles login, users, pricing save, subscriptions, etc.)
    Loader {
        id: adminLogicLoader
        source: "qrc:/qt/qml/smart_parking_system/src/qml/logic/AdminLogic.qml"
        active: true
        onLoaded: {
            if (item) {
                item.adminPage = adminPage
                item.notify = (msg) => root.showToast(msg)
                item.allowedAccounts = root.allowedAccounts
                adminPage.rfidLogic = item.rfidLogic
                adminPage.usersLogic = item.usersLogic
                adminPage.employeeLogic = item.employeeLogic
                if(item.subsLogic) adminPage.subsLogic = item.subsLogic
            }
            if (item.rfidLogic) {
                item.rfidLogic.tfRfid = adminPage.rfidTextField
                item.rfidLogic.cbVehicle = adminPage.rfidVehicleCombo
                item.rfidLogic.cbTicket = adminPage.rfidTicketCombo
                item.rfidLogic.cbStatus = adminPage.rfidStatusCombo
                //item.rfidLogic.tfDesc = adminPage.rfidDescField
            }
        }
    }
    Connections {
        target: form.btnAdmin
        function onClicked() {
            contentStack.currentIndex = 2
            adminPage.loginVisible = !root.isAuthenticated
        }
    }
    Connections {
        target: searchPage
        function onTriggerCloseChanged() {
            if (searchPage.triggerClose) contentStack.currentIndex = 0
        }
    }
    Connections {
            target: adminPage
            function onTriggerCloseChanged() {
                if (adminPage.triggerClose) {
                    contentStack.currentIndex = 0
                    adminPage.triggerClose = false
                }
            }

            // --- ADD THIS FUNCTION ---
            function onTriggerLogoutAndCloseChanged() {
                if (adminPage.triggerLogoutAndClose) {
                    // 1. Revoke authentication so the check in onTriggerAdminChanged fails next time
                    root.isAuthenticated = false

                    // 2. Force the login overlay to be visible for the next visit
                    adminPage.loginVisible = true

                    adminPage.loginUserField.text = ""
                    adminPage.loginPassField.text = ""
                    adminPage.loginErrorLabel.text = "" // Optional: Clear old error messages

                    // 3. Reset the tab bar to the default view (optional but recommended)
                    if (adminPage.tabBar) adminPage.tabBar.currentIndex = 0

                    // 4. Navigate back to Home
                    contentStack.currentIndex = 0

                    // 5. Reset the trigger
                    adminPage.triggerLogoutAndClose = false
                }
            }
            // -------------------------
        }

    // Logic components
    CameraLogic {
        id: cameraLogic
    }
    BarrierLogic {
        id: barrierLogic
    }
    PricingLogic {
        id: pricingLogic
    }
    // Legacy loaders removed; AdminLogic handles all admin features
    SearchLogic {
        id: searchLogic
        searchPage: searchPage
    }
    HidLogLogic {
        id: hidLogLogic
    }
    PaymentDialog {
            id: paymentDialog
    }

    // Initialize streams and sinks
    Component.onCompleted: {
        // Kết nối logic bảng giá cho trang quản trị sau khi page sẵn sàng
        try {
            if (adminPage && adminPricingLogicLoader.item && adminPage.pricingLogicRef !== undefined)
                adminPage.pricingLogicRef = adminPricingLogicLoader.item
        } catch (e) {
            // Bỏ qua nếu bản UI cũ không có thuộc tính
        }
        // Set video sinks for Lane 1
        if (form.inputVideoLane1 && form.inputVideoLane1.videoSink) {
            cameraLane1.setInputVideoSink(form.inputVideoLane1.videoSink)
        } else {
            console.warn("[QML] Lane 1 input video or videoSink not available")
        }

        if (form.outputVideoLane1 && form.outputVideoLane1.videoSink) {
            cameraLane1.setOutputVideoSink(form.outputVideoLane1.videoSink)
        } else {
            console.warn("[QML] Lane 1 output video or videoSink not available")
        }

        // Set video sinks for Lane 2
        if (form.inputVideoLane2 && form.inputVideoLane2.videoSink) {
            cameraLane2.setInputVideoSink(form.inputVideoLane2.videoSink)
        } else {
            console.warn("[QML] Lane 2 input video or videoSink not available")
        }

        if (form.outputVideoLane2 && form.outputVideoLane2.videoSink) {
            cameraLane2.setOutputVideoSink(form.outputVideoLane2.videoSink)
        } else {
            console.warn("[QML] Lane 2 output video or videoSink not available")
        }

        // Start streams with RTSP options
        cameraLogic.startStreams()

        // Set logo if it exists (requires 'qrc' or 'file' prefix handled in C++ or UI)
        if (app.logoSource !== "") form.logoSource = app.logoSource
    }

    // Bridge functions that were removed from UI files
    function showToast(msg, severity) {
        if (notifyLogic && notifyLogic.push) {
            notifyLogic.push(msg, severity)
        } else if (typeof app !== 'undefined' && app.showToast) {
            // fallback delegate to backend if exposed
            app.showToast(msg)
        } else {
            console.log(msg)
        }
    }

    // 2. UI Interaction Logic (UI -> C++)
    Binding { target: form.tfHeaderTitle; property: "text"; value: app.headerTitle }
        Binding { target: form.tfCompanyName; property: "text"; value: app.companyName }
        Binding { target: form.tfAddress; property: "text"; value: app.companyAddress }
        Binding { target: form.tfPhone; property: "text"; value: app.companyPhone }
        Binding { target: form.tfEmail; property: "text"; value: app.companyEmail }
        // Ensure Logo updates visually when C++ property changes (e.g. on load)
        Connections {
            target: app
            function onLogoSourceChanged() {
                 form.logoSource = app.logoSource
            }
        }

    Connections {
        target: app // This connects to your ParkingController instance
        function onCheckoutRequiresPayment(rfid, plate, fee) {
        paymentDialog.rfid = rfid
        paymentDialog.plate = plate
        paymentDialog.fee = fee
        paymentDialog.open()
           }
       }

    // Logic for the new Header Search Button
    Connections {
        target: form.btnSearch
        function onClicked() {
            // Switch StackLayout to Index 1 (Search Page)
            contentStack.currentIndex = 1
        }
    }


    // Preview source bindings for lanes (bind to alias properties on form)
    // During exit review, only the exit lane should show entrance snapshots
    // Map lane1 as entrance when dualMode !== 2, and lane2 as exit when dualMode !== 1
    Binding {
        target: form
        property: "lane1InputPreviewSource"
        value: app.lane1InputPreviewImage && app.lane1InputPreviewImage.length > 0
               ? app.lane1InputPreviewImage
               : (app.dualMode === 2 ? cameraLane2.inputSnapshotDataUrl
                                      : cameraLane1.inputSnapshotDataUrl)
    }
    Binding {
        target: form
        property: "lane1OutputPreviewSource"
        value: app.lane1OutputPreviewImage && app.lane1OutputPreviewImage.length > 0
               ? app.lane1OutputPreviewImage
               : (app.dualMode === 2 ? cameraLane2.outputSnapshotDataUrl
                                      : cameraLane1.outputSnapshotDataUrl)
    }
    Binding {
        target: form
        property: "lane2InputPreviewSource"
        value: app.lane2InputPreviewImage && app.lane2InputPreviewImage.length > 0
               ? app.lane2InputPreviewImage
               : (app.dualMode === 1 ? cameraLane1.inputSnapshotDataUrl
                                      : cameraLane2.inputSnapshotDataUrl)
    }
    Binding {
        target: form
        property: "lane2OutputPreviewSource"
        value: app.lane2OutputPreviewImage && app.lane2OutputPreviewImage.length > 0
               ? app.lane2OutputPreviewImage
               : (app.dualMode === 1 ? cameraLane1.outputSnapshotDataUrl
                                      : cameraLane2.outputSnapshotDataUrl)
    }
    Binding {
        target: form
        property: "lane1MoneyMessage"
        value: app.lane1MoneyMessage
    }
    Binding {
        target: form
        property: "lane2MoneyMessage"
        value: app.lane2MoneyMessage
    }
}
