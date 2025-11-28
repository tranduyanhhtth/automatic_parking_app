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
    property Item tfCardNumber
    property alias listModel: listModel

    property var masterList: []
    property string sortColumn: ""
    property string sortDirection: "asc" // "asc" or "desc"
    property bool isProgrammaticUpdate: false

    // Inputs from UI
    property string scannedRfid: ""
    property bool triggerSave: false
    property bool triggerRefresh: false
    property bool triggerDelete: false
    property bool triggerMarkLost: false
    property bool triggerMarkDamaged: false

    ListModel { id: listModel }

    function refresh() {
            const r = rRepo()
            if (!r || !r.listRfidCards) {
                console.log('[RfidCardsLogic] refresh: repo/listRfidCards missing');
                return
            }

            // Fetch all data
            const rows = r.listRfidCards('', '', '', 2000, 0) || []
            console.log('[RfidCardsLogic] refresh -> total rows:', rows.length)

            // Save to master list
            masterList = rows

            // Apply current filters (in case text fields already have text)
            filterList()
        }

        // 2. NEW: Filter logic based on all text fields
    function filterList() {
            listModel.clear()

            // Get search terms
            var sCardNum = (tfCardNumber && tfCardNumber.text) ? tfCardNumber.text.toLowerCase().trim() : ""
            var sRfid  = (tfRfid  && tfRfid.text)  ? tfRfid.text.toLowerCase().trim()  : ""
            var sName  = (tfName  && tfName.text)  ? tfName.text.toLowerCase().trim()  : ""
            var sPlate = (tfPlate && tfPlate.text) ? tfPlate.text.toLowerCase().trim() : ""
            var sPhone = (tfPhone && tfPhone.text) ? tfPhone.text.toLowerCase().trim() : ""

            // Get ComboBox indices
            var idxVehicle = cbVehicle ? cbVehicle.currentIndex : 0
            var idxTicket  = cbTicket ? cbTicket.currentIndex : 0

            // Define Mappings for filtering (Matches the order in UI model minus "All")
            // UI Index 1 ("Xe máy") -> 'bike'
            // UI Index 2 ("Ô tô")   -> 'car'
            var ticketMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']

            // 1. Filter into a temporary array first
            var tempArray = []

            for (var i = 0; i < masterList.length; ++i) {
                var item = masterList[i]
                var iCardNum = (item.card_number || "").toLowerCase()
                var iRfid  = (item.rfid || "").toLowerCase()
                var iName  = (item.owner_name || "").toLowerCase()
                var iPlate = (item.plate || "").toLowerCase()
                var iPhone = (item.owner_phone || "").toLowerCase()

                var match = true
                if (sCardNum.length > 0 && iCardNum.indexOf(sCardNum) === -1) match = false
                if (sRfid.length > 0  && iRfid.indexOf(sRfid) === -1)   match = false
                if (sName.length > 0  && iName.indexOf(sName) === -1)   match = false
                if (sPlate.length > 0 && iPlate.indexOf(sPlate) === -1) match = false
                if (sPhone.length > 0 && iPhone.indexOf(sPhone) === -1) match = false

                // --- NEW: Vehicle Filter ---
                // Index 0 is "All", so we only filter if index > 0
                if (idxVehicle === 1 && item.vehicle_type !== 'bike') match = false
                if (idxVehicle === 2 && item.vehicle_type !== 'car') match = false

                // --- NEW: Ticket Filter ---
                if (idxTicket > 0) {
                    // map index 1 to array index 0
                    var reqTicket = ticketMap[idxTicket - 1]
                    if (item.ticket_type !== reqTicket) match = false
                }

                if (match) {
                    tempArray.push(item)
                }
            }

            // 2. Sort the temporary array
                if (sortColumn !== "") {
                    tempArray.sort(function(a, b) {
                    var valA = (a[sortColumn] || "").toString().toLowerCase()
                    var valB = (b[sortColumn] || "").toString().toLowerCase()
                    if (valA < valB) return sortDirection === "asc" ? -1 : 1
                    if (valA > valB) return sortDirection === "asc" ? 1 : -1
                    return 0
                    })
                }

                    // 3. Add to ListModel
                for (var j = 0; j < tempArray.length; ++j) {
                    listModel.append(tempArray[j])
                }
            }

        // --- ADD THIS NEW FUNCTION ---
        function handleSort(columnName) {
            if (sortColumn === columnName) {
                // Toggle direction
                sortDirection = (sortDirection === "asc" ? "desc" : "asc")
            } else {
                // New column, default to ascending
                sortColumn = columnName
                sortDirection = "asc"
            }
            filterList() // Re-apply filter and sort
        }

    function resetFilters() {
        if (tfCardNumber) tfCardNumber.text = ""
        if (tfRfid) tfRfid.text = ""
        if (tfName) tfName.text = ""
        if (tfPlate) tfPlate.text = ""
        if (tfPhone) tfPhone.text = ""
        if (tfDesc) tfDesc.text = ""
        if (cbVehicle) cbVehicle.currentIndex = 0
        if (cbTicket) cbTicket.currentIndex = 0
        scannedRfid = ""
        filterList()
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
        if (cbVehicle.currentIndex === 0) {
                    if (notify) notify('Vui lòng chọn Loại xe cụ thể (không chọn Tất cả)')
                    return
                }
                if (cbTicket.currentIndex === 0) {
                    if (notify) notify('Vui lòng chọn Loại vé cụ thể (không chọn Tất cả)')
                    return
                }
        const vt = cbVehicle.currentIndex === 1 ? 'bike' : 'car'
        const ttMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
        const stMap = ['available','assigned','lost','damaged']
        const tt = ttMap[cbTicket.currentIndex - 1]
        let st = ['available','assigned','lost','damaged'][cbStatus.currentIndex]
        const nameVal = (tfName ? tfName.text : "")
        const plateVal = (tfPlate ? tfPlate.text : "")
        const phoneVal = (tfPhone ? tfPhone.text : "")
        const descVal = (tfDesc ? tfDesc.text : "")
        const cardNumVal = (tfCardNumber ? tfCardNumber.text : "")
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
        const result = r.upsertRfidCard(rfid, vt, tt, st, descVal, nameVal, plateVal, phoneVal, cardNumVal)
        console.log('[RfidCardsLogic] upsert result:', result)
        if (result === -2) {
        if (notify) notify('Số thẻ đã tồn tại, vui lòng nhập số thẻ khác')
            return
        }
        const ok = (result === 1)
        if (notify) notify(ok ? (existed ? 'Đã cập nhật thẻ' : 'Đã tạo thẻ mới') : 'Không thể lưu thẻ')
        if (ok) {
            lastNotifiedExistingRfid = rfid
            refresh(); /*prefill(rfid)*/
            resetFilters();
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
            //tfRfid.text=''; tfDesc.text=''; scannedRfid='';
            refresh();
            resetFilters();
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
            isProgrammaticUpdate = true

            if (cbVehicle) cbVehicle.currentIndex = card.vehicle_type === 'bike' ? 1 : 2

            const ticketMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
            const idx = ticketMap.indexOf(card.ticket_type)
            if (cbTicket && idx >= 0) cbTicket.currentIndex = idx + 1

            const statusMap = ['available','assigned','lost','damaged']
            const stIdx = statusMap.indexOf(card.status)
            if (cbStatus && stIdx >= 0) cbStatus.currentIndex = stIdx
            if (tfCardNumber) tfCardNumber.text = card.card_number || ''
            if (tfName) tfName.text = card.owner_name || ''
            if (tfPlate) tfPlate.text = card.plate || ''
            if (tfPhone) tfPhone.text = card.owner_phone || ''
            if (tfDesc) tfDesc.text = card.description || ''

            if (notify && lastNotifiedExistingRfid !== card.rfid) {
                lastNotifiedExistingRfid = card.rfid
            }
            isProgrammaticUpdate = false
        }

    Connections {
            target: adminPage
            function onPendingSelectRfidIndexChanged() {
                if (!adminPage) return
                const idx = adminPage.pendingSelectRfidIndex
                if (idx === undefined || idx === null) return

                if (idx === -1) {
                    isProgrammaticUpdate = true
                    if (tfCardNumber) tfCardNumber.text = ""
                    if (tfRfid) tfRfid.text = ""
                    if (tfName) tfName.text = ""
                    if (tfPlate) tfPlate.text = ""
                    if (tfPhone) tfPhone.text = ""
                    // if (cbVehicle) cbVehicle.currentIndex = 0
                    // if (cbTicket) cbTicket.currentIndex = 0
                    isProgrammaticUpdate = false
                    scannedRfid = ""
                    // Reset list to full view (optional, ensures all rows are visible)
                    filterList()
                    return
                }

                if (!listModel || typeof listModel.count === 'undefined') return
                if (idx < 0 || idx >= listModel.count) return

                const row = listModel.get(idx)
                if (!row) return

                // [ADD THIS] Lock the filter before filling text
                isProgrammaticUpdate = true

                scannedRfid = row.rfid || ''
                lastNotifiedExistingRfid = scannedRfid // [cite: 80]

                if (tfCardNumber) tfCardNumber.text = row.card_number || ''
                if (tfRfid) tfRfid.text = row.rfid || ''
                if (tfName) tfName.text = row.owner_name || ''
                if (tfPlate) tfPlate.text = row.plate || ''
                if (tfPhone) tfPhone.text = row.owner_phone || ''

                if (cbVehicle) cbVehicle.currentIndex = (row.vehicle_type === 'bike' ? 1 : 2)
                const ticketMap = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly']
                const tIdx = ticketMap.indexOf(row.ticket_type || '')
                if (cbTicket && tIdx >= 0) cbTicket.currentIndex = tIdx + 1

                const statusMap = ['available','assigned','lost','damaged']
                const sIdx = statusMap.indexOf(row.status || '')
                if (cbStatus && sIdx >= 0) cbStatus.currentIndex = sIdx

                if (tfDesc) tfDesc.text = row.description || '' // [cite: 85]

                // [ADD THIS] Unlock after filling
                isProgrammaticUpdate = false
            }
        }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged(){ if (adminPage && adminPage.tabBar.currentIndex === 2) refresh() }
    }

    // 3. LISTEN TO ALL TEXT FIELDS FOR SEARCH

    Connections {
        target: tfCardNumber
        function onTextChanged() {
            if (isProgrammaticUpdate) return
            filterList()
        }
    }

    Connections {
            target: cbVehicle
            function onCurrentIndexChanged() {
                if (isProgrammaticUpdate) return
                filterList()
            }
        }

        Connections {
            target: cbTicket
            function onCurrentIndexChanged() {
                if (isProgrammaticUpdate) return
                filterList()
            }
        }

    Connections {
            target: tfRfid
            function onTextChanged() {
                if (!tfRfid) return

                // [ADD THIS] If we are filling the box via code, do NOT filter the list
                if (isProgrammaticUpdate) return

                // 1. Filter the list immediately
                filterList() // [cite: 88]

                // 2. Try to prefill details if exact match found
                const t = tfRfid.text
                if (t && t.length > 0) prefill(t) // [cite: 88]
            }
        }

    Connections {
                target: tfName
                function onTextChanged() {
                    // Add this check to prevent filtering when clicking a row
                    if (isProgrammaticUpdate) return
                    filterList()
                }
            }

            Connections {
                target: tfPlate
                function onTextChanged() {
                    // Add this check to prevent filtering when clicking a row
                    if (isProgrammaticUpdate) return
                    filterList()
                }
            }

            Connections {
                target: tfPhone
                function onTextChanged() {
                    // Add this check to prevent filtering when clicking a row
                    if (isProgrammaticUpdate) return
                    filterList()
                }
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
