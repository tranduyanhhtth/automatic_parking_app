import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property Item searchPage

    Timer {
        id: timeUpdater
        interval: 60000 
        running: true
        repeat: true
    }

    function getDaysInMonth(year, month) { // month is 1-based (1=Jan, 2=Feb, etc.)
           return new Date(year, month, 0).getDate();
    }

    function updateDayModel(yearCombo, monthCombo, dayCombo) {
        if (!yearCombo || !monthCombo || !dayCombo) return;

        var year = 2000 + yearCombo.currentIndex;
        var month = monthCombo.currentIndex + 1; // Convert 0-11 index to 1-12 month
        var days = getDaysInMonth(year, month);

        dayCombo.model = days;

        if (dayCombo.currentIndex >= days) {
            dayCombo.currentIndex = days - 1; // Reset to the last valid day
        }
    }

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

    // Function to update current time for both the 'From' and 'To' fields
    function updateCurrentTime() {
        if (searchPage) {
            let now = new Date();
            let hours = now.getHours();
            let minutes = now.getMinutes();

            searchPage.fromHour.currentIndex = hours;
            searchPage.fromMinute.currentIndex = minutes;
            searchPage.toHour.currentIndex = hours;
            searchPage.toMinute.currentIndex = minutes;
        }
    }

    // Function to update current date and time to defaults (today, live time for both)
    function updateCurrentDateTime() {
        if (searchPage) {
            let now = new Date();
            let year = now.getFullYear();
            let month = now.getMonth() + 1; // 0-based to 1-based
            let day = now.getDate();
            searchPage.dpFrom.text = formatDate(year, month, day);
            searchPage.dpTo.text = formatDate(year, month, day);
            updateCurrentTime();
        }
    }

    // Handle date picker visibility to set default values
    Connections {
        target: searchPage
        function onFromPickerVisibleChanged() {
            if (searchPage.fromPickerVisible) {
                var now = new Date();
                searchPage.fromYear.currentIndex = now.getFullYear() - 2000; // 2025 - 2000 = 25
                searchPage.fromMonth.currentIndex = now.getMonth(); // 0-11 (August = 7)
                searchPage.fromDay.currentIndex = now.getDate() - 1; // 0-30 (26 - 1 = 25)
            }
        }

        function onToPickerVisibleChanged() {
            if (searchPage.toPickerVisible) {
                var now = new Date();
                searchPage.toYear.currentIndex = now.getFullYear() - 2000; // 2025 - 2000 = 25
                searchPage.toMonth.currentIndex = now.getMonth(); // 0-11 (August = 7)
                searchPage.toDay.currentIndex = now.getDate() - 1; // 0-30 (26 - 1 = 25)
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
            updateCurrentDateTime();
        }
    }

    // Handle popup visibility changes to sync control flags
    Connections {
        target: searchPage.fromDatePopup
        function onVisibleChanged() {
            if (target && !target.visible) {
                searchPage.fromPickerVisible = false;
            }
        }
    }

    Connections {
        target: searchPage.toDatePopup
        function onVisibleChanged() {
            if (target && !target.visible) {
                searchPage.toPickerVisible = false;
            }
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
            // Không ép lowercase ở đây để vẫn có thể hiển thị đúng nguyên bản; dùng so khớp không phân biệt hoa/thường phía dưới
            let query = (searchPage.tfQuery.text || "").trim();
            // Map combobox -> giá trị thực trong DB: parking_sessions.status IN ('checked_in','checked_out','pending')
            let status = "";
            if (searchPage.cbStatus.currentIndex === 1)
                status = "checked_in";
            else if (searchPage.cbStatus.currentIndex === 2)
                status = "checked_out";

            console.log("Search Parameters:", {
                query: query || "(not set)",
                status: status || "(not set)",
                fromIso: fromIso || "(not set)",
                toIso: toIso || "(not set)"
            });
            // Thứ tự hàm C++: searchSessions(plate, rfid, fromIso, toIso, status, limit, offset)
            // Ta truyền plate nếu có; rfid để trống vì chưa có input.
            const results = repo.searchSessions(
                query || "",
                query || "",
                fromIso || "",
                toIso || "",
                status || "",
                200,
                0
            );

            // Bổ sung lọc không phân biệt hoa/thường (nếu user nhập plate)
            const filteredResults = (!query)
                ? results
                : results.filter(r => (r.plate || "").toString().toLowerCase() === query.toLowerCase());

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
                    payment_check: r.payment_check || "",
                    thumbnail: ""
                });
            }
            if (searchPage.lblSummary)
                searchPage.lblSummary.text = "Tìm thấy: " + filteredResults.length + " bản ghi";
            if (searchPage.lblRevenue)
                searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: " + total + " VNĐ";
        }

        function onTriggerCloseChanged() {
            if (!searchPage.triggerClose) return; // chỉ xử lý khi vừa toggle
            searchPage.tfQuery.text = "";
            searchPage.cbStatus.currentIndex = 0;
            updateCurrentDateTime();
            searchPage.resultsModel.clear();
            if (searchPage.lblSummary)
                searchPage.lblSummary.text = "0 kết quả";
            if (searchPage.lblRevenue)
                searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: 0 VNĐ";
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
            searchPage.sessionDetailDialog.dialog.open();
        }
    }

    Connections {
            target: searchPage
            function onTriggerViewImageChanged() {
                if (!searchPage.triggerViewImage) return;

                var sid = searchPage.selectedRowId;
                if (!sid || sid <= 0) return;

                console.log("Viewing images for session:", sid);

                // Fetch details from DatabaseManager (returns QVariantMap)
                // C++ Signature: QVariantMap getSessionDetails(int id);
                var det = repo.getSessionDetails(sid);

                if (det) {
                    // DatabaseManager returns keys: img1, img2, checkout_img1, checkout_img2
                    searchPage.viewImg1 = det.img1 || "";
                    searchPage.viewImg2 = det.img2 || "";
                    searchPage.viewOutImg1 = det.checkout_img1 || "";
                    searchPage.viewOutImg2 = det.checkout_img2 || "";
                } else {
                    searchPage.viewImg1 = "";
                    searchPage.viewImg2 = "";
                    searchPage.viewOutImg1 = "";
                    searchPage.viewOutImg2 = "";
                }

                // Open the new popup
                searchPage.imageViewer.open();
            }
        }

    Connections {
        target: searchPage
        function onVisibleChanged() {
            if (searchPage.visible) {
                updateCurrentDateTime();
            }
        }
    }

    Connections {
        target: searchPage.fromDatePopup
        function onVisibleChanged() {
            if (target.visible) {
                updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay);
            }
        }
    }

    Connections {
        target: searchPage.fromYear
        function onCurrentIndexChanged() {
            updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay);
        }
    }

    Connections {
        target: searchPage.fromMonth
        function onCurrentIndexChanged() {
            updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay);
        }
    }

    // Handle "To" date picker logic
    Connections {
        target: searchPage.toDatePopup
        function onVisibleChanged() {
            if (target.visible) {
                updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay);
            }
        }
    }

    Connections {
        target: searchPage.toYear
        function onCurrentIndexChanged() {
            updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay);
        }
    }

    Connections {
        target: searchPage.toMonth
        function onCurrentIndexChanged() {
            updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay);
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
