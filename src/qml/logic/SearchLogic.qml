import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property Item searchPage

    function formatDate(year, month, day) {
        let dt = new Date(year, month - 1, day);
        if (dt.getFullYear() !== year || dt.getMonth() !== month - 1 || dt.getDate() !== day) {
            console.log("Invalid date in formatDate:", { year, month, day });
            return "";
        }
        let monthStr = month < 10 ? ("0" + month) : ("" + month);
        let dayStr = day < 10 ? ("0" + day) : ("" + day);
        return `${year}-${monthStr}-${dayStr}`;
    }

    // Function to update current date
    function updateCurrentDate() {
        if (searchPage) {
            let now = new Date();
            let year = now.getFullYear();
            let month = now.getMonth() + 1; // 0-based to 1-based
            let day = now.getDate();
            searchPage.dpFrom.text = formatDate(year, month, day);
            searchPage.dpTo.text = formatDate(year, month, day);
            // Cập nhật lại khi quay lại trang (nếu có sự kiện quay lại)
            if (searchPage.onVisibleChanged) {
                searchPage.onVisibleChanged.connect(function() {
                    if (searchPage.visible) {
                        searchPage.dpFrom.text = formatDate(year, month, day);
                        searchPage.dpTo.text = formatDate(year, month, day);
                    }
                });
            }
        }
    }

    // Handle date picker visibility to set default values
    Connections {
        target: searchPage
        function onFromPickerVisibleChanged() {
            if (searchPage.fromPickerVisible) {
                var now = new Date();
                searchPage.fromYear.currentIndex = now.getFullYear() - 2000; // 2025 - 2000 = 25
                searchPage.fromMonth.currentIndex = now.getMonth() + 1; // 0-11 (August = 7)
                searchPage.fromDay.currentIndex = now.getDate(); // 0-30 (26 - 1 = 25)
            }
        }

        function onToPickerVisibleChanged() {
            if (searchPage.toPickerVisible) {
                var now = new Date();
                searchPage.toYear.currentIndex = now.getFullYear() - 2000; // 2025 - 2000 = 25
                searchPage.toMonth.currentIndex = now.getMonth() + 1; // 0-11 (August = 7)
                searchPage.toDay.currentIndex = now.getDate(); // 0-30 (26 - 1 = 25)
            }
        }
    }

    // Handle date selection signals
    Connections {
        target: searchPage

        function onTriggerFromDateSelectChanged() {
            if (!searchPage.fromYear || !searchPage.fromMonth || !searchPage.fromDay) {
                console.log("Error: fromYear, fromMonth, or fromDay is undefined");
                return;
            }
            var year = 2000 + searchPage.fromYear.currentIndex;
            var month = searchPage.fromMonth.currentIndex + 1; // 0-11 -> 1-12
            var day = searchPage.fromDay.currentIndex + 1;     // 0-30 -> 1-31
            console.log("From Date - Year:", year, "Month:", month, "Day:", day);
            searchPage.dpFrom.text = formatDate(year, month, day);
            searchPage.fromPickerVisible = false;
            searchPage.triggerFromDateSelect = false;
        }

        function onTriggerToDateSelectChanged() {
            if (!searchPage.toYear || !searchPage.toMonth || !searchPage.toDay) {
                console.log("Error: toYear, toMonth, or toDay is undefined");
                return;
            }
            var year = 2000 + searchPage.toYear.currentIndex;
            var month = searchPage.toMonth.currentIndex + 1; // 0-11 -> 1-12
            var day = searchPage.toDay.currentIndex + 1;     // 0-30 -> 1-31
            console.log("To Date - Year:", year, "Month:", month, "Day:", day);
            searchPage.dpTo.text = formatDate(year, month, day);
            searchPage.toPickerVisible = false;
            searchPage.triggerToDateSelect = false;
        }
    }

    // Set default date to current date on component completion
    Component.onCompleted: {
        if (searchPage) {
            // let now = new Date();
            // let year = now.getFullYear();
            // let month = now.getMonth() + 1; // 0-based to 1-based
            // let day = now.getDate();
            // searchPage.dpFrom.text = formatDate(year, month, day);
            // searchPage.dpTo.text = formatDate(year, month, day);
            updateCurrentDate();
        }
    }

    // Tìm kiếm từ SearchPage
    Connections {
        target: searchPage
        function onTriggerSearchChanged() {
            if (!repo) {
                root.showToast("Repo không sẵn sàng");
                return;
            }

            function normalizeDateTime(dateText, hourIndex, minuteIndex) {
                if (!dateText || dateText === "") return "";
                let parts = dateText.split('-');
                if (parts.length !== 3) return "";
                let year = parseInt(parts[0]);
                let month = parseInt(parts[1]) - 1; // Month is 0-based
                let day = parseInt(parts[2]);
                let hour = hourIndex !== undefined && hourIndex !== null ? parseInt(hourIndex) : 0;
                let minute = minuteIndex !== undefined && minuteIndex !== null ? parseInt(minuteIndex) : 0;
                let date = new Date(year, month, day, hour, minute);
                if (isNaN(date.getTime())) {
                    console.log("Invalid date object:", { year, month, day, hour, minute });
                    return "";
                }
                return Qt.formatDateTime(date, "yyyy-MM-ddTHH:mm:ss");
            }

            let fromIso = searchPage.dpFrom.text ? normalizeDateTime(searchPage.dpFrom.text, searchPage.fromHour.currentIndex, searchPage.fromMinute.currentIndex) : "";
            let toIso = searchPage.dpTo.text ? normalizeDateTime(searchPage.dpTo.text, searchPage.toHour.currentIndex, searchPage.toMinute.currentIndex) : "";
            let query = (searchPage.tfQuery.text || "").toLowerCase();
            let status = searchPage.cbStatus.currentIndex === 0 ? "" : searchPage.cbStatus.currentIndex === 1 ? "in" : "out";

            console.log("Search Parameters:", {
                query: query || "(not set)",
                status: status || "(not set)",
                fromIso: fromIso || "(not set)",
                toIso: toIso || "(not set)"
            });

            const results = repo.searchSessions(
                query || "", // Nếu không nhập biển số, để trống
                status || "", // Nếu không chọn trạng thái, để trống
                fromIso || "", // Nếu không chọn ngày giờ từ, để trống
                toIso || "", // Nếu không chọn ngày giờ đến, để trống
                "", 200, 0
            );

            const filteredResults = results.filter(r => {
                if (query && r.plate) {
                    return r.plate === query;
                }
                return true;
            });

            searchPage.resultsModel.clear();
            var total = 0;
            for (var i = 0; i < filteredResults.length; ++i) {
                var r = filteredResults[i];
                total += (r.fee || 0);
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
                });
            }
            if (searchPage.lblSummary)
                searchPage.lblSummary.text = "Tìm thấy: " + results.length + " bản ghi";
            if (searchPage.lblRevenue)
                searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: " + total + " VNĐ";
        }

        function onTriggerCloseChanged() {
            searchPage.tfQuery.text = "";
            searchPage.cbStatus.currentIndex = 0;
            searchPage.dpFrom.text = "";
            searchPage.dpTo.text = "";
            searchPage.fromHour.currentIndex = 0;
            searchPage.fromMinute.currentIndex = 0;
            searchPage.toHour.currentIndex = 0;
            searchPage.toMinute.currentIndex = 0;
            searchPage.resultsModel.clear();
            if (searchPage.lblSummary)
                searchPage.lblSummary.text = "0 kết quả";
            if (searchPage.lblRevenue)
                searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: 0 VNĐ";
            searchPage.triggerClose = true
        }
    }

    // Mở chi tiết một phiên khi user bấm nút
    Connections {
        target: searchPage
        function onTriggerShowDetailChanged() {
            if (!searchPage.triggerShowDetail) return;
            var sid = searchPage.selectedRowId;
            if (!sid || sid <= 0) return;
            var row = null;
            var m = searchPage.resultsModel;
            for (var i = 0; i < m.count; ++i) {
                var it = m.get(i);
                if (parseInt(it.idText) === sid) {
                    row = it;
                    break;
                }
            }
            searchPage.sessionDetailDialog.plate = row ? (row.plate || "") : "";
            searchPage.sessionDetailDialog.checkin = row ? (row.checkin || "") : "";
            searchPage.sessionDetailDialog.checkout = row ? (row.checkout || "") : "";
            searchPage.sessionDetailDialog.fee = row ? (row.fee || 0) : 0;
            try {
                var det = repo.getSessionDetails(sid);
                if (det) {
                    searchPage.sessionDetailDialog.img1Source = det.img1 || (row && row.thumbnail ? row.thumbnail : "");
                    searchPage.sessionDetailDialog.img2Source = det.img2 || "";
                    searchPage.sessionDetailDialog.checkoutImg1Source = det.checkout_img1 || "";
                    searchPage.sessionDetailDialog.checkoutImg2Source = det.checkout_img2 || "";
                } else {
                    searchPage.sessionDetailDialog.img1Source = row && row.thumbnail ? row.thumbnail : "";
                    searchPage.sessionDetailDialog.img2Source = "";
                    searchPage.sessionDetailDialog.checkoutImg1Source = "";
                    searchPage.sessionDetailDialog.checkoutImg2Source = "";
                }
            } catch (e) {
                searchPage.sessionDetailDialog.img1Source = row && row.thumbnail ? row.thumbnail : "";
                searchPage.sessionDetailDialog.img2Source = "";
                searchPage.sessionDetailDialog.checkoutImg1Source = "";
                searchPage.sessionDetailDialog.checkoutImg2Source = "";
            }
            // try {
            //     var uid = (row && row.userId) ? parseInt(row.userId) : 0;
            //     if (uid && uid > 0 && repo.getUserById) {
            //         var u = repo.getUserById(uid);
            //         searchPage.userNameLabel.text = "Họ tên: " + (u.full_name || "-");
            //         searchPage.userPhoneLabel.text = "SĐT: " + (u.phone || "-");
            //         searchPage.userVehicleTypeLabel.text = "Loại xe: " + (u.vehicle_type || "-");
            //         searchPage.userNoteLabel.text = "Ghi chú: " + (u.note || "-");
            //     } else {
            //         searchPage.userNameLabel.text = "Họ tên: -";
            //         searchPage.userPhoneLabel.text = "SĐT: -";
            //         searchPage.userVehicleTypeLabel.text = "Loại xe: -";
            //         searchPage.userNoteLabel.text = "Ghi chú: -";
            //     }
            // } catch (e) {
            //     searchPage.userNameLabel.text = "Họ tên: -";
            //     searchPage.userPhoneLabel.text = "SĐT: -";
            //     searchPage.userVehicleTypeLabel.text = "Loại xe: -";
            //     searchPage.userNoteLabel.text = "Ghi chú: -";
            // }
            searchPage.sessionDetailDialog.dialog.open();
        }
    }

    // In hóa đơn
    Connections {
        target: searchPage
        function onTriggerPrintInvoiceChanged() {
            if (!searchPage.triggerPrintInvoice) return;
            var sid = searchPage.selectedRowId;
            if (!sid || sid <= 0) return;
            if (root && root.showToast) root.showToast("In hóa đơn: " + sid);
            console.log("Print invoice for session", sid);
        }
    }
}
