import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
	id: adminPage
	// Shared refs and triggers
	property Item pricingLogicRef
	property bool triggerLogoutAndClose: false
	property bool triggerClose: false
	property bool triggerLogin: false
	// Subscriptions edit/save
	property bool subEditMode: false
	property bool triggerSubEdit: false
	property bool triggerSubSave: false
	// Back-compat triggers (not used here but kept for logic compatibility)
	property bool triggerSubCreate: false
	property bool triggerSubExtend: false
	property bool triggerSubLostDelete: false
	// Pricing triggers/edit (placeholders kept for compatibility with other logic)
	property bool triggerAddPricing: false
	property bool triggerSavePricing: false
	property bool triggerDeletePricing: false
	property bool pricingEditMode: false

	// Data models
	ListModel {
		id: subscriptionsModel
	}
	property alias subscriptionsModel: subscriptionsModel

	// Header
	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 12
		spacing: 10

		RowLayout {
			Layout.fillWidth: true
			Text {
				text: "Quản trị hệ thống"
				color: "black"
				font.pixelSize: 20
				font.bold: true
			}
			Item {
				Layout.fillWidth: true
			}
			Rectangle {
				width: 100
				height: 30
				radius: 6
				color: "#444"
				Text {
					anchors.centerIn: parent
					text: "Đăng xuất"
					color: "white"
				}
				MouseArea {
					anchors.fill: parent
					onClicked: adminPage.triggerLogoutAndClose = true
				}
			}
		}

		// Subscriptions section (cleaned)
		Rectangle {
			Layout.fillWidth: true
			Layout.fillHeight: true
			color: "#f0f0f0"
			radius: 8
			border.color: "#ddd"

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 10
				spacing: 10

				// Only Edit and Save
				RowLayout {
					Layout.fillWidth: true
					spacing: 8
					Rectangle {
						width: 110
						height: 30
						radius: 8
						color: adminPage.subEditMode ? "#777" : "#2b7"
						Text {
							anchors.centerIn: parent
							text: "Chỉnh sửa"
							color: "white"
						}
						MouseArea {
							anchors.fill: parent
							enabled: !adminPage.subEditMode
							onClicked: adminPage.triggerSubEdit = !adminPage.triggerSubEdit
						}
					}
					Rectangle {
						width: 110
						height: 30
						radius: 8
						color: adminPage.subEditMode ? "#2b7" : "#777"
						Text {
							anchors.centerIn: parent
							text: "Lưu"
							color: "white"
						}
						MouseArea {
							anchors.fill: parent
							enabled: adminPage.subEditMode
							onClicked: adminPage.triggerSubSave = !adminPage.triggerSubSave
						}
					}
					Item {
						Layout.fillWidth: true
					}
				}

				// Subscriptions table
				Rectangle {
					Layout.fillWidth: true
					Layout.fillHeight: true
					color: "#222"
					border.color: "#333"
					radius: 8

					ColumnLayout {
						anchors.fill: parent
						anchors.margins: 8
						spacing: 6

						// Header row
						RowLayout {
							Layout.fillWidth: true
							spacing: 8
							Text {
								text: "ID"
								color: "white"
								Layout.preferredWidth: 60
							}
							Text {
								text: "Người dùng"
								color: "white"
								Layout.preferredWidth: 160
							}
							Text {
								text: "Biển số"
								color: "white"
								Layout.preferredWidth: 120
							}
							Text {
								text: "ID thẻ"
								color: "white"
								Layout.preferredWidth: 120
							}
							Text {
								text: "Bắt đầu"
								color: "white"
								Layout.preferredWidth: 120
							}
							Text {
								text: "Kết thúc"
								color: "white"
								Layout.preferredWidth: 120
							}
							Text {
								text: "Trạng thái"
								color: "white"
								Layout.preferredWidth: 100
							}
							Text {
								text: "Thanh toán"
								color: "white"
								Layout.preferredWidth: 100
							}
							Text {
								text: "Gói"
								color: "white"
								Layout.preferredWidth: 80
							}
							Text {
								text: "Giá"
								color: "white"
								Layout.preferredWidth: 100
							}
							Item {
								Layout.fillWidth: true
							}
						}

						// List
						ListView {
							Layout.fillWidth: true
							Layout.fillHeight: true
							clip: true
							model: subscriptionsModel
							delegate: RowLayout {
								Layout.fillWidth: true
								spacing: 8
								// readonly columns
								Text {
									text: model.id
									color: "#ccc"
									Layout.preferredWidth: 60
								}
								Text {
									text: model.full_name
									color: "white"
									Layout.preferredWidth: 160
								}
								// editable when subEditMode
								TextField {
									id: tfPlate
									text: model.plate
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 120
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfPlate
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'plate',
														tfPlate.text)
									}
								}

								TextField {
									id: tfRfid
									text: model.rfid
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 120
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfRfid
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'rfid',
														tfRfid.text)
									}
								}

								TextField {
									id: tfStart
									text: model.start_date
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 120
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfStart
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'start_date',
														tfStart.text)
									}
								}

								TextField {
									id: tfEnd
									text: model.end_date
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 120
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfEnd
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'end_date',
														tfEnd.text)
									}
								}

								TextField {
									id: tfStatus
									text: model.status
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 100
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfStatus
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'status',
														tfStatus.text)
									}
								}

								TextField {
									id: tfPayment
									text: model.payment_mode
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 100
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfPayment
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'payment_mode',
														tfPayment.text)
									}
								}

								TextField {
									id: tfPlan
									text: model.plan_type
									readOnly: !adminPage.subEditMode
									Layout.preferredWidth: 80
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfPlan
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'plan_type',
														tfPlan.text)
									}
								}

								TextField {
									id: tfPrice
									text: ("" + model.price)
									readOnly: !adminPage.subEditMode
									validator: IntValidator {
										bottom: 0
										top: 100000000
									}
									Layout.preferredWidth: 100
									color: "white"
									background: Rectangle {
										color: readOnly ? "#333" : "#2a2a2a"
										radius: 6
										border.color: "#555"
									}
								}
								Connections {
									target: tfPrice
									function onTextChanged() {
										if (adminPage.subEditMode)
											subscriptionsModel.setProperty(
														index, 'price',
														(tfPrice.text
														 && tfPrice.text.length ? (tfPrice.text - 0) : 0))
									}
								}
							}
						}
					}
				}
			}
		}
	}

	// Hidden placeholders to satisfy property alias references used by other logic files
	Item {
		id: hiddenPlaceholders
		visible: false
		width: 0
		height: 0
		// Tab bar alias target
		Item {
			id: tabbar
		}
		// Pricing controls
		ComboBox {
			id: pricingVehicle
		}
		ComboBox {
			id: pricingType
		}
		TextArea {
			id: pricingJson
		}
		// Structured pricing fields (placeholders so logic can bind)
		TextField {
			id: pricingBaseFee
		}
		TextField {
			id: pricingGraceMinutes
		}
		TextField {
			id: pricingIncEvery
		}
		TextField {
			id: pricingIncFee
		}
		TextField {
			id: pricingCap
		}
		// Subscription form controls kept as invisible placeholders
		ComboBox {
			id: subVehicle
		}
		ComboBox {
			id: subUser
		}
		TextField {
			id: subPlate
		}
		TextField {
			id: subRfid
		}
		ComboBox {
			id: subPlan
		}
		TextField {
			id: subStart
		}
		TextField {
			id: subEnd
		}
		ComboBox {
			id: subPayment
		}
		TextField {
			id: subPrice
		}
	}

	// Login overlay
	property bool loginVisible: true
	property alias loginUserField: tfLoginUser
	property alias loginPassField: tfLoginPass
	property alias loginErrorLabel: loginError
	Rectangle {
		id: loginOverlay
		anchors.fill: parent
		visible: adminPage.loginVisible
		z: 1000
		color: "#6f6f6f"
		Rectangle {
			width: (parent.width * 0.4) < 520 ? (parent.width * 0.4) : 520
			height: 320
			radius: 10
			color: "#F5F6F8"
			border.color: "#D9DCE3"
			anchors.centerIn: parent
			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 20
				spacing: 12
				Text {
					text: "Đăng nhập"
					color: "#111"
					font.pixelSize: 20
					font.bold: true
				}
				RowLayout {
					Layout.fillWidth: true
					spacing: 8
					Text {
						text: "Tài khoản"
						color: "#222"
						Layout.preferredWidth: 100
						horizontalAlignment: Text.AlignRight
					}
					TextField {
						id: tfLoginUser
						Layout.fillWidth: true
						placeholderText: "admin"
						color: "#111"
					}
				}
				RowLayout {
					Layout.fillWidth: true
					spacing: 8
					Text {
						text: "Mật khẩu"
						color: "#222"
						Layout.preferredWidth: 100
						horizontalAlignment: Text.AlignRight
					}
					TextField {
						id: tfLoginPass
						Layout.fillWidth: true
						placeholderText: "••••••"
						echoMode: TextInput.Password
						color: "#111"
						Keys.onReturnPressed: adminPage.triggerLogin = !adminPage.triggerLogin
					}
				}
				Text {
					id: loginError
					text: ""
					color: "#c62828"
					visible: text.length > 0
				}
				RowLayout {
					Layout.alignment: Qt.AlignRight
					spacing: 8
					Button {
						text: "Đóng"
						onClicked: adminPage.triggerClose = !adminPage.triggerClose
					}
					Button {
						text: "Đăng nhập"
						highlighted: true
						onClicked: adminPage.triggerLogin = !adminPage.triggerLogin
					}
				}
			}
		}
	}
}
