import QtQuick

// Logic cho phần Đăng ký vé tháng/quý/năm trong trang Admin
// Gắn với các trigger trong AdminPage.ui.qml để thực hiện hành động
Item {
    id: adminSubscriptionsLogic
    // Trang UI cần gán: adminPage object
    property Item adminPage
    // Hàm thông báo (truyền từ MainWindow): notify(msg)
    property var notify

    function validate() {
        if (!adminPage) return "Trang Admin chưa sẵn sàng";
        if (!adminPage.subUser || adminPage.subUser.currentIndex < 0)
            return "Vui lòng chọn người dùng";
        if (!adminPage.subPlate || !adminPage.subPlate.text || adminPage.subPlate.text.length < 5)
            return "Biển số không hợp lệ";
        if (!adminPage.subRfid || !adminPage.subRfid.text || adminPage.subRfid.text.length < 3)
            return "ID thẻ không hợp lệ";
        if (!adminPage.subPrice || !adminPage.subPrice.text)
            return "Chưa nhập giá";
        return "";
    }

    // Helpers
    function vehicleTextToCode(txt) {
        const t = (''+txt).toLowerCase()
        if (t.indexOf('xe máy') === 0 || t.indexOf('xemay') === 0 || t === 'bike' || t === 'motorbike') return 'motorbike'
        if (t.indexOf('ô tô') === 0 || t.indexOf('o to') === 0 || t.indexOf('oto') === 0 || t === 'car') return 'car'
        return 'motorbike'
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
        const ticket = planToTicket(adminPage.subPlan && adminPage.subPlan.currentText)
        // Gợi ý ngày kết thúc dựa vào ngày bắt đầu và gói
        const start = adminPage.subStart ? adminPage.subStart.text : ''
        if (start && adminPage.subEnd) {
            const months = ticket === 'monthly' ? 1 : (ticket === 'quarterly' ? 3 : (ticket === 'yearly' ? 12 : 0))
            if (months > 0) adminPage.subEnd.text = addMonths(start, months)
        }
    }

    // Lắng nghe các trigger từ UI
    Connections {
        target: adminPage
        function onTriggerSubCreateChanged() {
            if (!adminPage.triggerSubCreate) return
            const err = validate();
            if (err) { if (notify) notify(err); return }
            const name = adminPage.subUser.currentText
            const plate = adminPage.subPlate.text
            const rfid = adminPage.subRfid.text
            const planTxt = adminPage.subPlan.currentText
            const startDate = adminPage.subStart.text
            const endDate = adminPage.subEnd.text
            const payment = adminPage.subPayment.currentText
            const price = parseInt(adminPage.subPrice.text || '0') || 0
            // upsert user
            const vtDefault = 'motorbike'
            var userId = (typeof repo !== 'undefined' && repo.upsertUser) ? repo.upsertUser(name, '', rfid, plate, vtDefault) : -1
            if (userId <= 0) { if (notify) notify('Không tạo được người dùng'); return }
            var ticket = planToTicket(planTxt)
            var pid = (typeof repo !== 'undefined' && repo.getPricingId) ? repo.getPricingId(vtDefault, ticket) : -1
            var sid = (typeof repo !== 'undefined' && repo.createSubscription) ? repo.createSubscription(userId, pid, plate, rfid, ticket, startDate, endDate, payment, price, 'active') : -1
            if (sid > 0) {
                if (typeof repo !== 'undefined' && repo.insertRevenue && price > 0) {
                    repo.insertRevenue(undefined, sid, userId, price, payment, 'subscription', '')
                }
                if (notify) notify('Đã đăng ký vé ' + planTxt + ' cho ' + name)
            } else {
                if (notify) notify('Lỗi khi tạo đăng ký')
            }
        }
        function onTriggerSubExtendChanged() {
            if (!adminPage.triggerSubExtend) return
            const err = validate();
            if (err) { if (notify) notify(err); return }
            const name = adminPage.subUser.currentText
            const plate = adminPage.subPlate.text
            const rfid = adminPage.subRfid.text
            const planTxt = adminPage.subPlan.currentText
            const startDate = adminPage.subStart.text
            const endDate = adminPage.subEnd.text
            const payment = adminPage.subPayment.currentText
            const price = parseInt(adminPage.subPrice.text || '0') || 0
            const vtDefault = 'motorbike'
            var userId = (typeof repo !== 'undefined' && repo.upsertUser) ? repo.upsertUser(name, '', rfid, plate, vtDefault) : -1
            if (userId <= 0) { if (notify) notify('Không tạo được người dùng'); return }
            var ticket = planToTicket(planTxt)
            var pid = (typeof repo !== 'undefined' && repo.getPricingId) ? repo.getPricingId(vtDefault, ticket) : -1
            var sid = (typeof repo !== 'undefined' && repo.createSubscription) ? repo.createSubscription(userId, pid, plate, rfid, ticket, startDate, endDate, payment, price, 'active') : -1
            if (sid > 0) {
                if (typeof repo !== 'undefined' && repo.insertRevenue && price > 0) {
                    repo.insertRevenue(undefined, sid, userId, price, payment, 'subscription', 'extend')
                }
                if (notify) notify('Đã gia hạn vé ' + planTxt + ' cho ' + name)
            } else {
                if (notify) notify('Lỗi khi gia hạn')
            }
        }
        function onTriggerSubLostDeleteChanged() {
            if (!adminPage.triggerSubLostDelete) return
            if (!adminPage.subRfid || !adminPage.subRfid.text) { if (notify) notify('Nhập ID thẻ để xóa'); return }
            if (notify) notify('Đã ghi nhận thẻ mất: ' + adminPage.subRfid.text)
        }
    }

    // Gợi ý khi người dùng đổi gói hoặc ngày bắt đầu
    Connections {
        target: adminPage ? adminPage.subPlan : null
        function onCurrentIndexChanged() { updateSuggestions() }
        function onCurrentTextChanged() { updateSuggestions() }
    }
    Connections {
        target: adminPage ? adminPage.subStart : null
        function onTextChanged() { updateSuggestions() }
    }
}
