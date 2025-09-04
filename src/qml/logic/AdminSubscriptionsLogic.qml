import QtQuick

// Logic cho phần Đăng ký vé tháng/quý/năm trong trang Admin
// Gắn với các trigger trong AdminPage.ui.qml để thực hiện hành động (mock)
Item {
    id: adminSubscriptionsLogic
    // Trang UI cần gán: adminPage object
    property Item adminPage
    // Hàm thông báo (truyền từ MainWindow): notify(msg)
    property var notify

    function validate() {
        if (!adminPage) return "Trang Admin chưa sẵn sàng";
        if (!adminPage.subUserCombo.currentText || adminPage.subUserCombo.currentIndex === 0)
            return "Vui lòng chọn người dùng";
        if (!adminPage.subPlateField.text || adminPage.subPlateField.text.length < 5)
            return "Biển số không hợp lệ";
        if (!adminPage.subRfidField.text || adminPage.subRfidField.text.length < 3)
            return "ID thẻ không hợp lệ";
        if (!adminPage.subPriceField.text)
            return "Chưa nhập giá";
        return "";
    }

    // Helpers
    function vehicleTextToCode(txt) {
        const t = (''+txt).toLowerCase()
        if (t.indexOf('xe máy') === 0 || t.indexOf('xemay') === 0 || t === 'bike' || t === 'motorbike') return 'motorbike'
        if (t.indexOf('ô tô') === 0 || t.indexOf('o to') === 0 || t.indexOf('oto') === 0 || t === 'car') return 'car'
        return txt || 'motorbike'
    }
    function planToTicket(planTxt) {
        const p = (''+planTxt).toLowerCase()
        if (p.indexOf('th') === 0 || p.indexOf('month') === 0) return 'monthly'
        if (p.indexOf('qu') === 0 || p.indexOf('quarter') === 0) return 'quarterly'
        if (p.indexOf('nă') === 0 || p.indexOf('ye') === 0 || p.indexOf('year') === 0) return 'yearly'
        return p
    }
    function pad2(n) { return (n < 10 ? '0' + n : '' + n) }
    function addMonths(isoYmd, months) {
        if (!isoYmd || months <= 0) return isoYmd || ''
        const parts = (''+isoYmd).split('-')
        if (parts.length < 3) return isoYmd
        let y = parseInt(parts[0]||'0'); let m = parseInt(parts[1]||'1')-1; let d = parseInt(parts[2]||'1')
        const dt = new Date(y, m, d)
        dt.setMonth(dt.getMonth() + months)
        return dt.getFullYear() + '-' + pad2(dt.getMonth()+1) + '-' + pad2(dt.getDate())
    }
    function updateSuggestions() {
        if (!adminPage) return
        const vehicleCode = vehicleTextToCode(adminPage.subVehicleCombo && adminPage.subVehicleCombo.currentText)
        const ticket = planToTicket(adminPage.subPlanCombo && adminPage.subPlanCombo.currentText)
        // Suggest price from pricing logic (min value)
        try {
            const plKey = ticket === 'monthly' ? 'month' : (ticket === 'quarterly' ? 'quarter' : (ticket === 'yearly' ? 'year' : ''))
            if (plKey && adminPage.pricingLogicRef && adminPage.subPriceField) {
                const v = adminPage.pricingLogicRef.getMin(vehicleCode === 'car' ? 'car' : 'motorbike', plKey)
                if (v && (''+v).length > 0) adminPage.subPriceField.text = '' + v
            }
        } catch (e) { /* ignore */ }
        // Suggest end date from start date
        const start = adminPage.subStartField ? adminPage.subStartField.text : ''
        if (start && adminPage.subEndField) {
            const months = ticket === 'monthly' ? 1 : (ticket === 'quarterly' ? 3 : (ticket === 'yearly' ? 12 : 0))
            if (months > 0) adminPage.subEndField.text = addMonths(start, months)
        }
    }

    // Lắng nghe các trigger từ UI
    Connections {
        target: adminPage
        function onTriggerSubCreateChanged() {
            if (!adminPage.triggerSubCreate) return
            const err = validate();
            if (err) { if (notify) notify(err); return }
            // Gọi repo để lưu đăng ký thật sự
            const name = adminPage.subUserCombo.currentText
            const plate = adminPage.subPlateField.text
            const rfid = adminPage.subRfidField.text
            const vehicleType = (adminPage.subVehicleCombo.currentText === "Xe máy") ? "motorbike" : "car"
            const plan = adminPage.subPlanCombo.currentText.toLowerCase() // "tháng", "quý", "năm" -> tuỳ backend xử lý
                const vehicleType = vehicleTextToCode(adminPage.subVehicleCombo.currentText)
                const plan = adminPage.subPlanCombo.currentText.toLowerCase() // "tháng", "quý", "năm" -> tuỳ backend xử lý
            const payment = adminPage.subPaymentCombo.currentText
            const price = parseInt(adminPage.subPriceField.text || "0") || 0
            // upsert user từ thông tin cơ bản
            var userId = repo && repo.upsertUser ? repo.upsertUser(name, "", rfid, plate, vehicleType) : -1
            if (userId <= 0) { if (notify) notify("Không tạo được người dùng"); return }
            var ticket = (''+plan).toLowerCase()
            if (ticket.indexOf('th')===0) ticket = 'monthly'
            else if (ticket.indexOf('qu')===0) ticket = 'quarterly'
            else if (ticket.indexOf('nă')===0 || ticket.indexOf('ye')===0) ticket = 'yearly'
            // vehicleType must be one of: motorbike | car
            var vtNorm = (''+vehicleType).toLowerCase() === 'xe máy' ? 'motorbike' : ((''+vehicleType).toLowerCase() === 'ô tô' ? 'car' : ((''+vehicleType).toLowerCase()==='bike' ? 'motorbike' : ((''+vehicleType).toLowerCase()==='oto' ? 'car' : ((''+vehicleType).toLowerCase()))))
                var vtNorm = vehicleTextToCode(vehicleType)
            var pid = repo && repo.getPricingId ? repo.getPricingId(vtNorm, ticket) : -1
            var sid = repo && repo.createSubscription ? repo.createSubscription(userId, pid, plate, rfid, ticket, startDate, endDate, payment, price, "active") : -1
            if (sid > 0) {
                // Ghi nhận doanh thu đăng ký
                if (repo && repo.insertRevenue && price > 0) {
                    repo.insertRevenue(undefined, sid, userId, price, payment, "subscription", "")
                }
                if (notify) notify("Đã đăng ký vé " + adminPage.subPlanCombo.currentText + " cho " + name)
            } else {
                if (notify) notify("Lỗi khi tạo đăng ký")
            }
        }
        function onTriggerSubExtendChanged() {
            if (!adminPage.triggerSubExtend) return
            const err = validate();
            if (err) { if (notify) notify(err); return }
            // Đơn giản: tạo thêm một bản ghi subscription mới nối tiếp (tuỳ quy định)
            const name = adminPage.subUserCombo.currentText
            const plate = adminPage.subPlateField.text
            const rfid = adminPage.subRfidField.text
            const vehicleType = (adminPage.subVehicleCombo.currentText === "Xe máy") ? "motorbike" : "car"
                const vehicleType = vehicleTextToCode(adminPage.subVehicleCombo.currentText)
            const startDate = adminPage.subStartField.text
            const endDate = adminPage.subEndField.text
            const payment = adminPage.subPaymentCombo.currentText
            const price = parseInt(adminPage.subPriceField.text || "0") || 0
            var userId = repo && repo.upsertUser ? repo.upsertUser(name, "", rfid, plate, vehicleType) : -1
            if (userId <= 0) { if (notify) notify("Không tạo được người dùng"); return }
            var ticket = (''+plan).toLowerCase()
            if (ticket.indexOf('th')===0) ticket = 'monthly'
            else if (ticket.indexOf('qu')===0) ticket = 'quarterly'
            else if (ticket.indexOf('nă')===0 || ticket.indexOf('ye')===0) ticket = 'yearly'
            var vtNorm = (''+vehicleType).toLowerCase() === 'xe máy' ? 'motorbike' : ((''+vehicleType).toLowerCase() === 'ô tô' ? 'car' : ((''+vehicleType).toLowerCase()==='bike' ? 'motorbike' : ((''+vehicleType).toLowerCase()==='oto' ? 'car' : ((''+vehicleType).toLowerCase()))))
                var vtNorm = vehicleTextToCode(vehicleType)
            var pid = repo && repo.getPricingId ? repo.getPricingId(vtNorm, ticket) : -1
            var sid = repo && repo.createSubscription ? repo.createSubscription(userId, pid, plate, rfid, ticket, startDate, endDate, payment, price, "active") : -1
            if (sid > 0) {
                if (repo && repo.insertRevenue && price > 0) {
                    repo.insertRevenue(undefined, sid, userId, price, payment, "subscription", "extend")
                }
                if (notify) notify("Đã gia hạn vé " + adminPage.subPlanCombo.currentText + " cho " + name)
            } else {
                if (notify) notify("Lỗi khi gia hạn")
            }
        }
        function onTriggerSubLostDeleteChanged() {
            if (!adminPage.triggerSubLostDelete) return
            if (!adminPage.subRfidField.text) { if (notify) notify("Nhập ID thẻ để xóa"); return }
            // Tác vụ xóa thẻ mất: có thể đánh dấu subscription inactive (cần API riêng trong repo nếu muốn đầy đủ)
            if (notify) notify("Đã ghi nhận thẻ mất: " + adminPage.subRfidField.text)
        }
    }
}

        // React to UI changes to auto-suggest price and end date
        Connections {
            target: adminPage ? adminPage.subPlanCombo : null
            function onCurrentIndexChanged() { updateSuggestions() }
            function onCurrentTextChanged() { updateSuggestions() }
        }
        Connections {
            target: adminPage ? adminPage.subVehicleCombo : null
            function onCurrentIndexChanged() { updateSuggestions() }
            function onCurrentTextChanged() { updateSuggestions() }
        }
        Connections {
            target: adminPage ? adminPage.subStartField : null
            function onTextChanged() { updateSuggestions() }
        }
