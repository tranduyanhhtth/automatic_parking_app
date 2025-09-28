import QtQuick

Item {
    id: usersLogic
    property Item adminPage
    property var notify
    // Prefer explicit repo ref like RfidCardsLogic to avoid global dependency
    property var repoRef
    function rRepo(){ return repoRef ? repoRef : (typeof repo !== 'undefined' ? repo : null) }

    // Data model for users table
    ListModel { id: usersModel }
    property alias listModel: usersModel
    property int selectedUserId: -1

    function normalizeVehicleLabel(txt) {
        var t = (''+txt).toLowerCase()
        if (t.indexOf('ô') === 0 || t.indexOf('o t') === 0 || t.indexOf('car') === 0) return 'car'
        return 'bike'
    }

    function refresh() {
        usersModel.clear()
        const r = rRepo()
        if (!r || !r.listUsers) { console.log('[UsersLogic] refresh: repo/listUsers missing'); return }
        var rows = r.listUsers(500,0) || []
        console.log('[UsersLogic] refresh -> rows:', rows.length)
        for (var i=0;i<rows.length;i++) usersModel.append(rows[i])
    }

    function selectUser(id, full_name, phone, rfid, plate, vehicle_type) {
        selectedUserId = id
        if (!adminPage) return
        if (adminPage.userName) adminPage.userName.text = full_name
        if (adminPage.userPhone) adminPage.userPhone.text = phone
        if (adminPage.userRfid) adminPage.userRfid.text = rfid
        if (adminPage.userPlate) adminPage.userPlate.text = plate
        if (adminPage.userVehicleType) adminPage.userVehicleType.currentIndex = (vehicle_type === 'car'?1:0)
    }

    function addOrUpdate(isUpdate) {
        if (!adminPage) { console.log('[UsersLogic] addOrUpdate: adminPage undefined'); return }
        // Resolve field objects once with safe fallback
        var fName = adminPage.userName ? adminPage.userName : null
        var fPhone = adminPage.userPhone ? adminPage.userPhone : null
        var fRfid = adminPage.userRfid ? adminPage.userRfid : null
        var fPlate = adminPage.userPlate ? adminPage.userPlate : null
        var fVt = adminPage.userVehicleType ? adminPage.userVehicleType : null
        if(!fName || !fPhone || !fRfid || !fPlate || !fVt){
            console.log('[UsersLogic] Missing field refs', {hasName:!!fName, hasPhone:!!fPhone, hasRfid:!!fRfid, hasPlate:!!fPlate, hasVehicle:!!fVt})
            if(notify) notify('Thiếu control form user');
            return
        }
        var name = fName.text
        if (!name || name.length < 2) { if (notify) notify('Tên không hợp lệ'); return }
        var phone = fPhone.text
        if (!phone || !phone.length) { if (notify) notify('Vui lòng nhập số điện thoại'); return }
        var rfid = fRfid.text
        if (!rfid || !rfid.length) { if (notify) notify('Vui lòng nhập ID thẻ'); return }

        var plate = fPlate.text
        if (!plate || !plate.length) { if (notify) notify('Vui lòng nhập biển số xe'); return }

        var vt = normalizeVehicleLabel(fVt.currentText)
        const r = rRepo()
        // --- STRICT VALIDATION: Check the RFID card BEFORE creating the user ---
            var card = r.getRfidCard(rfid)
            if (!card || !card.rfid) {
                if (notify) notify("Lỗi: Thẻ RFID '" + rfid + "' không tồn tại. Vui lòng tạo thẻ trước khi gán.")
                return; // Stop the entire process
            }
            if (card.status !== 'available') {
                if (notify) notify("Lỗi: Thẻ RFID '" + rfid + "' đã được gán hoặc không khả dụng.")
                return; // Stop the entire process
            }
            // --- End of strict validation ---
        if (!r || !r.upsertUser) { if (notify) notify('Thiếu repo.upsertUser'); return }
        console.log('[UsersLogic] upsertUser request', {name:name, phone:phone, rfid:rfid, plate:plate, vt:vt})
        var uid = r.upsertUser(name, phone, rfid, plate, vt)
        console.log('[UsersLogic] upsertUser result id=', uid)
        if (uid > 0) {
            // Gán/Chuyển RFID card cho user hiện tại (xóa ràng buộc cũ nếu có)
            r.assignRfidCard(rfid, uid)
                   if (r.upsertRfidCard) {
                       r.upsertRfidCard(card.rfid, card.vehicle_type, card.ticket_type, "assigned", card.description || '')
                       console.log("[UsersLogic] RFID card " + card.rfid + " was assigned and its status updated to 'assigned'.")
                   }
                   if (notify) notify(isUpdate ? 'Đã cập nhật user và gán lại thẻ' : 'Đã thêm user và gán thẻ')
                   refresh(); // Refresh the user list to show changes
               }
        else {
            if (notify) notify('Lỗi lưu user')
        }
    }

    function softDelete() {
        if (selectedUserId <= 0) { if (notify) notify('Chưa chọn user'); return }
        const r = rRepo()
        if (!r || !r.softDeleteUser) { if (notify) notify('Thiếu repo.softDeleteUser'); return }
        console.log('[UsersLogic] delete userId=', selectedUserId)
        var ok = r.softDeleteUser(selectedUserId)
        console.log('[UsersLogic] delete result', ok)
        if (notify) notify(ok ? 'Đã xóa user và đăng ký liên quan' : 'Không thể xóa user')
        if (ok) {
            refresh();
            selectedUserId = -1;
            if(adminPage) adminPage.triggerUsersChanged = !adminPage.triggerUsersChanged
        }
    }

    Connections {
        target: adminPage
        function onTriggerAddUserChanged() { if (adminPage.triggerAddUser) { addOrUpdate(false); adminPage.triggerAddUser = false } }
        function onTriggerUpdateUserChanged() { if (adminPage.triggerUpdateUser) { addOrUpdate(true); adminPage.triggerUpdateUser = false } }
        function onTriggerDeleteUserChanged() { if (adminPage.triggerDeleteUser) { softDelete(); adminPage.triggerDeleteUser = false } }
        function onTriggerUsersChangedChanged(){ refresh() }
        function onLoginVisibleChanged(){ if(!adminPage.loginVisible && adminPage.tabBar && adminPage.tabBar.currentIndex===3){ refresh() } }
        function onPendingSelectUserIndexChanged(){
            var idx = adminPage.pendingSelectUserIndex
            if(idx>=0 && idx < usersModel.count){
                var r = usersModel.get(idx)
                selectUser(r.id, r.full_name, r.phone, r.rfid, r.plate, r.vehicle_type)
            }
        }
    }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged(){ if(adminPage && adminPage.tabBar.currentIndex===3) refresh() }
    }

    Component.onCompleted: refresh()
}
