import QtQuick

// CRUD logic for Subscriptions list: load -> edit -> save
Item {
    id: subCrud
    // References
    property Item adminPage
    property var notify

    // Fetch current subscriptions from DB into ListModel
    function load() {
        if (!adminPage || !adminPage.subscriptionsModel) return
        const model = adminPage.subscriptionsModel
        model.clear()
        if (typeof repo !== 'undefined' && repo.listSubscriptions) {
            const arr = repo.listSubscriptions()
            for (let i = 0; i < arr.length; i++) model.append(arr[i])
        } else if (notify) {
            notify("Không có API listSubscriptions")
        }
    }

    // Save current model rows to DB: upsert user and subscription records
    function saveAll() {
        if (!adminPage || !adminPage.subscriptionsModel) return false
        const model = adminPage.subscriptionsModel
        let ok = true
        for (let i = 0; i < model.count; i++) {
            const row = model.get(i)
            const name = row.full_name || ""
            const plate = row.plate || ""
            const rfid = row.rfid || ""
            const vt = row.vehicle_type || (plate.length > 0 ? (plate.length <= 9 ? "motorbike" : "car") : "motorbike")
            const uid = (repo && repo.upsertUser) ? repo.upsertUser(name, "", rfid, plate, vt) : -1
            if (uid <= 0) { ok = false; continue }
            const plan = row.plan_type || "tháng"
            const start = row.start_date || ""
            const end = row.end_date || ""
            const pay = row.payment_mode || "Trả trước"
            const price = parseInt(row.price || 0)
            let success = false
            if (row.id && repo && repo.updateSubscription) {
                success = repo.updateSubscription(row.id, uid, plate, rfid, plan, start, end, pay, price, row.status || "active")
            } else if (repo && repo.createSubscription) {
                const planNorm = ('' + plan).toLowerCase()
                const ticketType = planNorm.startsWith('th') ? 'monthly' : (planNorm.startsWith('qu') ? 'quarterly' : (planNorm.startsWith('nă') || planNorm.startsWith('ye') ? 'yearly' : planNorm))
                const vtNorm = ('' + vt).toLowerCase()
                const pid = repo.getPricingId ? repo.getPricingId(vtNorm, ticketType) : -1
                const sid = repo.createSubscription(uid, pid, plate, rfid, ticketType, start, end, pay, price, row.status || "active")
                success = sid > 0
                if (success && repo.insertRevenue && price > 0) {
                    repo.insertRevenue(undefined, sid, uid, price, pay, "subscription", "new-from-edit")
                }
            }
            if (!success) ok = false
        }
        return ok
    }

    // Hook up to AdminPage triggers
    Connections {
        target: adminPage
        function onTriggerSubEditChanged() {
            if (!adminPage.triggerSubEdit) return
            adminPage.subEditMode = true
            if (notify) notify("Chế độ chỉnh sửa")
            if (adminPage.subscriptionsModel && adminPage.subscriptionsModel.count === 0) load()
        }
        function onTriggerSubSaveChanged() {
            if (!adminPage.triggerSubSave) return
            const ok = saveAll()
            adminPage.subEditMode = false
            if (notify) notify(ok ? "Đã lưu thay đổi" : "Một số dòng lưu thất bại")
        }
    }
}
