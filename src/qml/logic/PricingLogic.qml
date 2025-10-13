import QtQuick
import QtQml.Models

Item {
    id: root
    width: 0
    height: 0

    // Edit mode for table
    property bool editMode: false
    // Bind this from UI: "bike" or "car"
    property string selectedVehicle: "bike"
    // JSON payload after save
    property string jsonPayload: "[]"
    // UI-only trigger: when set to true from .ui.qml, perform save and reset.
    property bool requestSave: false

    // Expose the pricing model
    property var pricingModel: model
    // Filtered view per selected vehicle for UI binding
    property var filteredModel: filtered

    // Signal emitted when saved with JSON payload
    signal saved(string json)

    // The pricing data model for bike and car
    ListModel {
        id: model
        // Bike (Xe máy)
    ListElement { vehicle_type: "bike"; ticket_type: "hourly";      ticket_label: "Vé giờ (lượt)";       description: "Mỗi giờ đầu tiên (tối đa 60 phút/lượt); quá giờ tính thêm lượt mới.";               price_hint: "5.000 - 8.000/lượt"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "bike"; ticket_type: "daily_day";   ticket_label: "Vé ngày (ban ngày)";  description: "Từ 6h-18h, tối đa 12 giờ; vượt quá tính thêm ngày.";                                 price_hint: "20.000 - 30.000/ngày"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "bike"; ticket_type: "daily_night"; ticket_label: "Vé ngày (ban đêm)";  description: "Từ 18h-6h, tối đa 12 giờ; qua đêm tính bằng 6 lượt.";                                price_hint: "25.000 - 40.000/ngày"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "bike"; ticket_type: "overnight";   ticket_label: "Vé qua đêm";         description: "Từ 18h hôm trước đến 6h hôm sau (tính 6 lượt).";                                   price_hint: "30.000 - 48.000/đêm"; price_value: ""; grace_hint: "phút"; grace_value: "0" }
    ListElement { vehicle_type: "bike"; ticket_type: "monthly";     ticket_label: "Vé tháng";            description: "Đăng ký 1 tháng (30 ngày), sử dụng không giới hạn lượt ra vào.";                      price_hint: "200.000 - 300.000/tháng"; price_value: ""; grace_hint: "-"; grace_value: "0" }
    ListElement { vehicle_type: "bike"; ticket_type: "quarterly";   ticket_label: "Vé quý (3 tháng)";    description: "Đăng ký 3 tháng, giảm 10% so với tháng lẻ.";                                             price_hint: "540.000 - 810.000/quý"; price_value: ""; grace_hint: "-"; grace_value: "0" }
    ListElement { vehicle_type: "bike"; ticket_type: "yearly";      ticket_label: "Vé năm";              description: "Đăng ký 12 tháng, giảm 20% so với tháng lẻ.";                                           price_hint: "1.920.000 - 2.880.000/năm"; price_value: ""; grace_hint: "-"; grace_value: "0" }
        // Car (<9 seats)
    ListElement { vehicle_type: "car"; ticket_type: "hourly";      ticket_label: "Vé giờ (lượt)";       description: "Mỗi giờ đầu tiên (tối đa 60 phút/lượt); quá giờ tính thêm lượt mới.";               price_hint: "20.000 - 30.000/lượt"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "car"; ticket_type: "daily_day";   ticket_label: "Vé ngày (ban ngày)";  description: "Từ 6h-18h, tối đa 12 giờ; vượt quá tính thêm ngày (theo block 4 giờ).";               price_hint: "150.000 - 240.000/ngày"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "car"; ticket_type: "daily_night"; ticket_label: "Vé ngày (ban đêm)";  description: "Từ 18h-6h, tối đa 12 giờ; qua đêm tính bằng 6 lượt.";                                price_hint: "180.000 - 300.000/ngày"; price_value: ""; grace_hint: "phút"; grace_value: "15" }
    ListElement { vehicle_type: "car"; ticket_type: "overnight";   ticket_label: "Vé qua đêm";         description: "Từ 18h hôm trước đến 6h hôm sau (tính 6 lượt).";                                     price_hint: "120.000 - 180.000/đêm"; price_value: ""; grace_hint: "phút"; grace_value: "0" }
    ListElement { vehicle_type: "car"; ticket_type: "monthly";     ticket_label: "Vé tháng";            description: "Đăng ký 1 tháng (30 ngày), sử dụng không giới hạn lượt ra vào.";                      price_hint: "1.500.000 - 2.000.000/tháng"; price_value: ""; grace_hint: "-"; grace_value: "0" }
    ListElement { vehicle_type: "car"; ticket_type: "quarterly";   ticket_label: "Vé quý (3 tháng)";    description: "Đăng ký 3 tháng, giảm 10% so với tháng lẻ.";                                             price_hint: "4.050.000 - 5.400.000/quý"; price_value: ""; grace_hint: "-"; grace_value: "0" }
    ListElement { vehicle_type: "car"; ticket_type: "yearly";      ticket_label: "Vé năm";              description: "Đăng ký 12 tháng, giảm 20% so với tháng lẻ.";                                           price_hint: "14.400.000 - 19.200.000/năm"; price_value: ""; grace_hint: "-"; grace_value: "0" }
    }

    // Filtered model used by UI
    ListModel {
        id: filtered
    }

    // Prefill price_value from DB if available
    function prefillFromDb() {
        if (typeof repo === 'undefined' || !repo.getLatestPricing)
            return;
        var updated = false;
        for (var i = 0; i < model.count; ++i) {
            var it = model.get(i)
            try {
                var m = repo.getLatestPricing(it.vehicle_type, it.ticket_type)
                if (m) {
                    if (m.base_fee !== undefined && m.base_fee !== null) {
                        var val = m.base_fee
                        if (typeof val === 'object' && val.hasOwnProperty('toString')) val = val.toString()
                        // Convert QVariant to int then string
                        var num = parseInt(val)
                        if (!isNaN(num) && num >= 0) {
                            model.setProperty(i, 'price_value', '' + num)
                            updated = true
                        }
                    }
                    if (m.grace_period !== undefined && m.grace_period !== null) {
                        var gval = m.grace_period
                        if (typeof gval === 'object' && gval.hasOwnProperty('toString')) gval = gval.toString()
                        var gnum = parseInt(gval)
                        if (!isNaN(gnum) && gnum >= 0) {
                            model.setProperty(i, 'grace_value', '' + gnum)
                            updated = true
                        }
                    }
                }
            } catch(e) {
                // ignore per row errors
            }
        }
        if (updated)
            updateFiltered()
    }

    function updateFiltered() {
        filtered.clear()
        for (var i = 0; i < model.count; ++i) {
            var it = model.get(i)
            if (it.vehicle_type !== selectedVehicle) continue
            filtered.append({
                vehicle_type: it.vehicle_type,
                ticket_type: it.ticket_type,
                ticket_label: it.ticket_label,
                description: it.description,
                price_hint: it.price_hint,
                price_value: it.price_value,
                grace_hint: it.grace_hint,
                grace_value: it.grace_value
            })
        }
    }

    function setPriceFor(ticketType, value) {
            // Update the source model
            for (var i = 0; i < model.count; ++i) {
                var it = model.get(i)
                if (it.vehicle_type === selectedVehicle && it.ticket_type === ticketType) {
                    model.setProperty(i, 'price_value', value)
                    break
                }
            }
            // Also update the filtered model directly to avoid a full refresh
            for (var j = 0; j < filtered.count; ++j) {
                if (filtered.get(j).ticket_type === ticketType) {
                    filtered.setProperty(j, 'price_value', value)
                    break
                }
            }
            //updateFiltered()
        }

    function setGraceFor(ticketType, value) {
            // Update the source model
            for (var i = 0; i < model.count; ++i) {
                var it = model.get(i)
                if (it.vehicle_type === selectedVehicle && it.ticket_type === ticketType) {
                    model.setProperty(i, 'grace_value', value)
                    break
                }
            }
            // Also update the filtered model directly
            for (var j = 0; j < filtered.count; ++j) {
                if (filtered.get(j).ticket_type === ticketType) {
                    filtered.setProperty(j, 'grace_value', value)
                    break
                }
            }
            //updateFiltered() here
        }

    onSelectedVehicleChanged: updateFiltered()
    Component.onCompleted: {
        prefillFromDb()
        updateFiltered()
    }

    function mapDurationMinutes(ticket) {
        if (ticket === "hourly") return 60;
        if (ticket === "daily_day" || ticket === "daily_night") return 12 * 60;
        return null;
    }

    function mapStartTime(ticket) {
        if (ticket === "daily_day") return "06:00";
        if (ticket === "daily_night") return "18:00";
        return null;
    }

    function mapEndTime(ticket) {
        if (ticket === "daily_day") return "18:00";
        if (ticket === "daily_night") return "06:00";
        return null;
    }

    function mapDiscount(ticket) {
        if (ticket === "quarterly") return 10;
        if (ticket === "yearly") return 20;
        return 0;
    }

    function sanitizeInt(value) {
        if (value === null || value === undefined)
            return 0
        var str = "" + value
        var digits = str.replace(/[^0-9]/g, "")
        if (!digits.length)
            return 0
        var parsed = parseInt(digits)
        return isNaN(parsed) ? 0 : parsed
    }

    function buildJsonAll() {
        var arr = []
        for (var i = 0; i < model.count; ++i) {
            var it = model.get(i)
            arr.push({
                vehicle_type: it.vehicle_type,
                ticket_type: it.ticket_type,
                ticket_label: it.ticket_label,
                description: it.description,
                base_fee: sanitizeInt(it.price_value),
                duration_minutes: mapDurationMinutes(it.ticket_type),
                incremental_fee: null,
                max_daily_fee: null,
                discount_percentage: mapDiscount(it.ticket_type),
                grace_period: sanitizeInt(it.grace_value),
                start_time: mapStartTime(it.ticket_type),
                end_time: mapEndTime(it.ticket_type)
            })
        }
        return JSON.stringify(arr, null, 2)
    }

    function buildJsonForSelectedVehicle() {
        var arr = []
        for (var i = 0; i < model.count; ++i) {
            var it = model.get(i)
            if (it.vehicle_type !== selectedVehicle)
                continue
            var feeNum = sanitizeInt(it.price_value)
            arr.push({
                vehicle_type: it.vehicle_type,
                ticket_type: it.ticket_type,
                ticket_label: it.ticket_label,
                description: it.description,
                base_fee: feeNum,
                duration_minutes: mapDurationMinutes(it.ticket_type),
                incremental_fee: null,
                max_daily_fee: null,
                discount_percentage: mapDiscount(it.ticket_type),
                grace_period: sanitizeInt(it.grace_value),
                start_time: mapStartTime(it.ticket_type),
                end_time: mapEndTime(it.ticket_type)
            })
        }
        return JSON.stringify(arr, null, 2)
    }

    function save() {
        // Save only current vehicle rows by default
        jsonPayload = buildJsonForSelectedVehicle()
        try {
            console.log('[PricingLogic] Save JSON length:', jsonPayload.length, 'vehicle:', selectedVehicle)
        } catch(e) {}
        editMode = false
        saved(jsonPayload)
    }

    onRequestSaveChanged: {
        if (requestSave) {
            save()
            requestSave = false
        }
    }
    
    // Wrapper function for AdminPage.ui.qml to avoid JavaScript if statements
    function onPriceFieldChanged(ticketType, value) {
        if (editMode) {
            setPriceFor(ticketType, value);
        }
    }

    function onGraceFieldChanged(ticketType, value) {
        if (editMode) {
            setGraceFor(ticketType, value);
        }
    }
}
