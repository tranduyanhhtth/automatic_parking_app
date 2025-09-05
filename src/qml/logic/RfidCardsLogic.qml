import QtQuick

Item {
    id: rfidCardsLogic
    property Item adminPage
    property var notify

    // UI bindings (set by AdminPage): fields and list model
    property alias tfRfid: tfRfid
    property alias cbVehicle: cbVehicle
    property alias cbTicket: cbTicket
    property alias cbStatus: cbStatus
    property alias tfDesc: tfDesc
    property alias listModel: listModel

    // Inputs from UI
    property string scannedRfid: ""
    property bool triggerSave: false
    property bool triggerRefresh: false

    ListModel { id: listModel }

    function refresh() {
        listModel.clear()
        if (typeof repo === 'undefined' || !repo.listRfidCards) return
        const vt = cbVehicle.currentIndex === 0 ? '' : (cbVehicle.currentIndex === 1 ? 'bike' : 'car')
        const tt = '' // filter later if needed
        const st = ''
        const rows = repo.listRfidCards(st, vt, tt, 500, 0) || []
        for (let i = 0; i < rows.length; ++i) {
            const r = rows[i]
            listModel.append(r)
        }
    }

    function save() {
        if (typeof repo === 'undefined' || !repo.upsertRfidCard) { if (notify) notify('Thiếu repo'); return }
        const rfid = tfRfid.text || scannedRfid
        if (!rfid || !rfid.length) { if (notify) notify('Chưa có RFID'); return }
        const vt = cbVehicle.currentIndex === 2 ? 'car' : 'bike'
        const tt = ['hourly','daily_day','daily_night','overnight','monthly','quarterly','yearly'][cbTicket.currentIndex]
        const st = ['available','assigned','lost','damaged'][cbStatus.currentIndex]
        const ok = repo.upsertRfidCard(rfid, vt, tt, st, tfDesc.text || '')
        if (notify) notify(ok ? 'Đã lưu thẻ' : 'Không thể lưu thẻ')
        if (ok) refresh()
    }

    Connections {
        target: adminPage
        function onTriggerCloseChanged() { /* no-op */ }
    }

    Connections {
        target: cardReaderEntrance
        function onRfidScanned(code) { rfidCardsLogic.scannedRfid = code; if (rfidCardsLogic.tfRfid) rfidCardsLogic.tfRfid.text = code }
    }
    Connections {
        target: cardReaderExit
        function onRfidScanned(code) { rfidCardsLogic.scannedRfid = code; if (rfidCardsLogic.tfRfid) rfidCardsLogic.tfRfid.text = code }
    }

    onTriggerRefreshChanged: if (triggerRefresh) { refresh(); triggerRefresh = false }
    onTriggerSaveChanged: if (triggerSave) { save(); triggerSave = false }
}
