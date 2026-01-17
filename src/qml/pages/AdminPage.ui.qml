import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts
import QtQuick.Dialogs
import "../logic"
import "../components"

Item {
	id: adminPage
	property bool triggerClose: false
	property bool triggerLogoutAndClose: false
	// Pricing triggers
	property bool triggerAddPricing: false
	property bool triggerSavePricing: false
	property bool triggerDeletePricing: false
	// Saving state for Pricing (used to show spinner on Save button)
	property bool pricingSaving: false
	property bool triggerEmployeeCheckIn: false
	property bool triggerEmployeeCheckOut: false
	// Pricing field aliases for logic
	property alias pricingBaseFee: pricingBaseFee
	property alias pricingGraceMinutes: pricingGraceMinutes
	property alias pricingIncEvery: pricingIncEvery
	property alias pricingIncFee: pricingIncFee
	property alias pricingCap: pricingCap
	// Expose hidden JSON buffer so AdminLogic can read it
	property alias pricingJson: pricingJson
	// Expose vehicle combobox to external logic (AdminPricingActions)
	property alias pricingVehicleCombo: pricingVehicle
	// Login overlay state and triggers
	property bool loginVisible: true
	property bool triggerLogin: false
	// Expose login UI controls to logic
	property alias loginUserField: tfLoginUser
	property alias loginPassField: tfLoginPass
	property alias loginErrorLabel: loginError
	// Expose form fields cho UsersLogic
	property alias userName: userName
	property alias userPhone: userPhone
	property alias userRfid: userRfid
	property alias userPlate: userPlate
	property alias userVehicleType: userVehicleType
	property alias userNote: userNote
	// Subscriptions new user text field alias
	//employee fields
	property alias tfEmployeeName: tfEmployeeName
	property alias tfEmployeeStaffId: tfEmployeeStaffId

	property alias taEmployeeNote: taEmployeeNote
	property alias cbEmployeeRole: cbEmployeeRole
	// Subscriptions form control aliases for logic access
	property alias subUserText: tfRfidName
	property alias subPlate: tfRfidPlate
	property alias subRfid: tfRfid
	property alias subPlan: tfSubPlan
	property alias subStart: tfSubStart
	property alias subEnd: tfSubEnd
	property alias subPayment: cbSubPayment
	property alias subPrice: tfSubPrice
	property alias subFilter: dummySubFilter
	property alias subPaymentMethod: cbSubPaymentMethod
	property alias subPlatePick: dummyPlatePick
	// Revenue summary aliases (labels in Revenue section)
	property alias revSummaryTotal: revSummaryTotal
	property alias revSummaryBreakdown: revSummaryBreakdown
	// Revenue filter field aliases for logic access
	property alias revFrom: revFrom
	property alias revTo: revTo
	property alias revType: revType
	// Expose minimal aliases for logic wiring later
	property var rfidLogic: null
	property var subsLogic: null
	property var usersLogic: null
	property var employeeLogic: null
	property alias tabBar: tabbar
	// Add these aliases to expose the RFID tab controls
	property alias rfidTextField: tfRfid
	property alias rfidVehicleCombo: cbVehicle
	property alias rfidTicketCombo: cbTicket
	property alias rfidStatusCombo: cbStatus
	// property alias rfidDescField: tfDesc
	property alias rfidNameField: tfRfidName
	property alias rfidPlateField: tfRfidPlate
	property alias rfidPhoneField: tfRfidPhone
	property alias rfidCardNumberField: tfRfidCardNumber
	// Trigger cho thao tác user
	property bool triggerAddUser: false
	property bool triggerUpdateUser: false
	property bool triggerDeleteUser: false
	// Triggers cho employee management
	property bool triggerAddEmployee: false
	property bool triggerUpdateEmployee: false
	property bool triggerDeleteEmployee: false
	// Employee check-in/out states (managed by EmployeeLogic)
	property bool canEmployeeCheckIn: false
	property bool canEmployeeCheckOut: false
	// Employee list model (managed by EmployeeLogic)
	property var employeeListModel: null
	// Subscription list model (managed by SubscriptionsLogic)
	property var subscriptionListModel: null
	// Triggers cho subscriptions
	property bool triggerSubCreate: false
	property bool triggerSubExtend: false
	property bool triggerSubLostDelete: false
	property bool triggerSubCancel: false
	property bool triggerSubFilterChanged: false
	property bool triggerExportExpired: false
	property bool triggerSubUserTextChanged: false
	property bool triggerSubCancelExtend: false
	property bool triggerSubUpdate: false
	property bool triggerSubsChanged: false
	property bool triggerSubsSaveDialogAccepted: false
	// buffer for generated expired CSV
	property string expiredCsvBuffer: ""
	property bool triggerUsersChanged: false
	// Row selection via index (single-expression onClicked)
	property int pendingSelectUserIndex: -1
	property int pendingSelectSubIndex: -1
	property int pendingSelectRfidIndex: -1
	property int pendingSelectEmployeeIndex: -1
	// Revenue date-picker integration (SearchPage-style for Revenue tab)
	property bool revFromPickerVisible: false
	property bool revToPickerVisible: false
	property bool triggerRevFromSelect: false
	property bool triggerRevToSelect: false
	property bool triggerRevenueFilter: false
	property bool triggerOpenImage: false
	// Triggers for exporting files
	// property bool triggerExportCsv: false
	// property bool triggerExportPdf: false
	property bool triggerExportExcel: false
	// Expose inner ComboBoxes to logic via aliases
	property alias revFromYear: revFromDatePopup.fromYear
	property alias revFromMonth: revFromDatePopup.fromMonth
	property alias revFromDay: revFromDatePopup.fromDay
	property alias revToYear: revToDatePopup.toYear
	property alias revToMonth: revToDatePopup.toMonth
	property alias revToDay: revToDatePopup.toDay
	// Expose save dialogs for logic modules
	property alias fileSaveDialog: revenueSaveDialog
	property alias subsFileSaveDialog: subsSaveDialog
	property alias imageOpenDialog: imageOpenDialog

	ComboBox { id: dummySubFilter; visible: false }

	ComboBox { id: dummyPlatePick; visible: false }

	// Logic instances
	ToastComponent {
		id: toastOverlay
	}
	NotifyLogic {
		id: notifyLogic
		toast: toastOverlay
	}
	// UsersLogic {
	//	 id: usersLogic
	// 	 adminPage: adminPage
	//	 notify: notifyLogic.push
	// }
	// SubscriptionsLogic {
	//	 id: subsLogic
	//	 adminPage: adminPage
	//	 notify: notifyLogic.push
	// }
	DashboardLogic {
		id: dashboardLogic
		adminPage: adminPage
		notify: notifyLogic.push
	}
	RevenueLogic {
		id: revenueLogic
		adminPage: adminPage
		notify: notifyLogic.push
	}
	Binding {
		target: rfidLogic
		property: "tfCardNumber"
		value: adminPage.rfidCardNumberField
		when: rfidLogic !== null
	}
	Binding {
			target: rfidLogic
			property: "tfName"
			value: tfRfidName
			when: rfidLogic !== null
	}

	Binding {
		target: rfidLogic
		property: "tfPlate"
		value: tfRfidPlate
		when: rfidLogic !== null
	}
	Binding {
		target: rfidLogic
		property: "tfPhone" // <--- Bind property
		value: adminPage.rfidPhoneField // Bind to alias
		when: rfidLogic !== null
	}
	// File save dialogs for exports
	FileDialog {
		id: revenueSaveDialog
		title: "Chọn nơi lưu file Excel"
		nameFilters: ["Excel files (*.xlsx)", "All files (*.*)"] // Changed filter
		onAccepted: adminPage.triggerExportExcel = !adminPage.triggerExportExcel
	}

	FileDialog {
		id: imageOpenDialog
		title: "Chọn ảnh để tải lên"
		nameFilters: ["Image files (*.png *.jpg *.jpeg)", "All files (*.*)"]
		onAccepted:
				uploadedImageViewer.source = imageOpenDialog.selectedFile
		}

	FileDialog {
		id: subsSaveDialog
		title: "Chọn nơi lưu CSV Đăng ký"
		nameFilters: ["CSV files (*.csv)", "All files (*.*)"]
		onAccepted: adminPage.triggerSubsSaveDialogAccepted = !adminPage.triggerSubsSaveDialogAccepted
	}
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
							onClicked: adminPage.triggerLogoutAndClose
									   = !adminPage.triggerLogoutAndClose
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
							text: "Bảng giá"
						}
						TabButton {
							text: "Quản lý thẻ"
						}
						TabButton {
							text: "Người dùng"
							visible: false   // Makes it invisible
							enabled: false   // Prevents clicking
							width: 0         // Ensures it takes up no space in the bar
							height: 0
						}
						TabButton {
							text: "Đăng kí"
							visible: false
							enabled: false
							width: 0
							height: 0
						}
						TabButton{
							text: "Quản lý nhân viên"
						}
						TabButton {
							text: "Doanh thu"
						}
					}
					Connections {
						// When switching tabs, clear all forms
						target: tabbar
						function onCurrentIndexChanged() {
						if (rfidTextField) rfidTextField.text = ""
						if (rfidVehicleCombo) rfidVehicleCombo.currentIndex = 0
						if (rfidTicketCombo) rfidTicketCombo.currentIndex = 0
						if (rfidDescField) rfidDescField.text = ""
						if (tfRfidName) tfRfidName.text = ""
						if (tfRfidPlate) tfRfidPlate.text = ""
						if (tfRfidPhone) tfRfidPhone.text = ""
						pendingSelectRfidIndex = -1 // Clear list selection
						// --- Users Tab (Index 3) ---
						if (userName) userName.text = ""
						if (userPhone) userPhone.text = ""
						if (userRfid) userRfid.text = ""
						if (userPlate) userPlate.text = ""
						if (userVehicleType) userVehicleType.text = ""
						if (userNote) userNote.text = ""
						if (usersLogic) usersLogic.selectedUserId = -1 // Reset logic state
						pendingSelectUserIndex = -1 // Clear list selection
						// --- Subscriptions Tab (Index 4) ---
						if (subUserText) subUserText.text = ""
						if (subPlate) subPlate.text = ""
						if (subRfid) subRfid.text = ""
						if (subPlan) subPlan.text = ""
						if (subStart) subStart.text = ""
						if (subEnd) subEnd.text = ""
						if (subPayment) subPayment.currentIndex = 0
						if (subPaymentMethod) subPaymentMethod.currentIndex = 0
						if (subPrice) subPrice.text = ""
						if (subsLogic) subsLogic.selectedSubId = -1 // Reset logic state
						pendingSelectSubIndex = -1 // Clear list selection
						if (uploadedImageViewer) uploadedImageViewer.source = ""
						// --- Employee Tab (Index 5) ---
						if (tfEmployeeName) tfEmployeeName.text = ""
						if (tfEmployeeStaffId) tfEmployeeStaffId.text = ""
						if (taEmployeeNote) taEmployeeNote.text = ""
						if (cbEmployeeRole) cbEmployeeRole.currentIndex = 0
						pendingSelectEmployeeIndex = -1 // Clear list selection
						// Reset check-in/out button states
						canEmployeeCheckIn = false
						canEmployeeCheckOut = false
						// --- Revenue Tab (Index 6) ---
						if (revFrom) revFrom.text = ""
						if (revTo) revTo.text = ""
						if (revType) revType.currentIndex = 0
						// --- Pricing Tab (Index 1) ---
						if (pricingVehicle) pricingVehicle.currentIndex = 0
						// --- END: Clear all form fields ---
						// --- Keep existing logic for Revenue tab ---
						if (tabbar.currentIndex === 6) {
							adminPage.triggerRevenueFilter = !adminPage.triggerRevenueFilter;
								}
						}
					}
					Connections {
					// When switching tabs, clear all forms
						target: tabbar
						function onCurrentIndexChanged() {
						adminPage.clearAllTabForms()
						if (tabbar.currentIndex === 6) {
							adminPage.triggerRevenueFilter = !adminPage.triggerRevenueFilter;
							}
						}
					}
					Connections {
						target: dailyRevenueRangePicker // The ID of your new ComboBox
						function onCurrentIndexChanged() {
							if (dashboardLogic && dashboardLogic.updateDailyChartRange) {
								// Call the logic function when the index changes
								dashboardLogic.updateDailyChartRange(dailyRevenueRangePicker.currentIndex)
							}
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
							border.color: "darkgray"
							// Defer chart refresh calls to a legal context for .ui.qml
							Connections {
								target: dashboardLogic
								function onReady() {
									if (dashboardLogic && dashboardLogic.refreshDailyChart)
										dashboardLogic.refreshDailyChart(dSeries, dAxisX, dAxisY, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
									if (dashboardLogic && dashboardLogic.refreshBreakdownPie)
										dashboardLogic.refreshBreakdownPie(pie, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
									if (dashboardLogic && dashboardLogic.refreshByTicketBar)
										dashboardLogic.refreshByTicketBar(ticketBar, ticketAxisX, ticketAxisY, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
								}

								function onRefreshCharts() {
									if (dashboardLogic && dashboardLogic.refreshDailyChart)
										dashboardLogic.refreshDailyChart(dSeries, dAxisX, dAxisY, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
									if (dashboardLogic && dashboardLogic.refreshBreakdownPie)
										dashboardLogic.refreshBreakdownPie(pie, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
									if (dashboardLogic && dashboardLogic.refreshByTicketBar)
										dashboardLogic.refreshByTicketBar(ticketBar, ticketAxisX, ticketAxisY, dashboardLogic.defaultFrom && dashboardLogic.defaultFrom(), dashboardLogic.todayIso())
								}
							}
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
												text: dashboardLogic.inToday
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
												text: dashboardLogic.outToday
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
												text: dashboardLogic.revenueToday + " VNĐ"
												color: "#4ec9b0"
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
												text: "Vé tháng hết hạn"
												color: "#bbb"
											}
											Text {
												id: cardExpiredSubs
												text: dashboardLogic.expiredSubs
												color: "#e53935"
												font.pixelSize: 22
												font.bold: true
											}
										}
									}
								}
								// Charts
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
										ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 6
											RowLayout {
												Layout.fillWidth: true

												Text {
													text: "Doanh thu theo ngày (nghìn VNĐ)"
													color: "white"
													font.bold: true
													Layout.fillWidth: true
												}

												ComboBox {
													id: dailyRevenueRangePicker
													Layout.preferredWidth: 120
													model: ["7 ngày", "30 ngày", "90 ngày"]
													currentIndex: 1
												}
											}
											ChartView {
												id: chartRevenueDaily
												Layout.fillWidth: true
												Layout.fillHeight: true
												antialiasing: true
												theme: ChartView.ChartThemeDark
												visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 0) && !adminPage.loginVisible
												legend.visible: false
												ValueAxis { id: dAxisY; min: 0; labelFormat: "%.0f K" }
												DateTimeAxis { id: dAxisX; format: "dd/MM"; tickCount: 8 }
												LineSeries { id: dSeries; axisY: dAxisY; axisX: dAxisX; color: "#4ec9b0"; pointLabelsVisible: false; useOpenGL: false }
											}
										}
									}
									Rectangle {
										Layout.fillWidth: true
										Layout.fillHeight: true
										radius: 8
										color: "#222"
										border.color: "#333"
										ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 6
											Text { text: "Cơ cấu doanh thu"; color: "white"; font.bold: true }
											ChartView {
												id: chartBreakdown
												Layout.fillWidth: true
												Layout.fillHeight: true
												antialiasing: true
												theme: ChartView.ChartThemeDark
												visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 0) && !adminPage.loginVisible
												legend.visible: true
												PieSeries { id: pie; holeSize: 0.35 }
											}
											Rectangle {
												Layout.fillWidth: true
												Layout.fillHeight: true
												radius: 8
												color: "#222"
												border.color: "#333"
												ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 6
													Text { text: "Doanh thu theo loại vé (nghìn VNĐ)"; color: "white"; font.bold: true }
													ChartView {
														id: chartByTicket
														Layout.fillWidth: true
														Layout.fillHeight: true
														antialiasing: true
														theme: ChartView.ChartThemeDark
														visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 0) && !adminPage.loginVisible
														legend.visible: false
														BarSeries { id: ticketBar; axisX: ticketAxisX; axisY: ticketAxisY; barWidth: 0.6 }
														BarCategoryAxis { id: ticketAxisX }
														ValueAxis { id: ticketAxisY; min: 0; labelFormat: "%.0f K" }
													}
												}
											}
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
							border.color: "darkgray"
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
											color: "#111"
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
										color: (pricingLogic.editMode && !adminPage.pricingSaving) ? "#2b7" : "#777"
										Row {
											anchors.centerIn: parent
											spacing: 6
											BusyIndicator {
												running: adminPage.pricingSaving
												visible: adminPage.pricingSaving
												width: 16; height: 16
											}
											Text {
												text: "Lưu"
												color: "white"
											}
										}
										MouseArea {
											anchors.fill: parent
											enabled: pricingLogic.editMode && !adminPage.pricingSaving
											onClicked: pricingLogic.requestSave
													   = !pricingLogic.requestSave
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
												text: "Bắt đầu"
												color: "white"
												font.bold: true
												Layout.preferredWidth: 80
											}
											Text {
												text: "Kết thúc"
												color: "white"
												font.bold: true
												Layout.preferredWidth: 80
											}
										Text {
											text: "Giá (VND)"
											color: "white"
											font.bold: true
											Layout.preferredWidth: 160
										}
										Text {
											text: "Miễn phí (phút)"
											color: "white"
											font.bold: true
											Layout.preferredWidth: 140
										}
									}

									// Rows
									ListView {
										visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 1) && !adminPage.loginVisible
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
													font.pixelSize: 13
												}
												Text {
													id: desc
													text: description
													color: "#dddddd"
													Layout.fillWidth: true
													wrapMode: Text.Wrap
													lineHeight: 1.2
												}
												TextField {
														id: tfStartTime
														text: start_value
														readOnly: !pricingLogic.editMode || !is_time_editable
														enabled: is_time_editable
														placeholderText: "HH:mm"
														color: "black"
														placeholderTextColor: "#bbbbbb"
														Layout.preferredWidth: 80
														horizontalAlignment: TextInput.AlignHCenter

														// Validate time format HH:mm
														validator: RegularExpressionValidator { regularExpression: /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/ }

														background: Rectangle {
															color: tfStartTime.readOnly ? "gray" : "white"
															radius: 6
															border.color: "#666666"
														}
													}

												Connections {
														target: tfStartTime
														function onTextChanged() {
															pricingLogic.onTimeChanged(ticket_type, true, tfStartTime.text)
														}
													}

													// [CHANGE] End Time Input
													TextField {
														id: tfEndTime
														text: end_value
														readOnly: !pricingLogic.editMode || !is_time_editable
														enabled: is_time_editable
														placeholderText: "HH:mm"
														color: "black"
														placeholderTextColor: "#bbbbbb"
														Layout.preferredWidth: 80
														horizontalAlignment: TextInput.AlignHCenter

														validator: RegularExpressionValidator { regularExpression: /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/ }

														background: Rectangle {
															color: tfEndTime.readOnly ? "gray" : "white"
															radius: 6
															border.color: "#666666"
														}
													}

													Connections {
															target: tfEndTime
															function onTextChanged() {
																pricingLogic.onTimeChanged(ticket_type, false, tfEndTime.text)
															}
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
														pricingLogic.onPriceFieldChanged(ticket_type, tfPriceValue.text)
													}
												}
												TextField {
													id: tfGraceValue
													text: grace_value
													readOnly: !pricingLogic.editMode || grace_hint === "-"
													enabled: grace_hint !== "-"
													placeholderText: grace_hint
													color: "black"
													placeholderTextColor: "#bbbbbb"
													Layout.preferredWidth: 140
													validator: IntValidator {
														bottom: 0
														top: 1000
													}
													background: Rectangle {
														color: tfGraceValue.readOnly ? "gray" : "white"
														radius: 6
														border.color: "#666666"
													}
												}

												Connections {
													target: tfGraceValue
													function onTextChanged() {
														pricingLogic.onGraceFieldChanged(ticket_type, tfGraceValue.text)
													}
												}
											}
										}
									}
								}
							}
						}
						// RFID Cards
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							border.color: "darkgray"
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 8
								RowLayout {
									Layout.fillWidth: true
									spacing: 8
									TextField {
										id: tfRfidCardNumber
										Layout.preferredWidth: 120
										placeholderText: "Số thẻ"
										color: "white"
										placeholderTextColor: "#ccc"
										background: Rectangle {
											color: '#222'
											radius: 8
											border.color: '#555'
										}
									}
									TextField {
										id: tfRfid
										Layout.preferredWidth: 180
										placeholderText: "Quét/nhập RFID"
										color: "white"
										placeholderTextColor: "white"
										background: Rectangle {
											color: '#222'
											radius: 8
											border.color: '#555'
										}
									}
									ComboBox {
										id: cbVehicle
										Layout.preferredWidth: 140
										Layout.preferredHeight: 24
										// OLD: model: ["Xe máy", "Ô tô"]
										// NEW: Add "Tất cả" at index 0
										model: ["Tất cả", "Xe máy", "Ô tô"]
										background: Rectangle {
											radius: 8
											color: "#111"
										}
									}
									ComboBox {
										id: cbTicket
										Layout.preferredWidth: 160
										Layout.preferredHeight: 24
										model: ["Tất cả","Giờ", "Ca Sáng", "Ca Chiều", "Ca Tối", "Ngày (ban ngày)", "Ngày (ban đêm)", "Qua đêm",  "Tháng", "Quý", "Năm"]
										background: Rectangle {
											radius: 8
											color: "#111"
										}
									}
									ComboBox {
										id: cbStatus
										Layout.preferredWidth: 0
										Layout.preferredHeight: 0
										visible: false
										enabled: false
										model: ["available", "assigned", "lost", "damaged"]
										currentIndex: 0
									}
									Item {Layout.fillWidth: true}
								}
								RowLayout{
									Layout.fillWidth: true
									spacing: 10

									TextField{
										id: tfRfidName
										Layout.preferredWidth: 180
										placeholderText: "Họ và tên"
										color: "white"
										placeholderTextColor: "#ccc"
										background: Rectangle{color: "#222"; radius: 8; border.color: "#555" }
									}
									TextField{
										id: tfRfidPhone
										Layout.preferredWidth: 140
										placeholderText: "SĐT"
										color: "white"
										placeholderTextColor: "#ccc"
										background: Rectangle { color: '#222'; radius: 8; border.color: '#555' }
									}
									TextField{
										id: tfRfidPlate
										Layout.preferredWidth: 140
										placeholderText: "Biển số"
										color: "white"
										placeholderTextColor: "#ccc"
										background: Rectangle { color: '#222'; radius: 8; border.color: '#555' }
									}

									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#555" // Grey color for reset
										Text {
											anchors.centerIn: parent
											text: "Đặt lại bộ lọc" // Reset Filter
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: rfidLogic.resetFilters()
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										visible: cbTicket.currentIndex < 8
										Text {
											anchors.centerIn: parent
											text: "Lưu"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: rfidLogic.triggerSave
													   = !rfidLogic.triggerSave
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#c62828"
										Text {
											anchors.centerIn: parent
											text: "Xóa thẻ"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: rfidLogic.triggerDelete
													   = !rfidLogic.triggerDelete
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#ff9800"
										Text {
											anchors.centerIn: parent
											text: "Mất"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: rfidLogic.triggerMarkLost
													   = !rfidLogic.triggerMarkLost
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#b71c1c"
										Text {
											anchors.centerIn: parent
											text: "Hỏng"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: rfidLogic.triggerMarkDamaged
													   = !rfidLogic.triggerMarkDamaged
										}
									}
								}
								Rectangle {
									Layout.fillWidth: true
									Layout.preferredHeight: 75
									color: "#333"
									radius: 8
									visible: cbTicket.currentIndex >= 8 // Indexes 8,9,10 are Monthly/Quarterly/Yearly
									ColumnLayout {
										anchors.fill: parent
										anchors.margins: 8
										spacing: 4
										Text { text: "Thông tin Gia hạn / Đăng ký Vé Tháng"; color: "#4ec9b0"; font.bold: true; font.pixelSize: 12 }
										RowLayout {
											Layout.fillWidth: true
											spacing: 8
											TextField {
												id: tfSubPlan
												placeholderText: "Loại"
												readOnly: true
												Layout.preferredWidth: 80
												color: "white"
												background: Rectangle { color: "#555"; radius: 6 }
											}
											TextField {
												id: tfSubStart
												placeholderText: "Ngày BĐ (YYYY-MM-DD)"
												Layout.preferredWidth: 160
												color: "white"
												background: Rectangle { color: "#222"; radius: 6; border.color: "#666" }
											}
											Text { text: "→"; color: "white" }
											TextField {
												id: tfSubEnd
												placeholderText: "Ngày KT (YYYY-MM-DD)"
												Layout.preferredWidth: 160
												color: "white"
												background: Rectangle { color: "#222"; radius: 6; border.color: "#666" }
											}
											TextField {
												id: tfSubPrice
												placeholderText: "Giá tiền"
												Layout.preferredWidth: 120
												color: "white"
												readOnly: false
												background: Rectangle { color: "#222"; radius: 6; border.color: "#666" }
											}
											ComboBox {
												id: cbSubPayment
												model: ["Trả trước", "Trả sau"]
												Layout.preferredWidth: 100
											}
											ComboBox {
												id: cbSubPaymentMethod
												model: ["Tiền mặt", "Chuyển khoản"]
												Layout.preferredWidth: 110
											}
											// Subscription Actions
											Rectangle {
												width: 90; height: 28; radius: 6; color: "#2196f3" // Blue
												Text { anchors.centerIn: parent; text: "Đăng ký"; color: "white" }
												MouseArea { anchors.fill: parent; onClicked: adminPage.triggerSubCreate = !adminPage.triggerSubCreate }
											}
											Rectangle {
												width: 90; height: 28; radius: 6; color: "#ff9800" // Orange
												Text { anchors.centerIn: parent; text: "Gia hạn"; color: "white" }
												MouseArea { anchors.fill: parent; onClicked: adminPage.triggerSubExtend = !adminPage.triggerSubExtend }
											}
											Rectangle {
												width: 90; height: 28; radius: 6; color: "#ffc107" // Amber/Gold color
												Text {
													anchors.centerIn: parent;
													text: "Cập nhật";
													color: "black";
													font.pixelSize: 12
												}
												MouseArea {
													anchors.fill: parent;
													onClicked: adminPage.triggerSubUpdate = !adminPage.triggerSubUpdate
												}
											}
										}
									}
								}
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

											MouseArea {
												Layout.preferredWidth: 120
												Layout.preferredHeight: 30
												cursorShape: Qt.PointingHandCursor
												//onClicked: rfidLogic.handleSort("card_number")

												RowLayout {
													anchors.fill: parent
													spacing: 8
													Text {
														text: "Số thẻ"
														color: "white"
														font.bold: true
													}
												}
											}

											// 1. Column: Họ tên
												MouseArea {
													Layout.preferredWidth: 140
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													// Calls the logic function directly (Allowed in .ui.qml)
													//onClicked: rfidLogic.handleSort("owner_name")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Họ tên"
															color: "white"
															font.bold: true
														}
													}
												}

												// 2. Column: Biển số
												MouseArea {
													Layout.preferredWidth: 120
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("plate")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Biển số"
															color: "white"
															font.bold: true
														}
													}
												}

												// 3. Column: RFID
												MouseArea {
													Layout.preferredWidth: 160
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("rfid")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "RFID"
															color: "white"
															font.bold: true
														}
													}
												}

												// 4. Column: Loại xe
												MouseArea {
													Layout.preferredWidth: 100
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("vehicle_type")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Loại xe"
															color: "white"
															font.bold: true
														}
													}
												}

												// 5. Column: Loại vé
												MouseArea {
													Layout.preferredWidth: 140
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("ticket_type")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Loại vé"
															color: "white"
															font.bold: true
														}
													}
												}

												// 6. Column: Số điện thoại
												MouseArea {
													Layout.preferredWidth: 120
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("owner_phone")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Số điện thoại"
															color: "white"
															font.bold: true
														}
													}
												}

												// 7. Column: Trạng thái
												MouseArea {
													Layout.preferredWidth: 120
													Layout.preferredHeight: 30
													cursorShape: Qt.PointingHandCursor
													//onClicked: rfidLogic.handleSort("status")

													RowLayout {
														anchors.fill: parent
														spacing: 4
														Text {
															text: "Trạng thái"
															color: "white"
															font.bold: true
														}
													}
												}

												Text {
													text: "Gán lúc"
													color: "white"
													Layout.preferredWidth: 160
													font.bold: true
												}
											}
										ListView {
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 2) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: rfidLogic ? rfidLogic.listModel : null
											clip: true
											delegate: Rectangle {
												color: (adminPage.pendingSelectRfidIndex === index) ? "#334455" : ((tfRfid && rfid === tfRfid.text) ? "#4ec9b0" : "transparent")
												border.color: "#555"
												border.width: 1
												width: ListView.view ? ListView.view.width : 0
												height: 30
												RowLayout {
													anchors.fill: parent
													spacing: 8

													Text {
														text: (typeof card_number === "undefined" || card_number === null) ? "" : card_number
														color: "white"
														Layout.preferredWidth: 120
														elide: Text.ElideRight
													}

													Text {
														// Check if full_name exists, otherwise show empty string
														text: (typeof owner_name === "undefined" || owner_name === null) ? "" : owner_name
														color: "white"
														Layout.preferredWidth: 140
														elide: Text.ElideRight
													}
													Text {
														// Check if plate exists, otherwise show empty string
														text: (typeof plate === "undefined" || plate === null) ? "" : plate
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: rfid
														color: "white"
														Layout.preferredWidth: 160
														elide: Text.ElideRight
													}
													Text {
														text: vehicle_type === 'car' ? "Ô tô" : (vehicle_type === 'bike' ? "Xe máy" : vehicle_type)
														color: "white"
														Layout.preferredWidth: 100
													}
													Text {
														text:	ticket_type === 'hourly' ? "Vé lượt" :
																ticket_type === 'daily_day' ? "Ngày (Sáng)" :
																ticket_type === 'daily_night' ? "Ngày (Tối)" :
																ticket_type === 'overnight' ? "Qua đêm" :
																ticket_type === 'monthly' ? "Tháng" :
																ticket_type === 'quarterly' ? "Quý" :
																ticket_type === 'yearly' ? "Năm" :
																ticket_type === 'morning' ? "Ca Sáng" :
																ticket_type === 'afternoon' ? "Ca Chiều" :
																ticket_type === 'evening' ? "Ca Tối" :
																ticket_type

														color: "white"
														Layout.preferredWidth: 140
													}
													Text {
														text: (typeof owner_phone === "undefined" || owner_phone === null) ? "" : owner_phone
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: status === 'available' ? "Sẵn dùng" :
																  status === 'assigned' ? "Đã gán" :
																  status === 'lost' ? "Mất" :
																  status === 'damaged' ? "Hỏng" :
																  status
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: (assigned_at
															   || '')
														color: "white"
														Layout.preferredWidth: 160
													}
													Item {
																Layout.fillWidth: true
															}
												}
												MouseArea {
													anchors.fill: parent
													onClicked: adminPage.pendingSelectRfidIndex
															   = index
												}
											}
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
							border.color: "darkgray"
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
									// ComboBox {
									// 	id: userVehicleType
									// 	model: ["Xe máy", "Ô tô"]
									// 	Layout.preferredWidth: 140
									// 	Layout.preferredHeight: 24
									// 	background: Rectangle {
									// 		radius: 8
									// 	}
									// }
									TextField {
										id: userVehicleType
										placeholderText: "Loại xe"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#999"
											border.color: "#555"
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
											onClicked: adminPage.triggerAddUser
													   = !adminPage.triggerAddUser
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
											onClicked: adminPage.triggerUpdateUser
													   = !adminPage.triggerUpdateUser
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
											onClicked: adminPage.triggerDeleteUser
													   = !adminPage.triggerDeleteUser
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
											id: usersListView
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 3) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: usersLogic ? usersLogic.listModel : null
											clip: true
											delegate: Rectangle {
												color: (usersLogic
														&& usersLogic.selectedUserId
														=== id) ? "#334455" : "transparent"
												border.color: "#444"
												border.width: 1
												width: ListView.view ? ListView.view.width : 0
												height: 28
												RowLayout {
													anchors.fill: parent
													spacing: 8
													Text {
														text: (index + 1)
														color: "white"
														Layout.preferredWidth: 50
													}
													// Text {
													// 	text: id
													// 	color: "#888"
													// 	Layout.preferredWidth: 60
													// }
													Text {
														text: full_name
														color: "white"
														Layout.preferredWidth: 160
														elide: Text.ElideRight
													}
													Text {
														text: phone
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: rfid
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: plate
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: vehicle_type
														color: "white"
														Layout.preferredWidth: 100
													}
													Text {
														text: status
														color: status === 'inactive' ? '#ff9800' : '#ccc'
														Layout.preferredWidth: 80
													}
													Item {
														Layout.fillWidth: true
													}
												}
												MouseArea {
													anchors.fill: parent
													onClicked: adminPage.pendingSelectUserIndex
															   = index
												}
											}
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
							border.color: "darkgray"
							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10
								// Form đăng ký vé tháng
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextField {
										id: subUserText
										placeholderText: "Nhập tên user"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 220
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
										onTextChanged: adminPage.triggerSubUserTextChanged
													   = !adminPage.triggerSubUserTextChanged
									}
									TextField {
										id: subPlate
										placeholderText: "Biển số"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#999"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: subRfid
										placeholderText: "ID thẻ"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#999"
											border.color: "#555"
											radius: 8
										}
									}
									ComboBox {
										id: subPlatePick
										visible: subsLogic
												 && subsLogic.dupPlates
												 && subsLogic.dupPlates.length > 1
										Layout.preferredWidth: 160
										Layout.preferredHeight: 24
										model: subsLogic ? subsLogic.dupPlates : []
										background: Rectangle {
											radius: 8
										}
										onCurrentIndexChanged: adminPage.triggerSubUserTextChanged = !adminPage.triggerSubUserTextChanged
									}

									Text {
										visible: subPlatePick.visible && subPlatePick.currentIndex < 0
										text: "← Chọn biển số"
										color: "#ffeb3b"
										font.pixelSize: 12
										verticalAlignment: Text.AlignVCenter
									}
									TextField {
										id: subPlan
										placeholderText: "Loại thẻ"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 140
										background: Rectangle {
											color: "#999"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: subStart
										placeholderText: "Ngày bắt đầu (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#999"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: subEnd
										placeholderText: "Ngày kết thúc (YYYY-MM-DD)"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 180
										background: Rectangle {
											color: "#999"
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
											color: "#111"
										}
									}
									ComboBox {
										id: subPaymentMethod // New ID
										model: ["Tiền mặt", "Chuyển khoản"] // Your requested options
										Layout.preferredWidth: 140
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
											color: "#111"
										}
									}
									TextField {
										id: subPrice
										placeholderText: "Giá vé"
										placeholderTextColor: "white"
										color: "white"
										readOnly: true
										Layout.preferredWidth: 120
										background: Rectangle {
											color: "#999"
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
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerSubCreate = !adminPage.triggerSubCreate
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
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerSubExtend
													   = !adminPage.triggerSubExtend
										}
									}
									Rectangle { // <-- ADDED BLOCK
										width: 110
										height: 28
										radius: 8
										color: "#ffc107" // Amber
										Text {
											anchors.centerIn: parent
											text: "Cập nhật"
											color: "black"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerSubUpdate = !adminPage.triggerSubUpdate
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#007bff" // Blue color for distinction
										Text {
											anchors.centerIn: parent
											text: "Tải ảnh lên"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerOpenImage = !adminPage.triggerOpenImage
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#ff9800"
										Text {
											anchors.centerIn: parent
											text: "Hủy gia hạn"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerSubCancelExtend
													   = !adminPage.triggerSubCancelExtend
										}
									}
									Item {
										Layout.fillWidth: true
									}
								}
								Item {
									id: imageContainer
									Layout.alignment: Qt.AlignHCenter
									Layout.preferredHeight: uploadedImageViewer.source ? 500 : 0
									Layout.preferredWidth: uploadedImageViewer.source ? uploadedImageViewer.width : 0
									visible: uploadedImageViewer.source && uploadedImageViewer.source.toString().length > 0
								Image {
									id: uploadedImageViewer
									source: "" // Initially empty
									height: imageContainer.Layout.preferredHeight
									fillMode: Image.PreserveAspectFit
									visible: uploadedImageViewer.source
								}
								Rectangle { // Close button
									width: 24
									height: 24
									radius: 12
									color: "#222"
									anchors.top: parent.top
									anchors.right: parent.right
									anchors.margins: 8
									visible: uploadedImageViewer.source
									Text {
										text: "×"
										color: "white"
										font.pixelSize: 18
										font.bold: true
										anchors.centerIn: parent
									}
									MouseArea {
										anchors.fill: parent
										onClicked: uploadedImageViewer.source = ""
									}
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
											// filter + export controls
											Layout.fillWidth: true
											spacing: 8
											ComboBox {
												id: subFilter
												model: ["Tất cả", "Hết hạn", "Đang hoạt động"]
												Layout.preferredWidth: 160
												onCurrentIndexChanged: adminPage.triggerSubFilterChanged = !adminPage.triggerSubFilterChanged
											}
											Rectangle {
												width: 130
												height: 28
												radius: 8
												color: "#2b7"
												Text {
													anchors.centerIn: parent
													text: "Xuất CSV Hết hạn"
													color: 'white'
													wrapMode: Text.Wrap
													horizontalAlignment: Text.AlignHCenter
												}
												MouseArea {
													anchors.fill: parent
													onClicked: adminPage.triggerExportExpired
															   = !adminPage.triggerExportExpired
												}
											}
											Item {
												Layout.fillWidth: true
											}
										}
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
												text: "Loại vé"
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
											Text {
												text: "Hình thức thanh toán"
												color: "white"
												Layout.preferredWidth: 120
											}

											Item {
												Layout.fillWidth: true
											}
										}
										ListView {
											id: subsListView
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 4) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: adminPage.subscriptionListModel
											clip: true
											delegate: Rectangle {
												color: (subsLogic
														&& subsLogic.selectedSubId
														=== id) ? "#344" : "transparent"
												border.color: "#555"
												border.width: 1
												width: ListView.view ? ListView.view.width : 0
												height: 30
												RowLayout {
													anchors.fill: parent
													spacing: 8
													Text {
														text: (index + 1)
														color: "white"
														Layout.preferredWidth: 50
													}
													// Text {
													// 	text: id
													// 	color: "#888"
													// 	Layout.preferredWidth: 60
													// }
													Text {
														text: full_name
														color: "white"
														Layout.preferredWidth: 160
														elide: Text.ElideRight
													}
													Text {
														text: plate
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: rfid
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														// Use nested ternary operators instead of a JS block
														text: plan_type === 'monthly' ? "Tháng" :
															  (plan_type === 'quarterly' ? "Quý" :
															  (plan_type === 'yearly' ? "Năm" : plan_type))

														color: "white"
														Layout.preferredWidth: 120 // Make sure this matches the header width
													}
													Text {
														text: start_date
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: end_date
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: status
														color: status === 'canceled' ? '#ff9800' : (status === 'expired' ? '#e53935' : '#cfd8dc')
														Layout.preferredWidth: 90
													}
													Text {
														text: payment_mode
														color: "white"
														Layout.preferredWidth: 90
													}
													Text {
														text: payment_method
														color: "white"
														Layout.preferredWidth: 90
													}
													Item {
														Layout.fillWidth: true
													}
												}
												MouseArea {
													anchors.fill: parent
													onClicked: adminPage.pendingSelectSubIndex
															   = index
												}
											}
										}
									}
								}
							}
						}
						// Quản lý nhân viên
						Rectangle {
							color: "lightgray"
							Layout.fillWidth: true
							Layout.fillHeight: true
							border.color: "darkgray"

							ColumnLayout {
								anchors.fill: parent
								anchors.margins: 10
								spacing: 10

								// Form for adding/editing employees
								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextField {
										id: tfEmployeeName
										placeholderText: "Họ và tên"
										placeholderTextColor: "white"
										color: "white"
										Layout.preferredWidth: 220
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
									TextField {
										id: tfEmployeeStaffId
										placeholderText: "Mã nhân viên"
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
										id: cbEmployeeRole
										model: ["Nhân viên", "Quản lý"]
										Layout.preferredWidth: 150
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
											color: "#111"
										}
									}
									Item { Layout.fillWidth: true }
								}

								RowLayout {
									spacing: 8
									Layout.fillWidth: true
									TextArea {
										id: taEmployeeNote
										placeholderText: "Ghi chú"
										placeholderTextColor: "white"
										color: "white"
										Layout.fillWidth: true
										Layout.preferredHeight: 40
										background: Rectangle {
											color: "#222"
											border.color: "#555"
											radius: 8
										}
									}
								}

								// Action buttons
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
											onClicked: adminPage.triggerAddEmployee = !adminPage.triggerAddEmployee
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
											onClicked: adminPage.triggerUpdateEmployee = !adminPage.triggerUpdateEmployee
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
											onClicked: adminPage.triggerDeleteEmployee = !adminPage.triggerDeleteEmployee
										}
									}
									Item {
										Layout.fillWidth: true
									}
									Rectangle { // Check-in Button
										width: 120
										height: 28
										radius: 8
										color: adminPage.canEmployeeCheckIn ? "#00897b" : "#555"
										Text { anchors.centerIn: parent; text: "Chấm công"; color: "white" }
										MouseArea {
											anchors.fill: parent
											enabled: adminPage.canEmployeeCheckIn
											onClicked: adminPage.triggerEmployeeCheckIn = !adminPage.triggerEmployeeCheckIn
											}
										}
									Rectangle { // Check-out Button
										width: 120
										height: 28
										radius: 8
										color: adminPage.canEmployeeCheckOut ? "#d84315" : "#555"
										Text { anchors.centerIn: parent; text: "Kết thúc ca"; color: "white" }
										MouseArea {
											anchors.fill: parent
											enabled: adminPage.canEmployeeCheckOut
											onClicked: adminPage.triggerEmployeeCheckOut = !adminPage.triggerEmployeeCheckOut
										}
									}
								}

								// List of employees
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
										// Header Row
										RowLayout {
											Layout.fillWidth: true
											spacing: 8
											Text { text: "ID"; color: "white"; Layout.preferredWidth: 50 }
											Text { text: "Họ và tên"; color: "white"; Layout.preferredWidth: 180 }
											Text { text: "Mã NV"; color: "white"; Layout.preferredWidth: 120 }
											Text { text: "Vai trò"; color: "white"; Layout.preferredWidth: 120 }
											Text { text: "Vào Ca"; color: "white"; Layout.preferredWidth: 120 }
											Text { text: "Kết thúc ca"; color: "white"; Layout.preferredWidth: 120 }
											Text { text: "Ghi chú"; color: "white"; Layout.fillWidth: true }
											Item {
												Layout.fillWidth: true
											}
										}

										// Employee ListView
										ListView {
											id: employeeListView
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 5) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											clip: true
											model: adminPage.employeeListModel
											delegate: Rectangle {
												width: parent ? parent.width : 0
												height: 30
												color: (adminPage.pendingSelectEmployeeIndex === index) ? "#334455" : "transparent"
												border.color: "#444"
												border.width: 1

												RowLayout {
													anchors.fill: parent
													spacing: 8
													Text { text: (index+1); color: "white"; Layout.preferredWidth: 50 }
													Text { text: full_name; color: "white"; Layout.preferredWidth: 180; elide: Text.ElideRight }
													Text { text: staff_id; color: "white"; Layout.preferredWidth: 120 }
													Text { text: role; color: "white"; Layout.preferredWidth: 120 }
													Text { text: shift_start_at; color: "white"; Layout.preferredWidth: 120 }
													Text { text: shift_end_at; color: "white"; Layout.preferredWidth: 120 }
													Text { text: note; color: "#ccc"; Layout.fillWidth: true; elide: Text.ElideRight }
													Item {
														Layout.fillWidth: true
													}
												}
												MouseArea {
													anchors.fill: parent
													onClicked: adminPage.pendingSelectEmployeeIndex = index
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
							border.color: "darkgray"
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
										validator: RegularExpressionValidator { regularExpression: /^\d{4}-\d{2}-\d{2}$/ }
										readOnly: true
										MouseArea { anchors.fill: parent; onClicked: adminPage.revFromPickerVisible = true }
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
										validator: RegularExpressionValidator { regularExpression: /^\d{4}-\d{2}-\d{2}$/ }
										readOnly: true
										MouseArea { anchors.fill: parent; onClicked: adminPage.revToPickerVisible = true }
									}
									ComboBox {
										id: revType
										model: ["Tất cả", "Vé lượt", "Vé tháng"]
										Layout.preferredWidth: 160
										Layout.preferredHeight: 24
										background: Rectangle {
											radius: 8
											color: "#111"
										}
									}
									Item {
										Layout.fillWidth: true
									}
									// Quick range presets
									Rectangle { width: 70; height: 28; radius: 8; color: "#555"
										Text { anchors.centerIn: parent; text: "7 ngày"; color: "white" }
										MouseArea { anchors.fill: parent; onClicked: revenueLogic && (revenueLogic.triggerPreset7 = !revenueLogic.triggerPreset7) }
									}
									Rectangle { width: 70; height: 28; radius: 8; color: "#555"
										Text { anchors.centerIn: parent; text: "30 ngày"; color: "white" }
										MouseArea { anchors.fill: parent; onClicked: revenueLogic && (revenueLogic.triggerPreset30 = !revenueLogic.triggerPreset30) }
									}
									Rectangle { width: 70; height: 28; radius: 8; color: "#555"
										Text { anchors.centerIn: parent; text: "90 ngày"; color: "white" }
										MouseArea { anchors.fill: parent; onClicked: revenueLogic && (revenueLogic.triggerPreset90 = !revenueLogic.triggerPreset90) }
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
										MouseArea { anchors.fill: parent; onClicked: adminPage.triggerRevenueFilter = !adminPage.triggerRevenueFilter }
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
										Text { anchors.centerIn: parent; text: "Reload"; color: "white" }
										MouseArea { anchors.fill: parent; onClicked: adminPage.triggerRevenueFilter = !adminPage.triggerRevenueFilter }
									}
									Rectangle {
										width: 120
										height: 28
										radius: 8
										color: "#2b7"
										Text { anchors.centerIn: parent; text: "Tạo dữ liệu"; color: "white" }
										MouseArea { anchors.fill: parent; onClicked: revenueLogic && (revenueLogic.triggerSeedDemo = !revenueLogic.triggerSeedDemo) }
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
											id: revenueList
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 6) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: revenueLogic ? revenueLogic.listModel : null
											clip: true
											delegate: Rectangle {
												color: "transparent"
												border.color: "#333"
												border.width: 1
												width: ListView.view ? ListView.view.width : 0
												height: 28
												RowLayout { anchors.fill: parent; spacing: 8
													Text { text: d; color: "white"; Layout.preferredWidth: 140 }
													Text { text: session_count; color: "white"; Layout.preferredWidth: 140 }
													Text { text: subscription_count; color: "white"; Layout.preferredWidth: 140 }
													Text { text: total_amount; color: "white"; Layout.preferredWidth: 180 }
													Item { Layout.fillWidth: true }
												}
											}
										}
									}
								}
								// Thống kê tổng + Export
									RowLayout {
										Layout.fillWidth: true
										spacing: 12
										Text { id: revSummaryTotal; text: "Tổng doanh thu: 0"; color: "white" }
										Text { id: revSummaryBreakdown; text: "Trong đó: vé lượt 0, vé tháng 0"; color: "white" }
										Item {
											Layout.fillWidth: true
										}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7" // Green color suitable for Excel
										Text {
											anchors.centerIn: parent
											text: "Xuất Excel"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											// Toggle the new Excel trigger
											onClicked: adminPage.triggerExportExcel = !adminPage.triggerExportExcel
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
									adminPage.triggerSavePricing = !adminPage.triggerSavePricing
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

	// Simple Date Picker Popup for Revenue From date
	Popup {
		id: revFromDatePopup
		modal: true
		focus: true
		visible: adminPage.revFromPickerVisible
		onClosed: adminPage.revFromPickerVisible = false
		x: (parent ? parent.width : 800) / 2 - width / 2
		y: (parent ? parent.height : 600) / 2 - height / 2

		property alias fromYear: revFromYearCombo
		property alias fromMonth: revFromMonthCombo
		property alias fromDay: revFromDayCombo

		contentItem: ColumnLayout {
			spacing: 10
			RowLayout {
				spacing: 8
				Text { text: "Năm"; color: "black" }
				ComboBox {
					id: revFromYearCombo
					model: 101
					popup.height: 240
					delegate: ItemDelegate { text: (2000 + index) }
					Layout.preferredWidth: 100
					currentIndex: 25
				}
				Text { text: "Tháng"; color: "black" }
				ComboBox {
					id: revFromMonthCombo
					model: 12
					popup.height: 240
					delegate: ItemDelegate { text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) }
					displayText: (currentIndex + 1) < 10 ? "0" + (currentIndex + 1) : "" + (currentIndex + 1)
					Layout.preferredWidth: 90
					currentIndex: 1
				}
				Text { text: "Ngày"; color: "black" }
				ComboBox {
					id: revFromDayCombo
					model: 31
					popup.height: 240
					delegate: ItemDelegate { text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) }
					displayText: (currentIndex + 1) < 10 ? "0" + (currentIndex + 1) : "" + (currentIndex + 1)
					Layout.preferredWidth: 90
					currentIndex: 1
				}
			}
			RowLayout {
				Layout.fillWidth: true
				spacing: 10
				Rectangle {
					Layout.fillWidth: true
					height: 32
					radius: 6
					color: "#444"
					Text { anchors.centerIn: parent; text: "Hủy"; color: "white" }
					MouseArea { anchors.fill: parent; onClicked: adminPage.revFromPickerVisible = false }
				}
				Rectangle {
					Layout.fillWidth: true
					height: 32
					radius: 6
					color: "#2b7"
					Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
					MouseArea { anchors.fill: parent; onClicked: adminPage.triggerRevFromSelect = !adminPage.triggerRevFromSelect }
				}
			}
		}
	}

	// Simple Date Picker Popup for Revenue To date
	Popup {
		id: revToDatePopup
		modal: true
		focus: true
		visible: adminPage.revToPickerVisible
		onClosed: adminPage.revToPickerVisible = false
		x: (parent ? parent.width : 800) / 2 - width / 2
		y: (parent ? parent.height : 600) / 2 - height / 2

		property alias toYear: revToYearCombo
		property alias toMonth: revToMonthCombo
		property alias toDay: revToDayCombo

		contentItem: ColumnLayout {
			spacing: 10
			RowLayout {
				spacing: 8
				Text { text: "Năm"; color: "black" }
				ComboBox {
					id: revToYearCombo
					model: 101
					popup.height: 240
					delegate: ItemDelegate { text: (2000 + index) }
					Layout.preferredWidth: 100
					currentIndex: 25
				}
				Text { text: "Tháng"; color: "black" }
				ComboBox {
					id: revToMonthCombo
					model: 12
					popup.height: 240
					delegate: ItemDelegate { text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) }
					displayText: (currentIndex + 1) < 10 ? "0" + (currentIndex + 1) : "" + (currentIndex + 1)
					Layout.preferredWidth: 90
					currentIndex: 1
				}
				Text { text: "Ngày"; color: "black" }
				ComboBox {
					id: revToDayCombo
					model: 31
					popup.height: 240
					delegate: ItemDelegate { text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1) }
					displayText: (currentIndex + 1) < 10 ? "0" + (currentIndex + 1) : "" + (currentIndex + 1)
					Layout.preferredWidth: 90
					currentIndex: 1
				}
			}
			RowLayout {
				Layout.fillWidth: true
				spacing: 10
				Rectangle {
					Layout.fillWidth: true
					height: 32
					radius: 6
					color: "#444"
					Text { anchors.centerIn: parent; text: "Hủy"; color: "white" }
					MouseArea { anchors.fill: parent; onClicked: adminPage.revToPickerVisible = false }
				}
				Rectangle {
					Layout.fillWidth: true
					height: 32
					radius: 6
					color: "#2b7"
					Text { anchors.centerIn: parent; text: "Chọn"; color: "white" }
					MouseArea { anchors.fill: parent; onClicked: adminPage.triggerRevToSelect = !adminPage.triggerRevToSelect }
				}
			}
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
						color: "#fff"
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
						color: "#fff"
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
