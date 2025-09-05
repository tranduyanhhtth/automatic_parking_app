import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../logic"

Item {
	id: adminPage
	property bool triggerClose: false
	property bool triggerLogoutAndClose: false
	// Pricing triggers
	property bool triggerAddPricing: false
	property bool triggerSavePricing: false
	property bool triggerDeletePricing: false
	// Pricing field aliases for logic
	property alias pricingBaseFee: pricingBaseFee
	property alias pricingGraceMinutes: pricingGraceMinutes
	property alias pricingIncEvery: pricingIncEvery
	property alias pricingIncFee: pricingIncFee
	property alias pricingCap: pricingCap
	// Expose vehicle combobox to external logic (AdminPricingActions)
	property alias pricingVehicleCombo: pricingVehicle
	// Login overlay state and triggers
	property bool loginVisible: true
	property bool triggerLogin: false
	// Expose login UI controls to logic
	property alias loginUserField: tfLoginUser
	property alias loginPassField: tfLoginPass
	property alias loginErrorLabel: loginError
	// Expose minimal aliases for logic wiring later
	property alias tabBar: tabbar
	// Trigger cho thao tác user
	property bool triggerAddUser: false
	property bool triggerUpdateUser: false
	property bool triggerDeleteUser: false
	// Content root to be blurred when login overlay is visible
	Item {
		id: contentRoot
		anchors.fill: parent
		Rectangle {
			color: "white"
			anchors.fill: parent
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
						width: 90
						height: 30
						radius: 4
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
				// Thanh Tab và vùng nội dung theo Qt Quick Controls 2
				ColumnLayout {
					Layout.fillWidth: true
					Layout.fillHeight: true
					spacing: 6
					TabBar {
						id: tabbar
						Layout.fillWidth: true
						TabButton {
							text: "Tổng quan"
						}
						TabButton {
							text: "Người dùng"
						}
						TabButton {
							text: "Đăng kí"
						}
						TabButton {
							text: "Bảng giá"
						}
						TabButton {
							text: "Doanh thu"
						}
					}
					StackLayout {
						Layout.fillWidth: true
						Layout.fillHeight: true
						currentIndex: tabbar.currentIndex
						// Dashboard
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								// Cards
								RowLayout {
									Layout.fillWidth: true
									spacing: 10
									Rectangle {
										Layout.fillWidth: true
										height: 90
										radius: 8
										color: "#222"
										border.color: "#333"
										Column {
											anchors.centerIn: parent
											spacing: 4
											Text {
												text: "Tổng xe vào hôm nay"
												color: "#bbb"
											}
											Text {
												id: cardInToday
												text: "0"
												color: "white"
												font.pixelSize: 22
												font.bold: true
											}
										}
									}
									Rectangle {
										Layout.fillWidth: true
										height: 90
										radius: 8
										color: "#222"
										border.color: "#333"
										Column {
											anchors.centerIn: parent
											spacing: 4
											Text {
												text: "Tổng xe ra hôm nay"
												color: "#bbb"
											}
											Text {
												id: cardOutToday
												text: "0"
												color: "white"
												font.pixelSize: 22
												font.bold: true
											}
										}
									}
									Rectangle {
										Layout.fillWidth: true
										height: 90
										radius: 8
										color: "#222"
										border.color: "#333"
										Column {
											anchors.centerIn: parent
											spacing: 4
											Text {
												text: "Doanh thu hôm nay"
												color: "#bbb"
											}
											Text {
												id: cardRevenueToday
												text: "0 VNĐ"
												color: "#4ec9b0"
												font.pixelSize: 22
												font.bold: true
											}
										}
									}
								}
								// Charts placeholders
								RowLayout {
									Layout.fillWidth: true
									Layout.fillHeight: true
									spacing: 10
									Rectangle {
										Layout.fillWidth: true
										Layout.fillHeight: true
										radius: 8
										color: "#222"
										border.color: "#333"
										Text {
											anchors.centerIn: parent
											text: "Line chart: doanh thu theo ngày (placeholder)"
											color: "#777"
										}
									}
									Rectangle {
										Layout.fillWidth: true
										Layout.fillHeight: true
										radius: 8
										color: "#222"
										border.color: "#333"
										Text {
											anchors.centerIn: parent
											text: "Pie chart: vé tháng vs vé lượt (placeholder)"
											color: "#777"
										}
									}
								}
							}
						}
						// Users
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								// Form thêm/sửa
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextField {
										id: userName
										placeholderText: "Họ tên"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: userPhone
										placeholderText: "Số điện thoại"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 160
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: userRfid
										placeholderText: "ID thẻ"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: userPlate
										placeholderText: "Biển số"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									ComboBox {
										id: userVehicleType
										model: ["Xe máy", "Ô tô"]
										Layout.preferredWidth: 140
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
										}
									}
									Item {
										Layout.fillWidth: true
									}
								}
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextArea {
										id: userNote
										Layout.fillWidth: true
										height: 60
										color: "white"
										placeholderText: "Ghi chú"
										placeholderTextColor: "white"
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
								}
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Thêm"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerAddUser = true
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Cập nhật"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerUpdateUser = true
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#a33"
										Text {
											anchors.centerIn: parent
											text: "Xóa"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerDeleteUser = true
										}
									}
									Item {
										Layout.fillWidth: true
									}
								}
								// Bảng Users
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
										RowLayout {
											Layout.fillWidth: true
											spacing: 8
											Text {
												text: "ID"
												color: "white"
												Layout.preferredWidth: 60
											}
											Text {
												text: "Họ tên"
												color: "white"
												Layout.preferredWidth: 160
											}
											Text {
												text: "SĐT"
												color: "white"
												Layout.preferredWidth: 120
											}
											Text {
												text: "ID thẻ"
												color: "white"
												Layout.preferredWidth: 120
											}
											Text {
												text: "Biển số"
												color: "white"
												Layout.preferredWidth: 120
											}
											Text {
												text: "Loại xe"
												color: "white"
												Layout.preferredWidth: 100
											}
											Text {
												text: "Ghi chú"
												color: "white"
												Layout.preferredWidth: 200
											}
											Item {
												Layout.fillWidth: true
											}
										}
										ListView {
											Layout.fillWidth: true
											Layout.fillHeight: true
										}
									}
								}
							}
						}
						// Subscriptions
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								// Form đăng ký vé tháng
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									ComboBox {
										id: subUser
										model: ["Chọn user..."]
										Layout.preferredWidth: 200
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
										}
									}
									TextField {
										id: subPlate
										placeholderText: "Biển số"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: subRfid
										placeholderText: "ID thẻ"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									ComboBox {
										id: subPlan
										model: ["Tháng", "Quý", "Năm"]
										Layout.preferredWidth: 120
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
										}
									}
									TextField {
										id: subStart
										placeholderText: "Ngày bắt đầu (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: subEnd
										placeholderText: "Ngày kết thúc (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									ComboBox {
										id: subPayment
										model: ["Trả trước", "Trả sau"]
										Layout.preferredWidth: 120
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
										}
									}
									TextField {
										id: subPrice
										placeholderText: "Giá vé"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 120
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
								}
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Đăng ký mới"
											color: "white"
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Gia hạn"
											color: "white"
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#a33"
										Text {
											anchors.centerIn: parent
											text: "Xóa thẻ mất"
											color: "white"
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#777"
										Text {
											anchors.centerIn: parent
											text: "Hủy"
											color: "white"
										}
									}
									Item {
										Layout.fillWidth: true
									}
								}
								// Danh sách vé tháng
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
												Layout.preferredWidth: 80
											}
											Text {
												text: "Thanh toán"
												color: "white"
												Layout.preferredWidth: 100
											}
											Item {
												Layout.fillWidth: true
											}
										}
										ListView {
											Layout.fillWidth: true
											Layout.fillHeight: true
										}
									}
								}
							}
						}
						// Pricing
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							// Use logic component to manage data/state
							PricingLogic {
								id: pricingLogic
							}
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									ComboBox {
										id: pricingVehicle
										model: ["Xe máy", "Ô tô"]
										Layout.preferredWidth: 160
										Layout.preferredHeight: 24
										onCurrentIndexChanged: pricingLogic.selectedVehicle = (currentIndex === 0 ? "bike" : "car")
										Component.onCompleted: pricingLogic.selectedVehicle = (currentIndex === 0 ? "bike" : "car")
										background: Rectangle {
											radius: 8
										}
									}
									Item {
										Layout.fillWidth: true
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: pricingLogic.editMode ? "#777" : "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Chỉnh sửa"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											enabled: !pricingLogic.editMode
											onClicked: pricingLogic.editMode = true
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: pricingLogic.editMode ? "#2b7" : "#777"
										Text {
											anchors.centerIn: parent
											text: "Lưu"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											enabled: pricingLogic.editMode
											onClicked: pricingLogic.requestSave = true
										}
									}
								}

								Rectangle {
									Layout.fillWidth: true
									Layout.fillHeight: true
									radius: 8
									color: "#222"
									border.color: "#333"

									// Header
									RowLayout {
										id: pricingHeader
										anchors.left: parent.left
										anchors.right: parent.right
										anchors.top: parent.top
										anchors.margins: 8
										spacing: 8
										height: 28
										Text {
											text: "Loại Vé"
											color: "white"
											font.bold: true
											Layout.preferredWidth: 180
										}
										Text {
											text: "Mô Tả"
											color: "white"
											font.bold: true
											Layout.fillWidth: true
										}
										Text {
											text: "Giá (VND)"
											color: "white"
											font.bold: true
											Layout.preferredWidth: 160
										}
									}

									// Rows
									ListView {
										anchors.left: parent.left
										anchors.right: parent.right
										anchors.bottom: parent.bottom
										anchors.top: pricingHeader.bottom
										anchors.margins: 8
										model: pricingLogic.filteredModel
										clip: true
										delegate: Item {
											width: parent ? parent.width : 0
											// auto height based on content to avoid overlapping
											property int rowContentH: Math.max(
																		  lbl.implicitHeight,
																		  desc.implicitHeight,
																		  tfPriceValue.implicitHeight)
											height: rowContentH + 8
											RowLayout {
												anchors.fill: parent
												anchors.margins: 4
												spacing: 8
												Text {
													id: lbl
													text: ticket_label
													color: "white"
													Layout.preferredWidth: 180
													elide: Text.ElideRight
												}
												Text {
													id: desc
													text: description
													color: "#dddddd"
													Layout.fillWidth: true
													wrapMode: Text.Wrap
												}
												TextField {
													id: tfPriceValue
													text: price_value
													readOnly: !pricingLogic.editMode
													placeholderText: price_hint
													color: "black"
													placeholderTextColor: "#bbbbbb"
													Layout.preferredWidth: 160
													validator: IntValidator {
														bottom: 0
														top: 2000000000
													}
													background: Rectangle {
														color: tfPriceValue.readOnly ? "gray" : "white"
														radius: 6
														border.color: "#666666"
													}
												}

												Connections {
													target: tfPriceValue
													function onTextChanged() {
														if (pricingLogic.editMode)
															pricingLogic.setPriceFor(
																		ticket_type,
																		tfPriceValue.text)
													}
												}
											}
										}
									}
								}
							}
						}
						// Revenue
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								// Bộ lọc
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextField {
										id: revFrom
										placeholderText: "Từ ngày (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: revTo
										placeholderText: "Đến ngày (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									ComboBox {
										id: revType
										model: ["Tất cả", "Vé lượt", "Vé tháng"]
										Layout.preferredWidth: 160
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
										}
									}
									Item {
										Layout.fillWidth: true
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Lọc"
											color: "white"
										}
									}
								}
								// Bảng kết quả
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
										RowLayout {
											Layout.fillWidth: true
											spacing: 8
											Text {
												text: "Ngày"
												color: "white"
												Layout.preferredWidth: 140
											}
											Text {
												text: "Tổng lượt xe"
												color: "white"
												Layout.preferredWidth: 140
											}
											Text {
												text: "Tổng vé tháng"
												color: "white"
												Layout.preferredWidth: 140
											}
											Text {
												text: "Doanh thu (VNĐ)"
												color: "white"
												Layout.preferredWidth: 180
											}
											Item {
												Layout.fillWidth: true
											}
										}
										ListView {
											Layout.fillWidth: true
											Layout.fillHeight: true
										}
									}
								}
								// Thống kê tổng + Export
								RowLayout {
									Layout.fillWidth: true
									spacing: 12
									Text {
										text: "Tổng doanh thu: 0"
										color: "white"
									}
									Text {
										text: "Trong đó: vé lượt 0, vé tháng 0"
										color: "white"
									}
									Item {
										Layout.fillWidth: true
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Xuất CSV"
											color: "white"
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Xuất PDF"
											color: "white"
										}
									}
								}
							}
							// Save hook back to admin
							Connections {
								target: pricingLogic
								function onSaved(json) {
									try {
										console.log('[AdminPage] onSaved JSON length:',
													(json || '').length)
										const arr = JSON.parse(json)
										console.log('[AdminPage] rows to upsert:',
													Array.isArray(
														arr) ? arr.length : -1)
									} catch (e) {
										console.log('[AdminPage] JSON parse failed:',
													e)
									}
									pricingJson.text = json
									adminPage.triggerSavePricing = true
								}
							}
						}
					}
				}
			}
		}
	}

	// Full-screen login overlay (covers Admin page)
	// Hidden placeholders to satisfy alias bindings used by external logic
	Item {
		id: hiddenPricingAliasHolders
		visible: false
		width: 0
		height: 0
		// Aliased fields expected by other logic files
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
		// Hidden JSON text area for save payload
		TextArea {
			id: pricingJson
		}
	}

	// Full-screen login overlay (covers Admin page)
	Rectangle {
		id: loginOverlay
		anchors.fill: parent
		visible: adminPage.loginVisible
		z: 1000
		color: "#6f6f6f"
		// Center card
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
