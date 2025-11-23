import QtQuick

Item {
    id: rfidCardsLogic
    property Item adminPage
    property var notify
    property var repoRef
    // Tránh spam thông báo khi prefill cùng 1 thẻ nhiều lần
    property string lastNotifiedExistingRfid: ""
    // Helper đơn giản (ưu tiên repoRef)
    function rRepo() { return repoRef ? repoRef : (typeof repo !== 'undefined' ? repo : null) }

    // UI bindings (set by AdminPage): fields and list model
    property Item tfRfid
    property Item cbVehicle
    property Item cbTicket
    property Item cbStatus
    property Item tfDesc
    property Item tfName
    property Item tfPlate
    property Item tfPhone
    property Item tfDisc
    property alias listModel: listModel

    // Inputs from UI
    property string scannedRfid: ""
    property bool triggerSave: false
    property bool triggerRefresh: false
    property bool triggerDelete: false
    property bool triggerMarkLost: false
    property bool triggerMarkDamaged: false

    ListModel { id: listModel }

    function refresh() {
        listModel.clear()
        const r = rRepo()
        if (!r || !r.listRfidCards) { console.log('[RfidCardsLogic] refresh: repo/listRfidCards missing'); return }
        const rows = r.listRfidCards('', '', '', 1000, 0) || []
        console.log('[RfidCardsLogic] refresh -> total rows:', rows.length)
        for (let i = 0; i < rows.length; ++i) {
            const it = rows[i]
            listModel.append(it)
        }
    }

    function save() {
        console.log('[RfidCardsLogic] save() entered')
        var debugName = (tfName ? tfName.text : "NULL_TF")
        var debugPlate = (tfPlate ? tfPlate.text : "NULL_TF")
        console.log(">>> DEBUG CHECK: Name to save:", debugName)
        console.log(">>> DEBUG CHECK: Plate to save:", debugPlate)
        const r = rRepo()
        if (!r || !r.upsertRfidCard) { if (notify) notify('Repo RFID chưa sẵn sàng'); return }
        const rfid = (tfRfid?tfRfid.text:scannedRfid) || scannedRfid
        if (!rfid || !rfid.length) { if (notify) notify('Chưa có RFID'); return }
        if(!cbVehicle||!cbTicket||!cbStatus){ if(notify) notify('Thiếu control'); return }
        const vt = cbVehicle.currentIndex === 0 ? 'bike' : 'car'
        const ttMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
        const stMap = ['available','assigned','lost','damaged']
        const tt = ttMap[cbTicket.currentIndex]
        let st = stMap[cbStatus.currentIndex]
        const nameVal = (tfName ? tfName.text : "")
        const plateVal = (tfPlate ? tfPlate.text : "")
        const phoneVal = (tfPhone ? tfPhone.text : "") // <--- Get text
        let existed = false
        let currentDbStatus = ""
        if (r.getRfidCard) {
            const ex = r.getRfidCard(rfid)
            existed = !!(ex && ex.rfid)
            if (ex) currentDbStatus = ex.status
            if (ex && ex.status === 'assigned' && ex.vehicle_type !== vt) {
                if (notify) notify('Không thể đổi loại xe cho thẻ đã được gán')
                    return 
            }
            if (ex && ex.status === 'assigned' && ex.ticket_type !== tt) {
                if (notify) notify('Không thể đổi loại vé cho thẻ đã được gán')
                    return
            }
        }
        // --- NEW LOGIC: Force Available for Subscription Types ---
                const isSubscriptionType = (tt === 'monthly' || tt === 'quarterly' || tt === 'yearly')

                // If attempting to mark as 'assigned' in UI, but it's a subscription type
                // and it wasn't ALREADY assigned in DB, force it back to 'available'.
                if (isSubscriptionType && st === 'assigned') {
                    if (currentDbStatus !== 'assigned') {
                        st = 'available'
                        if (notify) notify('Thẻ vé tháng/quý/năm sẽ tự động chuyển "Assigned" khi bạn tạo Đăng Ký (Subscription). Đã lưu là "Available".')
                    }
                }
        const ok = r.upsertRfidCard(rfid, vt, tt, st, tfDesc.text || '', nameVal, plateVal, phoneVal)
        console.log('[RfidCardsLogic] upsert result existed?', existed, 'ok', ok)
        if (notify) notify(ok ? (existed ? 'Đã cập nhật thẻ' : 'Đã tạo thẻ mới') : 'Không thể lưu thẻ')
        if (ok) {
            lastNotifiedExistingRfid = rfid
            refresh(); prefill(rfid)
            if (adminPage) adminPage.triggerUsersChanged = !adminPage.triggerUsersChanged
        }
    }

    function del() {
        const rfid = tfRfid.text || scannedRfid
        if (!rfid) { if (notify) notify('Chưa có RFID'); return }
        const r = rRepo()
        if (!r || !r.deleteRfidCard) { if (notify) notify('Thiếu hàm xóa'); return }
        // Guard: prevent deleting assigned card at UI level as well
        if (r.getRfidCard) {
            const c = r.getRfidCard(rfid)
            if (c && (c.status === 'assigned' || (c.user_phone && (''+c.user_phone).length))) {
                if (notify) notify('Thẻ đang được gán cho người dùng, không thể xóa')
                return
            }

        }
        console.log('[RfidCardsLogic] deleteRfidCard', rfid)
        const ok = r.deleteRfidCard(rfid)
        console.log('[RfidCardsLogic] delete result', ok)
        if (notify) notify(ok ? 'Đã xóa thẻ' : 'Không thể xóa thẻ')
        if (ok) {
            tfRfid.text=''; tfDesc.text=''; scannedRfid='';
            refresh();
            if (adminPage) adminPage.triggerUsersChanged = !adminPage.triggerUsersChanged
        }
    }

    function changeStatus(newStatus){
        const rfid = tfRfid.text || scannedRfid
        if(!rfid){ if(notify) notify('Chưa có RFID'); return }
        const r = rRepo()
        if(!r || !r.setRfidCardStatus){ if(notify) notify('Thiếu hàm đổi trạng thái'); return }
        console.log('[RfidCardsLogic] setRfidCardStatus', rfid, newStatus)
        const ok = r.setRfidCardStatus(rfid, newStatus)
        console.log('[RfidCardsLogic] status change result', ok)
        if(notify) notify(ok ? ('Đã chuyển trạng thái '+newStatus) : 'Không thể đổi trạng thái')
        if(ok){
            lastNotifiedExistingRfid = rfid
            refresh(); prefill(rfid)
            if (adminPage) adminPage.triggerUsersChanged = !adminPage.triggerUsersChanged
        }
    }

    function prefill(rfid) {
        const r = rRepo()
        if (!rfid || !r || !r.getRfidCard) return
        const card = r.getRfidCard(rfid)
        if (!card || !card.rfid) return
        if (tfRfid && tfRfid.text !== card.rfid) tfRfid.text = card.rfid
        if (cbVehicle) cbVehicle.currentIndex = card.vehicle_type === 'bike' ? 0 : 1
        const ticketMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
        const idx = ticketMap.indexOf(card.ticket_type)
        if (cbTicket && idx >= 0) cbTicket.currentIndex = idx
        const statusMap = ['available','assigned','lost','damaged']
        const stIdx = statusMap.indexOf(card.status)
        if (cbStatus && stIdx >= 0) cbStatus.currentIndex = stIdx
        if (tfName) tfName.text = card.owner_name || ''
        if (tfPlate) tfPlate.text = card.plate || ''
        if (tfPhone) tfPhone.text = card.owner_phone || ''
        if (tfDesc) tfDesc.text = card.description || ''
        if (notify && lastNotifiedExistingRfid !== card.rfid) {
            notify('Thẻ đã tồn tại'+ (card.status ? (' ('+card.status+')') : ''))
            lastNotifiedExistingRfid = card.rfid
        }
    }

    Connections {
        target: adminPage
        function onTriggerCloseChanged() { /* no-op */ }
        function onTriggerUsersChangedChanged(){
            refresh();
            if (tfRfid && tfRfid.text) prefill(tfRfid.text)
        }
        function onPendingSelectRfidIndexChanged() {
            if (!adminPage) return
            const idx = adminPage.pendingSelectRfidIndex
            if (idx === undefined || idx === null) return
            if (!listModel || typeof listModel.count === 'undefined') return
            if (idx < 0 || idx >= listModel.count) return
            const row = listModel.get(idx)
            if (!row) return
            scannedRfid = row.rfid || ''
            lastNotifiedExistingRfid = scannedRfid
            if (tfRfid) tfRfid.text = row.rfid || ''
            if (tfName) tfName.text = row.owner_name || ''
            if (tfPlate) tfPlate.text = row.plate || ''
            if (tfPhone) tfPhone.text = row.owner_phone || ''
            if (cbVehicle) cbVehicle.currentIndex = (row.vehicle_type === 'bike' ? 0 : 1)
            const ticketMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
            const tIdx = ticketMap.indexOf(row.ticket_type || '')
            if (cbTicket && tIdx >= 0) cbTicket.currentIndex = tIdx
            const statusMap = ['available','assigned','lost','damaged']
            const sIdx = statusMap.indexOf(row.status || '')
            if (cbStatus && sIdx >= 0) cbStatus.currentIndex = sIdx
            if (tfDesc) tfDesc.text = row.description || ''
        }
    }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged(){ if (adminPage && adminPage.tabBar.currentIndex === 2) refresh() }
    }

    Connections { 
        target: cardReaderEntrance
        function onRfidScanned(code) { 
            scannedRfid = code; 
            if (tfRfid) { 
                tfRfid.text = code
                prefill(code) 
            } 
        } 
    }
    Connections { 
        target: cardReaderExit
        function onRfidScanned(code) { 
            scannedRfid = code
            if (tfRfid) { 
                tfRfid.text = code
                prefill(code) 
            } 
        } 
    }
    Connections {
        target: tfRfid
        function onTextChanged() {
            if (!tfRfid) return
            const t = tfRfid.text
            if (t && t.length > 0) prefill(t)
        }
    }

    onTriggerRefreshChanged: if (triggerRefresh) { refresh(); triggerRefresh = false }
    onTriggerSaveChanged: {
        console.log("[RfidCardsLogic] triggerSave changed:", triggerSave)
        if (triggerSave) {
            console.log("[RfidCardsLogic] calling save() ...")
            save()
            triggerSave = false
        }
    }

    onTriggerDeleteChanged: if (triggerDelete) { del(); triggerDelete = false }
    onTriggerMarkLostChanged: if (triggerMarkLost) { changeStatus('lost'); triggerMarkLost=false }
    onTriggerMarkDamagedChanged: if (triggerMarkDamaged) { changeStatus('damaged'); triggerMarkDamaged=false }
    Component.onCompleted: refresh()
}
