import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property Item searchPage
    // Handle date selection signals
    Connections {
        target: searchPage
        function formatDate(year, month, day) {
            let dt = new Date(year, month - 1, day)
            if (dt.getFullYear() !== year || dt.getMonth() !== month - 1 || dt.getDate() !== day) {
                root.showToast("Ngày không hợp lệ")
                return ""
            }
            let monthStr = month < 10 ? ("0" + month) : ("" + month)
            let dayStr = day < 10 ? ("0" + day) : ("" + day)
            return "" + year + "-" + monthStr + "-" + dayStr
        }
        function onTriggerFromDateSelectChanged() {
            var year = 2000 + searchPage.fromYear.currentIndex
            var month = searchPage.fromMonth.currentIndex + 1
            var day = searchPage.fromDay.currentIndex + 1
            searchPage.dpFrom.text = formatDate(year, month, day)
            searchPage.fromPickerVisible = false
            searchPage.triggerFromDateSelect = false
        }
        function onTriggerToDateSelectChanged() {
            var year = 2000 + searchPage.toYear.currentIndex
            var month = searchPage.toMonth.currentIndex + 1
            var day = searchPage.toDay.currentIndex + 1
            searchPage.dpTo.text = formatDate(year, month, day)
            searchPage.toPickerVisible = false
            searchPage.triggerToDateSelect = false
        }
    }

    // Set default date to current date on component completion
    Component.onCompleted: {
        if (searchPage) {
            let now = new Date()
            let year = now.getFullYear()
            let month = now.getMonth() + 1 // 0-based to 1-based
            let day = now.getDate()
            searchPage.dpFrom.text = formatDate(year, month, day)
            searchPage.dpTo.text = formatDate(year, month, day)
            // Cập nhật index của ComboBox (cần alias hoặc cách khác để truy cập)
            // Hiện tại, chỉ gán text, không thay đổi index do .ui.qml tách biệt
        }
    }

    // Tìm kiếm từ SearchPage
    Connections {
        target: searchPage
        function onTriggerSearchChanged() {
            if (!repo) {
                root.showToast("Repo không sẵn sàng")
                return
            }
            function normalizeDate(s) {
                if (!s) return ""
                var ds = s.trim().split('-')
                if (ds.length !== 3) return ""
                var y = parseInt(ds[0]), m = parseInt(ds[1]) - 1, d = parseInt(ds[2])
                var dt = new Date(y, m, d, 0, 0, 0) // Default to 00:00:00
                // Optionally include current time (e.g., 08:31 AM)
                if (new Date().getHours() >= 0) { // Adjust condition as needed
                    dt.setHours(new Date().getHours(), new Date().getMinutes(), 0)
                }
                return Qt.formatDateTime(dt, "yyyy-MM-ddTHH:mm:ss")
            }
            let fromIso = normalizeDate(searchPage.dpFrom.text)
            let toIso = normalizeDate(searchPage.dpTo.text)
            var q = (searchPage.tfQuery && searchPage.tfQuery.text) ? searchPage.tfQuery.text.trim() : ""
            var plate = ""
            var rfid = ""
            if (q.length > 0) {
                var hasLetter = /[A-Za-z]/.test(q)
                if (hasLetter) plate = q
                else rfid = q
            }
            var st = searchPage.cbStatus.currentText || ""
            var status = ""
            if (st === "In") status = "in"
            else if (st === "Out") status = "out"
            else status = ""
            const rows = repo.searchSessions(plate, rfid, fromIso, toIso, status, 200, 0)
            // Cập nhật model hiển thị
            searchPage.resultsModel.clear()
            var total = 0
            for (var i = 0; i < rows.length; ++i) {
                var r = rows[i]
                total += (r.fee || 0)
                searchPage.resultsModel.append({
                    idText: r.id || "",
                    userId: r.user_id || 0,
                    plate: r.plate || "",
                    rfid: r.rfid || "",
                    checkin: r.checkin_time || "",
                    checkout: r.checkout_time || "",
                    fee: r.fee || 0,
                    status: r.status || "",
                    thumbnail: ""
                })
            }
            if (searchPage.lblSummary)
                searchPage.lblSummary.text = "Tìm thấy: " + rows.length + " bản ghi"
            if (searchPage.lblRevenue)
                searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: " + total + " VNĐ"
        }
    }

    // Mở chi tiết một phiên khi user bấm nút
    Connections {
        target: searchPage
        function onTriggerShowDetailChanged() {
            if (!searchPage.triggerShowDetail) return
            var sid = searchPage.selectedRowId
            if (!sid || sid <= 0) return
            // Nếu repo có API trả đủ ảnh theo id, dùng; nếu không, thử dùng lại dữ liệu từ model
            var row = null
            // Scan model for the selected row to fill basic fields fast
            var m = searchPage.resultsModel
            for (var i = 0; i < m.count; ++i) {
                var it = m.get(i)
                if (parseInt(it.idText) === sid) {
                    row = it
                    break
                }
            }
            // Điền thông tin căn bản
            searchPage.sessionDetailDialog.plate = row ? (row.plate || "") : ""
            searchPage.sessionDetailDialog.checkin = row ? (row.checkin || "") : ""
            searchPage.sessionDetailDialog.checkout = row ? (row.checkout || "") : ""
            searchPage.sessionDetailDialog.fee = row ? (row.fee || 0) : 0
            // Ảnh: thử lấy từ DB theo id, nếu không có thì fallback thumbnail
            try {
                var det = repo.getSessionDetails(sid)
                if (det) {
                    searchPage.sessionDetailDialog.img1Source = det.img1 || (row && row.thumbnail ? row.thumbnail : "")
                    searchPage.sessionDetailDialog.img2Source = det.img2 || ""
                    searchPage.sessionDetailDialog.checkoutImg1Source = det.checkout_img1 || ""
                    searchPage.sessionDetailDialog.checkoutImg2Source = det.checkout_img2 || ""
                } else {
                    searchPage.sessionDetailDialog.img1Source = row && row.thumbnail ? row.thumbnail : ""
                    searchPage.sessionDetailDialog.img2Source = ""
                    searchPage.sessionDetailDialog.checkoutImg1Source = ""
                    searchPage.sessionDetailDialog.checkoutImg2Source = ""
                }
            } catch (e) {
                searchPage.sessionDetailDialog.img1Source = row && row.thumbnail ? row.thumbnail : ""
                searchPage.sessionDetailDialog.img2Source = ""
                searchPage.sessionDetailDialog.checkoutImg1Source = ""
                searchPage.sessionDetailDialog.checkoutImg2Source = ""
            }
            // Hiển thị thông tin user (nếu có liên kết)
            try {
                var uid = (row && row.userId) ? parseInt(row.userId) : 0
                if (uid && uid > 0 && repo.getUserById) {
                    var u = repo.getUserById(uid)
                    searchPage.userNameLabel.text = "Họ tên: " + (u.full_name || "-")
                    searchPage.userPhoneLabel.text = "SĐT: " + (u.phone || "-")
                    searchPage.userVehicleTypeLabel.text = "Loại xe: " + (u.vehicle_type || "-")
                    searchPage.userNoteLabel.text = "Ghi chú: " + (u.note || "-")
                } else {
                    searchPage.userNameLabel.text = "Họ tên: -"
                    searchPage.userPhoneLabel.text = "SĐT: -"
                    searchPage.userVehicleTypeLabel.text = "Loại xe: -"
                    searchPage.userNoteLabel.text = "Ghi chú: -"
                }
            } catch (e) {
                searchPage.userNameLabel.text = "Họ tên: -"
                searchPage.userPhoneLabel.text = "SĐT: -"
                searchPage.userVehicleTypeLabel.text = "Loại xe: -"
                searchPage.userNoteLabel.text = "Ghi chú: -"
            }
            searchPage.sessionDetailDialog.dialog.open()
        }
    }

    // In hóa đơn
    Connections {
        target: searchPage
        function onTriggerPrintInvoiceChanged() {
            if (!searchPage.triggerPrintInvoice) return
            var sid = searchPage.selectedRowId
            if (!sid || sid <= 0) return
            // TODO: implement real printing/export
            if (root && root.showToast) root.showToast("In hóa đơn: " + sid)
            console.log("Print invoice for session", sid)
        }
    }
}
