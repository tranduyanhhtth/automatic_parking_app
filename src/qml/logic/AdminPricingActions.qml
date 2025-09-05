import QtQuick

// Logic xử lý nút Thêm/Lưu/Xóa trong tab Bảng giá (Admin)
// - Lưu: cố gắng ghi xuống repo nếu có, nếu không thì thông báo đã cập nhật tạm thời
// - Xóa: đặt lại bảng giá về mặc định
// - Thêm: không cần cho bảng cố định này, có thể dùng để đặt preset theo loại phương tiện
Item {
    id: actions
    // Tham chiếu đến UI và logic dữ liệu
    property Item adminPage      // AdminPage.ui.qml instance
    property Item pricingLogic   // AdminPricingLogic
    property var  notify         // function(message) để hiển thị toast

    function resetTableToDefaults() {
        if (!pricingLogic) return
        pricingLogic.table = ({
            motorbike: {
                hour:     { min: "5000",   max: "8000" },
                day:      { min: "20000",  max: "30000" },
                night:    { min: "25000",  max: "40000" },
                overnight:{ min: "30000",  max: "48000" },
                month:    { min: "200000", max: "300000" },
                quarter:  { min: "540000", max: "810000" },
                year:     { min: "1920000",max: "2880000" }
            },
            car: {
                hour:     { min: "20000",   max: "30000" },
                day:      { min: "150000",  max: "240000" },
                night:    { min: "180000",  max: "300000" },
                overnight:{ min: "120000",  max: "180000" },
                month:    { min: "1500000", max: "2000000" },
                quarter:  { min: "4050000", max: "5400000" },
                year:     { min: "14400000",max: "19200000" }
            }
        })
    }

    // Mapping "Xe máy"/"Ô tô" -> repo keys
    function vehicleKey(label) {
        return (label === "Xe máy") ? "bike" : "car";
    }

    // Load bảng giá (min/max) đã lưu trong DB cho phương tiện
    function loadFromDbForVehicle(label) {
        if (!pricingLogic || typeof repo === 'undefined' || !repo.getLatestPricing)
            return;
        const vt = vehicleKey(label);
        const m = repo.getLatestPricing(vt, "admin_table");
        if (m && m.json) {
            try {
                // m.json có thể là object (do getLatestPricing parse sẵn)
                // hoặc không có -> m.time_slot_text là JSON string
                let js = m.json;
                if (!js && m.time_slot_text) js = JSON.parse(m.time_slot_text);
                if (js && js[vt]) {
                    pricingLogic.table[vt] = js[vt];
                }
            } catch(e) {
                // ignore malformed
            }
        }
    }

    Connections {
        target: adminPage
        // Nhấn Lưu: cố gắng gọi repo.savePricingJson nếu có
        function onTriggerSavePricingChanged() {
            if (!adminPage || !adminPage.triggerSavePricing) return
            // Log selected vehicle label if available
            try {
                const label = (adminPage && adminPage.pricingVehicleCombo) ? adminPage.pricingVehicleCombo.currentText : '(unknown)'
                console.log('[AdminPricingActions] Start save for vehicle label:', label)
            } catch(e) {}
            // Ưu tiên JSON do PricingLogic (UI) phát ra, nếu không có thì fallback bảng min/max
            let json = null
            try {
                if (adminPage.pricingJson && adminPage.pricingJson.text && adminPage.pricingJson.text.length > 0) {
                    json = adminPage.pricingJson.text
                }
            } catch(e) { json = null }
            // Nếu không có JSON từ UI thì không thực hiện lưu
            if (!json) {
                try { console.log('[AdminPricingActions] No JSON from UI; aborting save') } catch(e) {}
                adminPage.triggerSavePricing = false
                if (notify) notify('Thiếu dữ liệu để lưu')
                return
            }
            // Thử parse json như mảng các dòng pricing đã chuẩn hóa và upsert từng dòng
            let ok = false
            let savedCount = 0
            try {
                const arr = JSON.parse(json)
                try { console.log('[AdminPricingActions] Parsed JSON type:', Array.isArray(arr) ? 'array' : (typeof arr), 'length:', Array.isArray(arr) ? arr.length : -1) } catch(e) {}
                try { console.log('[AdminPricingActions] repo exists:', (typeof repo !== 'undefined'), 'has upsertPricingRow:', (repo && typeof repo.upsertPricingRow !== 'undefined')) } catch(e) {}
                if (Array.isArray(arr) && typeof repo !== 'undefined' && repo.upsertPricingRow) {
                    for (let i = 0; i < arr.length; ++i) {
                        const r = arr[i] || {}
                        const vtNorm = (r.vehicle_type || "").toString()
                        const tt = (r.ticket_type || "").toString()
                        const base = parseInt(r.base_fee || 0)
                        const dur = (r.duration_minutes === null || r.duration_minutes === undefined) ? -1 : parseInt(r.duration_minutes)
                        const inc = (r.incremental_fee === null || r.incremental_fee === undefined) ? -1 : parseInt(r.incremental_fee)
                        const cap = (r.max_daily_fee === null || r.max_daily_fee === undefined) ? -1 : parseInt(r.max_daily_fee)
                        const disc = (r.discount_percentage === null || r.discount_percentage === undefined) ? 0 : parseFloat(r.discount_percentage)
                        const grace = (r.grace_period === null || r.grace_period === undefined) ? 0 : parseInt(r.grace_period)
                        const desc = (r.description || "").toString()
                        const st = (r.start_time || "").toString()
                        const et = (r.end_time || "").toString()
                        try { console.log('[AdminPricingActions] Upsert row', i, vtNorm, tt, 'base', base, 'dur', dur, 'cap', cap) } catch(e) {}
                        const okRow = repo.upsertPricingRow(vtNorm, tt, base,
                                                             dur, inc, cap,
                                                             disc, grace,
                                                             desc, st, et)
                        try { console.log('[AdminPricingActions] upsertPricingRow returned:', okRow) } catch(e) {}
                        if (okRow) savedCount++
                    }
                    ok = savedCount > 0
                    try { console.log('[AdminPricingActions] Saved rows count:', savedCount) } catch(e) {}
                } else {
                    try { console.log('[AdminPricingActions] Not an array JSON or missing repo.upsertPricingRow; aborting save.') } catch(e) {}
                    ok = false
                }
            } catch (e) {
                // JSON không hợp lệ
                try { console.log('[AdminPricingActions] JSON parse error:', e) } catch(e2) {}
                ok = false
            }
            if (notify) notify(ok ? "Đã lưu bảng giá" : "Không thể lưu bảng giá")
            // Reset trigger
            adminPage.triggerSavePricing = false
        }
        // Nhấn Xóa: trả về mặc định
        function onTriggerDeletePricingChanged() {
            if (!adminPage.triggerDeletePricing) return
            resetTableToDefaults()
            if (notify) notify("Đã đặt lại bảng giá mặc định")
        }
        // Nhấn Thêm: đặt preset theo loại xe (ví dụ: Xe máy)
        function onTriggerAddPricingChanged() {
            if (!adminPage.triggerAddPricing) return
            // Có thể điều chỉnh theo combobox vehicle
            const veh = adminPage.pricingVehicleCombo.currentText
            if (veh === "Xe máy") {
                // ví dụ giảm nhẹ min cho vé giờ
                pricingLogic.setMin("motorbike", "hour", "5000")
            } else {
                pricingLogic.setMin("car", "hour", "20000")
            }
            if (notify) notify("Đã áp dụng preset theo " + veh)
        }
    }

    // Tự động tải cấu hình đã lưu khi mở app
    Component.onCompleted: {
        loadFromDbForVehicle("Xe máy")
        loadFromDbForVehicle("Ô tô")
    }
}
