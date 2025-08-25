import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQml
import QtQuick.Layouts
import "./components"
import "./dialogs"
import "./logic"
import "./pages"

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
    Connections {
        target: form
        function onTriggerOpenTitleMenuChanged() {
            if (navDrawer.opened) {
                navDrawer.opened = false
                contentStack.currentIndex = 0
            } else {
                navDrawer.opened = true
            }
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

    // Admin page login logic
    AdminLoginLogic { id: adminLoginLogic }
    Connections {
        target: searchPage
        function onTriggerCloseChanged() {
            if (searchPage.triggerClose) contentStack.currentIndex = 0
        }
    }
    Connections {
        target: adminPage
        function onTriggerCloseChanged() {
            if (adminPage.triggerClose) contentStack.currentIndex = 0
        }
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
    SearchLogic {
        id: searchLogic
        searchPage: searchPage
    }
    HidLogLogic {
        id: hidLogLogic
    }

    // Initialize streams and sinks
    Component.onCompleted: {
        // Set video sinks for Lane 1
        if (form.inputVideoLane1 && form.inputVideoLane1.videoSink)
            cameraLane1.setInputVideoSink(form.inputVideoLane1.videoSink)
        if (form.outputVideoLane1 && form.outputVideoLane1.videoSink)
            cameraLane1.setOutputVideoSink(form.outputVideoLane1.videoSink)
        // Set video sinks for Lane 2
        if (form.inputVideoLane2 && form.inputVideoLane2.videoSink)
            cameraLane2.setInputVideoSink(form.inputVideoLane2.videoSink)
        if (form.outputVideoLane2 && form.outputVideoLane2.videoSink)
            cameraLane2.setOutputVideoSink(form.outputVideoLane2.videoSink)

        // Start streams with RTSP options
        cameraLogic.startStreams()
    }

    // Bridge functions that were removed from UI files
    function showToast(msg) {
        toast.message = msg
        toast.triggerShow = !toast.triggerShow
    }

    // Preview source bindings for lanes (bind to alias properties on form)
    Binding { target: form; property: "lane1InputPreviewSource"; value: app.exitReviewAvailable ? (app.exitImage1DataUrl || "") : (app.dualMode !== 2 ? cameraLane1.inputSnapshotDataUrl : cameraLane2.inputSnapshotDataUrl) }
    Binding { target: form; property: "lane1OutputPreviewSource"; value: app.exitReviewAvailable ? (app.exitImage2DataUrl || "") : (app.dualMode !== 2 ? cameraLane1.outputSnapshotDataUrl : cameraLane2.outputSnapshotDataUrl) }
    Binding { target: form; property: "lane2InputPreviewSource"; value: app.exitReviewAvailable ? (app.exitImage1DataUrl || "") : (app.dualMode === 1 ? cameraLane1.inputSnapshotDataUrl : cameraLane2.inputSnapshotDataUrl) }
    Binding { target: form; property: "lane2OutputPreviewSource"; value: app.exitReviewAvailable ? (app.exitImage2DataUrl || "") : (app.dualMode === 1 ? cameraLane1.outputSnapshotDataUrl : cameraLane2.outputSnapshotDataUrl) }
}