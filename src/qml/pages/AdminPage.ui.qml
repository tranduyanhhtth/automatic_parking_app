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
	property alias subUserText: subUserText
	// Subscriptions form control aliases for logic access
	property alias subPlate: subPlate
	property alias subRfid: subRfid
	property alias subPlan: subPlan
	property alias subStart: subStart
	property alias subEnd: subEnd
	property alias subPayment: subPayment
	property alias subPrice: subPrice
	property alias subFilter: subFilter
	property alias subPlatePick: subPlatePick
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
	property alias tabBar: tabbar
	// Trigger cho thao tác user
	property bool triggerAddUser: false
	property bool triggerUpdateUser: false
	property bool triggerDeleteUser: false
	// Triggers cho subscriptions
	property bool triggerSubCreate: false
	property bool triggerSubExtend: false
	property bool triggerSubLostDelete: false
	property bool triggerSubCancel: false
	property bool triggerSubFilterChanged: false
	property bool triggerExportExpired: false
	property bool triggerSubUserTextChanged: false
	property bool triggerSubCancelExtend: false
	property bool triggerSubsChanged: false
	// buffer for generated expired CSV
	property string expiredCsvBuffer: ""
	property bool triggerUsersChanged: false
	// Row selection via index (single-expression onClicked)
	property int pendingSelectUserIndex: -1
	property int pendingSelectSubIndex: -1
	property int pendingSelectRfidIndex: -1

	// Revenue date-picker integration (SearchPage-style for Revenue tab)
	property bool revFromPickerVisible: false
	property bool revToPickerVisible: false
	property bool triggerRevFromSelect: false
	property bool triggerRevToSelect: false
	property bool triggerRevenueFilter: false
	// Triggers for exporting files 
	property bool triggerExportCsv: false
	property bool triggerExportPdf: false
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

	// Logic instances
	ToastComponent {
		id: toastOverlay
	}
	NotifyLogic {
		id: notifyLogic
		toast: toastOverlay
	}
	UsersLogic {
		id: usersLogic
		adminPage: adminPage
		notify: notifyLogic.push
	}
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
	// File save dialogs for exports
	FileDialog {
		id: revenueSaveDialog
		title: "Chọn nơi lưu CSV Doanh thu"
		nameFilters: ["CSV files (*.csv)", "All files (*.*)"]
		selectedFile: "bao_cao_doanh_thu.csv"
	}
	FileDialog {
		id: subsSaveDialog
		title: "Chọn nơi lưu CSV Đăng ký"
		nameFilters: ["CSV files (*.csv)", "All files (*.*)"]
		selectedFile: "dang_ky_het_han.csv"
		// When accepted, write the buffer via repo
		onAccepted: {
			try {
				if (typeof repo !== 'undefined' && repo.saveTextToFile) {
					const path = subsSaveDialog.selectedFile || (subsSaveDialog.selectedFiles && subsSaveDialog.selectedFiles.length>0 ? subsSaveDialog.selectedFiles[0] : "");
					const ok = repo.saveTextToFile(path, adminPage.expiredCsvBuffer || "");
					notifyLogic.push(ok?"Đã lưu file CSV đăng ký":"Lỗi khi lưu file");
				} else {
					notifyLogic.push("Thiếu API lưu file");
				}
			} catch(e) { console.log(e) }
		}
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
							text: "Phân loại thẻ"
						}
						TabButton {
							text: "Người dùng"
						}
						TabButton {
							text: "Đăng kí"
						}
						TabButton {
							text: "Doanh thu"
						}
					}
					Connections {
						// When switching to Revenue tab (index 5), ask logic to refresh via trigger
						target: tabbar
						function onCurrentIndexChanged() {
							if (tabbar.currentIndex === 5)
								adminPage.triggerRevenueFilter = !adminPage.triggerRevenueFilter;
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
											text: "Giá (VND)"
											color: "white"
											font.bold: true
											Layout.preferredWidth: 160
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
								RfidCardsLogic {
									id: rfidLogic
									adminPage: adminPage
									tfRfid: tfRfid
									cbVehicle: cbVehicle
									cbTicket: cbTicket
									cbStatus: cbStatus
									tfDesc: tfDesc
									repoRef: repo
									notify: notifyLogic.push
								}
								RowLayout {
									Layout.fillWidth: true
									spacing: 8
									TextField {
										id: tfRfid
										Layout.preferredWidth: 200
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
										Layout.preferredWidth: 180
										Layout.preferredHeight: 24
										model: ["Xe máy", "Ô tô"]
										background: Rectangle {
											radius: 8
										}
									}
									ComboBox {
										id: cbTicket
										Layout.preferredWidth: 180
										Layout.preferredHeight: 24
										model: ["Giờ", "Ngày (ban ngày)", "Ngày (ban đêm)", "Qua đêm", "Tháng", "Quý", "Năm"]
										background: Rectangle {
											radius: 8
										}
									}
									ComboBox {
										id: cbStatus
										Layout.preferredWidth: 180
										Layout.preferredHeight: 24
										model: ["available", "assigned"]
										background: Rectangle {
											radius: 8
										}
									}
									TextField {
										id: tfDesc
										Layout.fillWidth: true
										placeholderText: "Mô tả"
										color: "white"
										placeholderTextColor: "white"
										background: Rectangle {
											color: '#222'
											radius: 8
											border.color: '#555'
										}
									}
									Rectangle {
										width: 110
										height: 28
										radius: 8
										color: "#2b7"
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
												text: "RFID"
												color: "white"
												Layout.preferredWidth: 160
											}
											Text {
												text: "Loại xe"
												color: "white"
												Layout.preferredWidth: 100
											}
											Text {
												text: "Loại vé"
												color: "white"
												Layout.preferredWidth: 140
											}
											Text {
												text: "Số điện thoại"
												color: "white"
												Layout.preferredWidth: 120
											}
											Text {
												text: "Trạng thái"
												color: "white"
												Layout.preferredWidth: 120
											}
											Text {
												text: "Gán lúc"
												color: "white"
												Layout.preferredWidth: 160
											}
											Text {
												text: "Mô tả"
												color: "white"
												Layout.fillWidth: true
											}
										}
										ListView {
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 2) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: rfidLogic.listModel
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
														text: rfid
														color: "white"
														Layout.preferredWidth: 160
														elide: Text.ElideRight
													}
													Text {
														text: vehicle_type
														color: "white"
														Layout.preferredWidth: 100
													}
													Text {
														text: ticket_type
														color: "white"
														Layout.preferredWidth: 140
													}
													Text {
														text: (user_phone===undefined||user_phone===null)?'':(''+user_phone)
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: status
														color: "white"
														Layout.preferredWidth: 120
													}
													Text {
														text: (assigned_at
															   || '')
														color: "white"
														Layout.preferredWidth: 160
													}
													Text {
														text: (description
															   || '')
														color: "#ddd"
														Layout.fillWidth: true
														wrapMode: Text.Wrap
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
														color: status
															   === 'inactive' ? '#ff9800' : '#ccc'
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
									Connections {
										target: subPlatePick
										function onVisibleChanged(){
											if (subPlatePick.visible && (subPlatePick.currentIndex === -1 || subPlatePick.currentIndex === undefined)) {
												try {
													if (subPlatePick.popup && !subPlatePick.popup.visible) subPlatePick.popup.open()
													else if (subPlatePick.showPopup) subPlatePick.showPopup()
													subPlatePick.forceActiveFocus()
												} catch(e) {}
											}
										}
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
											id: subsListView
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 4) && !adminPage.loginVisible
											Layout.fillWidth: true
											Layout.fillHeight: true
											model: subsLogic ? subsLogic.listModel : null
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
											visible: (adminPage.tabBar && adminPage.tabBar.currentIndex === 5) && !adminPage.loginVisible
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
										color: "#2b7"
										Text {
											anchors.centerIn: parent
											text: "Xuất CSV"
											color: "white"
										}
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerExportCsv = !adminPage.triggerExportCsv
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
										MouseArea {
											anchors.fill: parent
											onClicked: adminPage.triggerExportPdf = !adminPage.triggerExportPdf
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
