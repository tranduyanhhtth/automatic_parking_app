import QtQuick

Item {
    id: notifyLogic
    // Visual toast component passed in; we bind its model
    property Item toast
    property int duration: 2600
    property int perSeverityMax: 3
    property int maxMessages: 5
    ListModel { id: msgs }
    property int _nextId: 1

    // Bind model to toast if available
    Component.onCompleted: { if(toast) toast.externalModel = msgs }
    onToastChanged: { if(toast) toast.externalModel = msgs }

    function classify(msg) {
        if (!msg) return 'info';
        const m = msg.toLowerCase();
        if (m.indexOf('lỗi') === 0 || m.indexOf('error') === 0 || m.indexOf('không thể') >= 0 || m.indexOf('không hợp lệ') >= 0 || m.indexOf('thiếu ') >= 0) return 'error';
        if (m.indexOf('cảnh báo') === 0 || m.indexOf('warning') === 0 || m.indexOf('chưa có') === 0 || m.indexOf('chưa chọn') === 0 ) return 'warn';
        if (m.indexOf('đã ') === 0 || m.indexOf('thành công') >= 0 || m.indexOf('saved') >= 0) return 'success';
        return 'info';
    }
    function push(message, severity){
        if(!message||!message.length) return
        if(!severity) severity = classify(message)
        // Duplicate merge
        for(let i=0;i<msgs.count;i++){
            let it=msgs.get(i)
            if(it.text===message && it.sev===severity && it.sev!=='fade'){
                msgs.setProperty(i,'count',(it.count||1)+1)
                msgs.setProperty(i,'ts',Date.now())
                return
            }
        }
        // Per severity limit
        let active=[]
        for(let j=0;j<msgs.count;j++){ let it=msgs.get(j); if(it.sev===severity && it.sev!=='fade') active.push({i:j,ts:it.ts}) }
        if(active.length>=perSeverityMax){ active.sort((a,b)=>a.ts-b.ts); msgs.remove(active[0].i) }
        while(msgs.count>=maxMessages) msgs.remove(msgs.count - 1)
        const id=_nextId++
        msgs.insert(0,{ id:id, text:message, sev:severity, ts:Date.now(), count:1 })

        // Timer fade
        Qt.createQmlObject('import QtQuick 2.15; Timer { interval: '+duration+'; running: true; repeat: false; onTriggered: { var id='+id+'; for(var k=0;k<msgs.count;k++){ if(msgs.get(k).id===id){ msgs.setProperty(k,"sev","fade"); break; } } } }', notifyLogic)
    }
}
