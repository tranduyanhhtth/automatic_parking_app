import QtQuick

// Logic tách riêng cho phần Bảng giá trong Admin
// - Lưu trữ tạm thời min/max cho từng loại vé và loại xe (Xe máy/Ô tô)
// - Cho phép UI (ui.qml) đọc/ghi qua hàm getMin/getMax/setMin/setMax
// - Có thể mở rộng để load/save với C++ repo khi cần
Item {
    id: adminPricingLogic

    // Lưu trữ ở dạng JS object: { motorbike: { key: { min: "", max: "" } }, car: { ... } }
    property var table: ({
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

    // Lấy giá trị min/max cho UI hiển thị
    function getMin(vehicle, key) {
        return (table[vehicle] && table[vehicle][key]) ? table[vehicle][key].min : "";
    }
    function getMax(vehicle, key) {
        return (table[vehicle] && table[vehicle][key]) ? table[vehicle][key].max : "";
    }

    // Ghi khi admin sửa trên UI
    function setMin(vehicle, key, v) {
        if (!table[vehicle]) table[vehicle] = {};
        if (!table[vehicle][key]) table[vehicle][key] = { min: "", max: "" };
        table[vehicle][key].min = v;
    }
    function setMax(vehicle, key, v) {
        if (!table[vehicle]) table[vehicle] = {};
        if (!table[vehicle][key]) table[vehicle][key] = { min: "", max: "" };
        table[vehicle][key].max = v;
    }

    // Xuất toàn bộ bảng giá (có thể dùng để lưu vào repo/savePricingJson)
    function exportJson() {
        return JSON.stringify(table);
    }
}
