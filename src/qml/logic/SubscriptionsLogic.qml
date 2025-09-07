import QtQuick

Item {
    id: subsLogic
    property Item adminPage
    property var notify

    ListModel { id: subsModel }
    property alias listModel: subsModel
    property int selectedSubId: -1
    property int selectedUserId: -1
    property var usersCache: []
    property int expiredCount: 0
    // Filtering & warning
    property string filterMode: "all" // all | expired | active
    property int expiredWarnThreshold: 5
    property bool _expiredWarned: false

    function msg(m){ if(notify) notify(m); else console.log(m) }
    function planToTicket(p){ p=(''+p).toLowerCase(); if(p.indexOf('th')===0||p.indexOf('month')===0) return 'monthly'; if(p.indexOf('qu')===0||p.indexOf('quarter')===0) return 'quarterly'; if(p.indexOf('nă')===0||p.indexOf('ye')===0||p.indexOf('year')===0) return 'yearly'; return p }
    function pad2(n){ return n<10?('0'+n):''+n }
    function addMonths(iso, m){ if(!iso||m<=0) return iso||''; const parts=(''+iso).split('-'); if(parts.length<3) return iso; let y=parseInt(parts[0]); let mm=parseInt(parts[1])-1; let d=parseInt(parts[2]); const dt=new Date(y,mm,d); dt.setMonth(dt.getMonth()+m); return dt.getFullYear()+'-'+pad2(dt.getMonth()+1)+'-'+pad2(dt.getDate()) }
    function updateEnd(){ if(!adminPage) return; const start=adminPage.subStart?adminPage.subStart.text:''; if(!start) return; const t=planToTicket(adminPage.subPlan.currentText); const m=t==='monthly'?1:(t==='quarterly'?3:(t==='yearly'?12:0)); if(m>0 && adminPage.subEnd) adminPage.subEnd.text=addMonths(start,m) }
    function validate(){ if(!adminPage) return 'Trang Admin chưa sẵn sàng'; if(!adminPage.subUser || adminPage.subUser.currentIndex<=0) return 'Chọn người dùng'; if(!adminPage.subPlate.text||adminPage.subPlate.text.length<4) return 'Biển số không hợp lệ'; if(!adminPage.subRfid.text||adminPage.subRfid.text.length<3) return 'RFID không hợp lệ'; if(!adminPage.subPrice.text) return 'Nhập giá'; return '' }
    function refreshUsers(){ if(typeof repo==='undefined'||!repo.listUsers) return; usersCache=repo.listUsers(500,0)||[]; if(adminPage && adminPage.subUser){ const arr=['Chọn user...']; for(let i=0;i<usersCache.length;i++) arr.push(usersCache[i].full_name); adminPage.subUser.model=arr } }
    function findUserId(idx){ if(idx<=0) return -1; const r=idx-1; return (r>=0&&r<usersCache.length)? usersCache[r].id : -1 }
    function refreshSubs(){
        subsModel.clear(); expiredCount = 0
        if(typeof repo==='undefined'||!repo.listSubscriptions) return
        const rows=repo.listSubscriptions(500,0)||[]
        console.log('[SubsLogic] refreshSubs -> rows:', rows.length)
        for(let i=0;i<rows.length;i++){
            const r = rows[i];
            if(r.status==='expired') expiredCount++
            // apply filter
            if(filterMode==='expired' && r.status!=='expired') continue
            if(filterMode==='active' && r.status!=='active') continue
            subsModel.append(r)
        }
        // update dashboard label if exists
        if(adminPage && adminPage.cardExpiredSubs){ adminPage.cardExpiredSubs.text = ''+expiredCount }
        // threshold warning (only when viewing all to avoid spam) & only once until condition clears
        if(filterMode==='all' && expiredCount >= expiredWarnThreshold){
            if(!_expiredWarned){ msg('Cảnh báo: có '+expiredCount+' đăng ký đã hết hạn'); _expiredWarned = true }
        } else if(expiredCount < expiredWarnThreshold) {
            _expiredWarned = false
        }
    }
    function selectSubscription(id,user_id,plate,rfid,plan_type,start_date,end_date,payment_mode,price,status){ selectedSubId=id; selectedUserId=user_id; if(adminPage){ if(adminPage.subPlate) adminPage.subPlate.text=plate; if(adminPage.subRfid) adminPage.subRfid.text=rfid; if(adminPage.subPlan){ const map={'monthly':0,'quarterly':1,'yearly':2}; adminPage.subPlan.currentIndex=(plan_type in map)? map[plan_type]:0 } if(adminPage.subStart) adminPage.subStart.text=start_date; if(adminPage.subEnd) adminPage.subEnd.text=end_date; if(adminPage.subPayment) adminPage.subPayment.currentIndex= payment_mode==='postpaid'?1:0; if(adminPage.subPrice) adminPage.subPrice.text=''+price; if(adminPage.subUser){ for(let i=0;i<usersCache.length;i++) if(usersCache[i].id===user_id){ adminPage.subUser.currentIndex=i+1; break } } } }
    function todayIso(){
        // local timezone date (not UTC slice) to align with business rules
        const now = new Date();
        const y = now.getFullYear();
        const m = now.getMonth()+1; const d = now.getDate();
        function p(x){return x<10?'0'+x:''+x}
        return y+'-'+p(m)+'-'+p(d)
    }
    function computeExtendDates(ticket, currentEnd){
        // start = max(today, currentEnd+1 day)
        const t = todayIso();
        let start = t;
        if(currentEnd){
            try { const ce=new Date(currentEnd); if(!isNaN(ce.getTime())) { ce.setDate(ce.getDate()+1); const cand=ce.toISOString().slice(0,10); if(cand>t) start=cand } } catch(e) {}
        }
        const months = ticket==='monthly'?1:(ticket==='quarterly'?3:(ticket==='yearly'?12:0));
        let end = start;
        if(months>0){ const parts=start.split('-'); const dt=new Date(parseInt(parts[0]), parseInt(parts[1])-1, parseInt(parts[2])); dt.setMonth(dt.getMonth()+months); end = dt.getFullYear()+'-'+pad2(dt.getMonth()+1)+'-'+pad2(dt.getDate()); }
        return {start:start, end:end};
    }
    function createOrExtend(isExtend){
        const err=validate(); if(err){ msg(err); return }
        console.log('[SubsLogic] createOrExtend start', {extend:isExtend})
        const ticket=planToTicket(adminPage.subPlan.currentText);
        const userId=findUserId(adminPage.subUser.currentIndex); if(userId<=0){ msg('User không hợp lệ'); return }
        const plate=adminPage.subPlate.text; const rfid=adminPage.subRfid.text;
        let startDate=adminPage.subStart.text; let endDate=adminPage.subEnd.text;
        const paymentRaw=adminPage.subPayment.currentText; const payment=paymentRaw.toLowerCase().indexOf('sau')>=0?'postpaid':'prepaid';
        const price=parseInt(adminPage.subPrice.text||'0')||0;
        // smart extend: if extend, recompute start/end from existing selected subscription
        if(isExtend && selectedSubId>0){
            // find current endDate from model
            for(let i=0;i<listModel.count;i++) if(listModel.get(i).id===selectedSubId){ const dates=computeExtendDates(ticket, listModel.get(i).end_date); startDate=dates.start; endDate=dates.end; if(adminPage.subStart) adminPage.subStart.text=startDate; if(adminPage.subEnd) adminPage.subEnd.text=endDate; break }
        }
        let vehicleType='car'; for(let i=0;i<usersCache.length;i++) if(usersCache[i].id===userId){ vehicleType=usersCache[i].vehicle_type; break }
        const pid=(typeof repo!=='undefined'&&repo.getPricingId)? repo.getPricingId(vehicleType,ticket):-1; if(pid<=0){ msg('Không tìm thấy bảng giá'); return }
        console.log('[SubsLogic] create/extend params', {userId:userId,pid:pid,plate:plate,rfid:rfid,ticket:ticket,start:startDate,end:endDate,payment:payment,price:price})
        const sid=(typeof repo!=='undefined'&&repo.createSubscription)? repo.createSubscription(userId,pid,plate,rfid,ticket,startDate,endDate,payment,price,'active'):-1;
        console.log('[SubsLogic] create/extend result subscriptionId=', sid)
        if(sid>0){ if(price>0 && repo.insertRevenue) repo.insertRevenue(undefined,sid,userId,price,payment,'subscription',isExtend?'extend':'create'); msg((isExtend?'Gia hạn':'Tạo')+' đăng ký thành công'); refreshSubs() } else msg('Lỗi lưu đăng ký') }
    
    // Auto expiry every 60s
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { if(typeof repo!=='undefined' && repo.expireDueSubscriptions){ const day=todayIso(); const n=repo.expireDueSubscriptions(day); if(n>0){ msg('Tự động hết hạn '+n+' đăng ký'); refreshSubs() } } } }
    function markLost(){ if(selectedSubId<=0){ msg('Chưa chọn đăng ký'); return } if(typeof repo==='undefined'||!repo.markSubscriptionLostCard){ msg('Thiếu API lost card'); return } const ok=repo.markSubscriptionLostCard(selectedSubId); msg(ok?'Đã đánh dấu mất thẻ':'Không thể đánh dấu mất'); if(ok){ refreshSubs(); selectedSubId=-1 } }
    function cancelSub(){ if(selectedSubId<=0){ msg('Chưa chọn đăng ký'); return } if(typeof repo==='undefined'||!repo.cancelSubscription){ msg('Thiếu API cancelSubscription'); return } const ok=repo.cancelSubscription(selectedSubId); msg(ok?'Đã hủy đăng ký':'Không thể hủy'); if(ok){ refreshSubs(); selectedSubId=-1 } }
    Connections { target: adminPage; function onTriggerSubCreateChanged(){ if(adminPage.triggerSubCreate){ createOrExtend(false); adminPage.triggerSubCreate=false } } function onTriggerSubExtendChanged(){ if(adminPage.triggerSubExtend){ createOrExtend(true); adminPage.triggerSubExtend=false } } function onTriggerSubLostDeleteChanged(){ if(adminPage.triggerSubLostDelete){ markLost(); adminPage.triggerSubLostDelete=false } } function onTriggerSubCancelChanged(){ if(adminPage.triggerSubCancel){ cancelSub(); adminPage.triggerSubCancel=false } } function onPendingSelectSubIndexChanged(){ var idx=adminPage.pendingSelectSubIndex; if(idx>=0 && idx<listModel.count){ var r=listModel.get(idx); selectSubscription(r.id, r.user_id, r.plate, r.rfid, r.plan_type, r.start_date, r.end_date, r.payment_mode, r.price, r.status) } } function onTriggerUsersChangedChanged(){ if(adminPage.triggerUsersChanged){ refreshUsers() } } }
    Connections { target: adminPage?adminPage.subPlan:null; function onCurrentIndexChanged(){ updateEnd() } function onCurrentTextChanged(){ updateEnd() } }
    Connections { target: adminPage?adminPage.subStart:null; function onTextChanged(){ updateEnd() } }
    function fullRefresh(){ refreshUsers(); refreshSubs() }

    function setFilter(mode){
        if(mode!==filterMode){ filterMode=mode; refreshSubs() }
    }

    function exportExpiredCsv(){
        if(typeof repo==='undefined'||!repo.listSubscriptions){ msg('Thiếu API listSubscriptions'); return }
        const rows=repo.listSubscriptions(1000,0)||[]
        const expired=[]; for(let i=0;i<rows.length;i++) if(rows[i].status==='expired') expired.push(rows[i])
        if(expired.length===0){ msg('Không có đăng ký hết hạn'); return }
        let csv='id,user_id,full_name,plate,rfid,plan_type,start_date,end_date,status\n'
        for(let i=0;i<expired.length;i++){
            const r=expired[i]
            function esc(v){ if(v===undefined||v===null) return ''; const s=(''+v).replace(/"/g,'""'); return '"'+s+'"' }
            csv+=r.id+','+r.user_id+','+esc(r.full_name)+','+esc(r.plate)+','+esc(r.rfid)+','+r.plan_type+','+r.start_date+','+r.end_date+','+r.status+'\n'
        }
        // Attempt to store in adminPage buffer for manual copy
        if(adminPage){ adminPage.expiredCsvBuffer = csv }
        console.log('[ExportExpiredCSV]\n'+csv)
        msg('Đã tạo CSV '+expired.length+' dòng (copy từ log hoặc buffer)')
    }

    Connections {
        target: adminPage
        function onTriggerSubFilterChangedChanged(){ if(adminPage && adminPage.triggerSubFilterChanged){
                if(adminPage.subFilter){
                    const idx = adminPage.subFilter.currentIndex
                    if(idx===0) setFilter('all')
                    else if(idx===1) setFilter('expired')
                    else setFilter('active')
                }
                adminPage.triggerSubFilterChanged = false
            } }
        function onTriggerExportExpiredChanged(){ if(adminPage && adminPage.triggerExportExpired){ exportExpiredCsv(); adminPage.triggerExportExpired=false } }
    }
    Component.onCompleted: fullRefresh()
}
