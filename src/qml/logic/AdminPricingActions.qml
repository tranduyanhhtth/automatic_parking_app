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
        return (label === "Xe máy") ? "motorbike" : "car";
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
            if (!adminPage.triggerSavePricing) return
            if (!pricingLogic) { if (notify) notify("Thiếu logic bảng giá"); return }
            // Ghi dưới ticket type ổn định 'admin_table' để không ảnh hưởng công thức tính phí runtime
            const vt = vehicleKey(adminPage.pricingVehicleCombo.currentText)
            const wrapped = {}
            wrapped[vt] = pricingLogic.table[vt]
            const json = JSON.stringify(wrapped)
            const ptype = "admin_table"
            let ok = false
            try {
                if (typeof repo !== 'undefined' && repo.savePricingJson) {
                    ok = repo.savePricingJson(vt, ptype, json, "admin ui")
                }
            } catch(e) {
                ok = false
            }
            if (notify) notify(ok ? "Đã lưu bảng giá" : "Đã cập nhật bảng giá (tạm) — không tìm thấy repo")
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
