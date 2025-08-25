import QtQuick
import QtQuick.Layouts

Item {
	id: navDrawer
	// Simple open state for the sliding panel
	property bool opened: false
	// Triggers for logic
	property bool triggerSearch: false
	property bool triggerAdmin: false
	property bool triggerClose: false

	// Light theme palette (elegant light gray/white)
	readonly property color bgOverlay: "#66000000"      // dim background
	readonly property color panelBg:   "#F5F6F8"        // drawer background
	readonly property color cardBg:    "#FFFFFF"        // item background
	readonly property color borderCol: "#D9DCE3"        // borders
	readonly property color textCol:   "#111111"        // primary text (black-ish)
	readonly property color subText:   "#555B65"        // secondary text
	readonly property color hoverBg:   "#F1F3F6"        // hover state
	readonly property color accentCol: "#2B78E4"        // subtle accent (blue)
	readonly property color dangerBg:  "#FDECEC"        // soft red bg for Close
	readonly property color dangerBor: "#F2B8B5"        // soft red border
	readonly property color dangerTxt: "#8A1C1C"        // dark red text

	// Lớp che nền khi menu mở
	Rectangle {
		anchors.fill: parent
		color: bgOverlay // đen mờ
		visible: navDrawer.opened
		z: 0
		MouseArea { anchors.fill: parent; onClicked: navDrawer.opened = false }
	}
	// Sliding panel from the left
	Rectangle {
		id: panel
		y: 0
		width: (((parent ? parent.width : 1200) * 0.3) < 360 ? ((parent ? parent.width : 1200) * 0.3) : 360)
		height: parent ? parent.height : 800
		x: navDrawer.opened ? 0 : -width
		z: 1
		color: panelBg
		border.color: borderCol
		Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 12
			spacing: 10
			Text { text: "Menu"; color: textCol; font.pixelSize: 18; font.bold: true }
			// Item: Tìm kiếm
			Rectangle {
				Layout.fillWidth: true; height: 44; radius: 8
				property bool hovered: false
				color: hovered ? hoverBg : cardBg
				border.color: hovered ? accentCol : borderCol
				border.width: 1
				Text { anchors.centerIn: parent; text: "Tìm kiếm"; color: textCol; font.pixelSize: 16 }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: parent.hovered = true
					onExited: parent.hovered = false
					onClicked: navDrawer.triggerSearch = !navDrawer.triggerSearch
				}
			}
			// Item: Quản trị hệ thống
			Rectangle {
				Layout.fillWidth: true; height: 44; radius: 8
				property bool hovered: false
				color: hovered ? hoverBg : cardBg
				border.color: hovered ? accentCol : borderCol
				border.width: 1
				Text { anchors.centerIn: parent; text: "Quản trị hệ thống"; color: textCol; font.pixelSize: 16 }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: parent.hovered = true
					onExited: parent.hovered = false
					onClicked: navDrawer.triggerAdmin = !navDrawer.triggerAdmin
				}
			}
			Item { Layout.fillHeight: true }
			// Item: Đóng (nổi bật nhẹ với đỏ nhạt)
			Rectangle {
				Layout.fillWidth: true; height: 44; radius: 8
				property bool hovered: false
				color: hovered ? "#FAD9D7" : dangerBg
				border.color: hovered ? "#E48A84" : dangerBor
				border.width: 1
				Text { anchors.centerIn: parent; text: "Đóng"; color: dangerTxt; font.pixelSize: 16; font.bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: parent.hovered = true
					onExited: parent.hovered = false
					onClicked: navDrawer.triggerClose = !navDrawer.triggerClose
				}
			}
		}
	}
}
