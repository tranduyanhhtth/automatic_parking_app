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
        onTriggered: updateCurrentTime()
    }

    function getDaysInMonth(year, month) {
        return new Date(year, month, 0).getDate();
    }

    // ... [keep updateDayModel function unchanged] ...
    function updateDayModel(yearCombo, monthCombo, dayCombo) {
        if (!yearCombo || !monthCombo || !dayCombo) return;
        var year = 2000 + yearCombo.currentIndex;
        var month = monthCombo.currentIndex + 1;
        var days = getDaysInMonth(year, month);
        var oldIndex = dayCombo.currentIndex;
        dayCombo.model = days;
        if (oldIndex >= days) {
            dayCombo.currentIndex = days - 1;
        } else if (oldIndex >= 0) {
            dayCombo.currentIndex = oldIndex;
        }
    }

    function formatDate(year, month, day) {
        let dt = new Date(year, month - 1, day);
        if (dt.getFullYear() !== year || dt.getMonth() !== month - 1 || dt.getDate() !== day) {
            return "";
        }
        let monthStr = month < 10 ? ("0" + month) : ("" + month);
        let dayStr = day < 10 ? ("0" + day) : ("" + day);
        return `${year}-${monthStr}-${dayStr}`;
    }

    function updateCurrentTime() {
        if (searchPage) {
            let now = new Date();
            let hours = now.getHours();
            let minutes = now.getMinutes();

            // Format HH:MM
            let hStr = (hours < 10 ? "0" : "") + hours;
            let mStr = (minutes < 10 ? "0" : "") + minutes;
            let timeStr = hStr + ":" + mStr;

            // Set Text Fields
            searchPage.tfFromTime.text = timeStr;
            searchPage.tfToTime.text = timeStr;

            // Also sync the Combos so they are ready if opened immediately
            searchPage.fromHour.currentIndex = hours;
            searchPage.fromMinute.currentIndex = minutes;
            searchPage.toHour.currentIndex = hours;
            searchPage.toMinute.currentIndex = minutes;
        }
    }

    // ... [keep Date Picker connections unchanged] ...
    Connections {
        target: searchPage
        function onFromPickerVisibleChanged() {
            if (searchPage.fromPickerVisible) {
                var now = new Date();
                searchPage.fromYear.currentIndex = now.getFullYear() - 2000;
                searchPage.fromMonth.currentIndex = now.getMonth();
                searchPage.fromDay.currentIndex = now.getDate() - 1;
            }
        }
        function onToPickerVisibleChanged() {
            if (searchPage.toPickerVisible) {
                var now = new Date();
                searchPage.toYear.currentIndex = now.getFullYear() - 2000;
                searchPage.toMonth.currentIndex = now.getMonth();
                searchPage.toDay.currentIndex = now.getDate() - 1;
            }
        }
    }

    // Date Select Handlers
    Connections {
        target: searchPage
        function onTriggerFromDateSelectChanged() {
            if (!searchPage.fromYear || !searchPage.fromMonth || !searchPage.fromDay) return;
            var year = 2000 + searchPage.fromYear.currentIndex;
            var month = searchPage.fromMonth.currentIndex + 1;
            var day = searchPage.fromDay.currentIndex + 1;
            searchPage.dpFrom.text = formatDate(year, month, day);
            searchPage.fromPickerVisible = false;
            searchPage.triggerFromDateSelect = false;
        }

        function onTriggerToDateSelectChanged() {
            if (!searchPage.toYear || !searchPage.toMonth || !searchPage.toDay) return;
            var year = 2000 + searchPage.toYear.currentIndex;
            var month = searchPage.toMonth.currentIndex + 1;
            var day = searchPage.toDay.currentIndex + 1;
            searchPage.dpTo.text = formatDate(year, month, day);
            searchPage.toPickerVisible = false;
            searchPage.triggerToDateSelect = false;
        }
    }

    // --- NEW: Time Select Handlers ---
    Connections {
        target: searchPage
        // Sync Popup Combos when opened to match current Text
        function onFromTimePickerVisibleChanged() {
            if (searchPage.fromTimePickerVisible) {
                let parts = searchPage.tfFromTime.text.split(':');
                if (parts.length === 2) {
                    searchPage.fromHour.currentIndex = parseInt(parts[0]);
                    searchPage.fromMinute.currentIndex = parseInt(parts[1]);
                }
            }
        }

        function onTriggerFromTimeSelectChanged() {
            // User clicked "Chọn"
            let h = searchPage.fromHour.currentIndex;
            let m = searchPage.fromMinute.currentIndex;
            searchPage.tfFromTime.text = (h<10?"0":"")+h + ":" + (m<10?"0":"")+m;
            searchPage.fromTimePickerVisible = false;
            searchPage.triggerFromTimeSelect = false;
        }

        // To Time
        function onToTimePickerVisibleChanged() {
            if (searchPage.toTimePickerVisible) {
                let parts = searchPage.tfToTime.text.split(':');
                if (parts.length === 2) {
                    searchPage.toHour.currentIndex = parseInt(parts[0]);
                    searchPage.toMinute.currentIndex = parseInt(parts[1]);
                }
            }
        }

        function onTriggerToTimeSelectChanged() {
            let h = searchPage.toHour.currentIndex;
            let m = searchPage.toMinute.currentIndex;
            searchPage.tfToTime.text = (h<10?"0":"")+h + ":" + (m<10?"0":"")+m;
            searchPage.toTimePickerVisible = false;
            searchPage.triggerToTimeSelect = false;
        }
    }

    Component.onCompleted: {
        if (searchPage) {
            updateCurrentTime();
            searchPage.triggerSearch = !searchPage.triggerSearch;
        }
    }

    // Connections to close popups if clicked outside (default behavior logic)
    Connections { target: searchPage.fromDatePopup; function onVisibleChanged() { if (target && !target.visible) searchPage.fromPickerVisible = false; } }
    Connections { target: searchPage.toDatePopup; function onVisibleChanged() { if (target && !target.visible) searchPage.toPickerVisible = false; } }
    Connections { target: searchPage.fromTimePopup; function onVisibleChanged() { if (target && !target.visible) searchPage.fromTimePickerVisible = false; } }
    Connections { target: searchPage.toTimePopup; function onVisibleChanged() { if (target && !target.visible) searchPage.toTimePickerVisible = false; } }

    // Search Execution
    Connections {
        target: searchPage
        function onTriggerSearchChanged() {
            if (!repo) {
                console.log("Repo not ready");
                return;
            }

            function normalizeDateTime(dateText, timeText) {
                if (!dateText || dateText === "") return "";
                let parts = dateText.split('-');
                if (parts.length !== 3) return "";
                let year = parseInt(parts[0]);
                let month = parseInt(parts[1]) - 1;
                let day = parseInt(parts[2]);

                let hour = 0;
                let minute = 0;

                // Parse HH:mm from timeText
                if (timeText && timeText.indexOf(':') !== -1) {
                    let timeParts = timeText.split(':');
                    hour = parseInt(timeParts[0]);
                    minute = parseInt(timeParts[1]);
                }

                let date = new Date(year, month, day, hour, minute);
                if (isNaN(date.getTime())) return "";
                return Qt.formatDateTime(date, "yyyy-MM-ddTHH:mm:ss");
            }

            let fromIso = normalizeDateTime(searchPage.dpFrom.text, searchPage.tfFromTime.text);
            let toIso = normalizeDateTime(searchPage.dpTo.text, searchPage.tfToTime.text);
            let query = (searchPage.tfQuery.text || "").trim();

            let status = "";
            if (searchPage.cbStatus.currentIndex === 1) status = "checked_in";
            else if (searchPage.cbStatus.currentIndex === 2) status = "checked_out";

            const results = repo.searchSessions(
                query || "",
                query || "",
                fromIso || "",
                toIso || "",
                status || "",
                5000,
                0
            );

            // ... [Keep filtering and model update logic unchanged] ...
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

        // Reset
        function onTriggerCloseChanged() {
            if (!searchPage.triggerClose) return;
            searchPage.tfQuery.text = "";
            searchPage.cbStatus.currentIndex = 0;
            searchPage.dpFrom.text = "";
            searchPage.dpTo.text = "";
            updateCurrentTime();
            searchPage.resultsModel.clear();

            if (searchPage.lblSummary) searchPage.lblSummary.text = "0 kết quả";
            if (searchPage.lblRevenue) searchPage.lblRevenue.text = "Tổng doanh thu trong kết quả: 0 VNĐ";

            // ADD THIS LINE to reload all data immediately:
            searchPage.triggerSearch = !searchPage.triggerSearch;
        }
    }

    // ... [Rest of file: Detail Logic and Date Model Updates remain unchanged] ...
    Connections {
        target: searchPage
        function onTriggerShowDetailChanged() {
             // ... existing code ...
             if (!searchPage.triggerShowDetail) return;
             var sid = searchPage.selectedRowId;
             // ... existing logic ...
             searchPage.sessionDetailDialog.dialog.open();
        }
    }

    Connections { target: searchPage.fromDatePopup; function onVisibleChanged() { if (target.visible) updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay); } }
    Connections { target: searchPage.fromYear; function onCurrentIndexChanged() { updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay); } }
    Connections { target: searchPage.fromMonth; function onCurrentIndexChanged() { updateDayModel(searchPage.fromYear, searchPage.fromMonth, searchPage.fromDay); } }
    Connections { target: searchPage.toDatePopup; function onVisibleChanged() { if (target.visible) updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay); } }
    Connections { target: searchPage.toYear; function onCurrentIndexChanged() { updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay); } }
    Connections { target: searchPage.toMonth; function onCurrentIndexChanged() { updateDayModel(searchPage.toYear, searchPage.toMonth, searchPage.toDay); } }
}
