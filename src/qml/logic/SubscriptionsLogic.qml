import QtQuick

Item {
    id: subsLogic
    property Item adminPage
    property var notify
    // Optional repository reference (fallback to global 'repo')
    property var repoRef
    function rRepo(){ return repoRef ? repoRef : (typeof repo !== 'undefined' ? repo : null) }

    ListModel { id: subsModel }
    property alias listModel: subsModel
    property int selectedSubId: -1
    property int selectedUserId: -1
    property var usersCache: []
    property var dupPlates: [] // for duplicate names disambiguation
    property string pendingUserNameQuery: ""
    property int expiredCount: 0
    // Filtering & warning
    property string filterMode: "all" // all | expired | active
    property int expiredWarnThreshold: 5
    property bool _expiredWarned: false
    // Extension revert cache
    property string _origStart: ""
    property string _origEnd: ""
    property bool _inExtendedState: false

    function msg(m){ if(notify) notify(m); else console.log(m) }
    function planToTicket(p){ p=(''+p).toLowerCase(); if(p.indexOf('th')===0||p.indexOf('month')===0) return 'monthly'; if(p.indexOf('qu')===0||p.indexOf('quarter')===0) return 'quarterly'; if(p.indexOf('nă')===0||p.indexOf('ye')===0||p.indexOf('year')===0) return 'yearly'; return p }
    function pad2(n){ return n<10?('0'+n):''+n }
    function addMonths(iso, m){ if(!iso||m<=0) return iso||''; const parts=(''+iso).split('-'); if(parts.length<3) return iso; let y=parseInt(parts[0]); let mm=parseInt(parts[1])-1; let d=parseInt(parts[2]); const dt=new Date(y,mm,d); dt.setMonth(dt.getMonth()+m); return dt.getFullYear()+'-'+pad2(dt.getMonth()+1)+'-'+pad2(dt.getDate()) }
    function updateEnd(){ if(!adminPage) return; const start=(adminPage.subStart&&adminPage.subStart.text)?adminPage.subStart.text:''; if(!start) return; const t=planToTicket(adminPage.subPlan.currentText); const m=t==='monthly'?1:(t==='quarterly'?3:(t==='yearly'?12:0)); if(m>0 && adminPage.subEnd) adminPage.subEnd.text=addMonths(start,m) }
    function validate(){ if(!adminPage) return 'Trang Admin chưa sẵn sàng'; if(!adminPage.subUserText || !adminPage.subUserText.text || adminPage.subUserText.text.length<2) return 'Nhập tên user'; if(!(adminPage.subPlate&&adminPage.subPlate.text)||adminPage.subPlate.text.length<4) return 'Biển số không hợp lệ'; if(!(adminPage.subRfid&&adminPage.subRfid.text)||adminPage.subRfid.text.length<3) return 'RFID không hợp lệ'; if(!(adminPage.subPrice&&adminPage.subPrice.text)) return 'Thiếu giá'; return '' }
    function refreshUsers(){ const r=rRepo(); if(!r||!r.listUsers) return; usersCache=r.listUsers(500,0)||[] }
    function findUserByName(name){ 
        if(!name) return null; 
        if(usersCache.length === 0) refreshUsers()
        const low=(''+name).toLowerCase();
        let matches=[];
        for(let i=0;i<usersCache.length;i++){
            if((''+usersCache[i].full_name).toLowerCase().indexOf(low) >= 0) matches.push(usersCache[i]);
        }
        if(matches.length===0) return null;
        // Build distinct plate list for UI picker when more than one match
        dupPlates = [];
        if(matches.length>1){
            const set={};
            for(let i=0;i<matches.length;i++){
                const pl = matches[i].plate || '';
                if(pl && !set[pl]){ set[pl]=true; dupPlates.push(pl); }
            }
            // If no plate data to disambiguate, fall back to first
        } else {
            dupPlates = [];
        }
        // If a plate is selected in picker, choose that user
        if(adminPage && adminPage.subPlatePick && dupPlates.length>1){
            const sel = adminPage.subPlatePick.currentIndex>=0 && adminPage.subPlatePick.currentIndex<dupPlates.length ? dupPlates[adminPage.subPlatePick.currentIndex] : '';
            if(sel){ for(let i=0;i<matches.length;i++){ if(matches[i].plate===sel) return matches[i]; } }
        }
        // Otherwise return first match
        return matches[0]
    }
    function refreshSubs(){
        subsModel.clear(); expiredCount = 0
        const r=rRepo(); if(!r||!r.listSubscriptions) return
        const rows=r.listSubscriptions(500,0)||[]
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
    function selectSubscription(id,user_id,plate,rfid,plan_type,start_date,end_date,payment_mode,price,status){
        selectedSubId=id; selectedUserId=user_id; _inExtendedState=false; _origStart=''; _origEnd='';
        if(adminPage){
            if(adminPage.subPlate) adminPage.subPlate.text=plate;
            if(adminPage.subRfid) adminPage.subRfid.text=rfid;
            if(adminPage.subPlan){ const map={'monthly':0,'quarterly':1,'yearly':2}; adminPage.subPlan.currentIndex=(plan_type in map)? map[plan_type]:0 }
            if(adminPage.subStart) adminPage.subStart.text=start_date;
            if(adminPage.subEnd) adminPage.subEnd.text=end_date;
            if(adminPage.subPayment) adminPage.subPayment.currentIndex= payment_mode==='postpaid'?1:0;
            if(adminPage.subPrice) adminPage.subPrice.text=''+price;
            if(adminPage.subUserText){
                for(let i=0;i<usersCache.length;i++) if(usersCache[i].id===user_id){ adminPage.subUserText.text=usersCache[i].full_name; break }
            }
        }
    }
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
    function computeExtendOneYear(currentEnd){
        const t = todayIso();
        let start = t;
        if(currentEnd){
            try { const ce=new Date(currentEnd); if(!isNaN(ce.getTime())) { ce.setDate(ce.getDate()+1); const cand=ce.toISOString().slice(0,10); if(cand>t) start=cand } } catch(e) {}
        }
        const end = addMonths(start, 12);
        return {start:start, end:end};
    }
    function prefillPrice(userId, ticket){
        if(userId<=0) return; const r=rRepo(); if(!r || !r.getPricingId || !r.getLatestPricing) return;
        // vehicle type
        let vehicleType='car'; for(let i=0;i<usersCache.length;i++) if(usersCache[i].id===userId){ vehicleType=usersCache[i].vehicle_type; break }
        const pid = r.getPricingId(vehicleType, ticket);
        if(pid>0 && adminPage && adminPage.subPrice){
            const pricing = r.getLatestPricing(vehicleType, ticket) || {};
            if(pricing.base_fee!==undefined) adminPage.subPrice.text=''+pricing.base_fee;
        }
    }
    function createOrExtend(isExtend){
        const err=validate(); if(err){ msg(err); return }
        console.log('[SubsLogic] createOrExtend start', {extend:isExtend})
        const ticket=planToTicket(adminPage.subPlan.currentText);
        var userId=-1; var userObj=null;
        if(adminPage && adminPage.subUserText){ userObj = findUserByName(adminPage.subUserText.text); if(userObj) userId=userObj.id }
        if(!userObj){ msg('Tên người dùng không tồn tại, không thể đăng ký'); return }
        // If multiple with same name, require a plate selection when plates differ
        if(dupPlates && dupPlates.length>1){ if(!adminPage.subPlatePick || adminPage.subPlatePick.currentIndex<0){ msg('Có nhiều người trùng tên, hãy chọn biển số'); return } }
        if(userId<=0){ msg('User không hợp lệ'); return }
        // Soft guard: block if an active subscription already exists for this user and same RFID/plate overlapping now
        (function(){
            const r=rRepo(); if(!r||!r.getLatestSubscriptionForUser) return;
            const sub=r.getLatestSubscriptionForUser(userId);
            if(sub && sub.id && sub.status==='active'){
                // If the same RFID or Plate matches, prevent duplicate create
                const sameR = (adminPage.subRfid&&adminPage.subRfid.text) ? (sub.rfid===adminPage.subRfid.text) : false;
                const sameP = (adminPage.subPlate&&adminPage.subPlate.text) ? (sub.plate===adminPage.subPlate.text) : false;
                if(sameR || sameP){ msg('Người dùng này đã có đăng ký đang hoạt động'); throw 'abort'; }
            }
        })();
        const plate=(adminPage.subPlate&&adminPage.subPlate.text)?adminPage.subPlate.text:''; const rfid=(adminPage.subRfid&&adminPage.subRfid.text)?adminPage.subRfid.text:'';
        let startDate=(adminPage.subStart&&adminPage.subStart.text)?adminPage.subStart.text:''; let endDate=(adminPage.subEnd&&adminPage.subEnd.text)?adminPage.subEnd.text:'';
        const paymentRaw=adminPage.subPayment?adminPage.subPayment.currentText:''; const payment=paymentRaw.toLowerCase().indexOf('sau')>=0?'postpaid':'prepaid';
        if(!(adminPage.subPrice&&adminPage.subPrice.text && adminPage.subPrice.text.length>0)) prefillPrice(userId, ticket)
        const price=parseInt((adminPage.subPrice&&adminPage.subPrice.text)?adminPage.subPrice.text:'0')||0;
        if(isExtend && selectedSubId>0){
            for(let i=0;i<listModel.count;i++) if(listModel.get(i).id===selectedSubId){
                const current=listModel.get(i);
                _origStart=current.start_date; _origEnd=current.end_date; _inExtendedState=true;
                const dates=computeExtendOneYear(current.end_date);
                startDate=dates.start; endDate=dates.end;
                if(adminPage.subStart) adminPage.subStart.text=startDate; if(adminPage.subEnd) adminPage.subEnd.text=endDate;
                break;
            }
        }
        let vehicleType='car'; for(let i=0;i<usersCache.length;i++) if(usersCache[i].id===userId){ vehicleType=usersCache[i].vehicle_type; break }
        const r=rRepo(); const pid=(r&&r.getPricingId)? r.getPricingId(vehicleType,ticket):-1; if(pid<=0){ msg('Không tìm thấy bảng giá'); return }
        console.log('[SubsLogic] create/extend params', {userId:userId,pid:pid,plate:plate,rfid:rfid,ticket:ticket,start:startDate,end:endDate,payment:payment,price:price})
        const sid=(r&&r.createSubscription)? r.createSubscription(userId,pid,plate,rfid,ticket,startDate,endDate,payment,price,'active'):-1;
        console.log('[SubsLogic] create/extend result subscriptionId=', sid)
        if(sid===-2){
            msg('Đăng ký trùng lặp: người dùng/biển số hoặc RFID đã có đăng ký hoạt động trong khoảng này');
            return;
        } else if(sid>0){ 
            if(price>0 && r && r.insertRevenue) 
                r.insertRevenue(undefined,sid,userId,price,payment,'subscription',isExtend?'extend':'create'); 
                msg((isExtend?'Gia hạn':'Tạo')+' đăng ký thành công'); 
                _inExtendedState=false; 
                refreshSubs() 
        } else msg('Lỗi lưu đăng ký') 
    }
    

    function cancelExtend(){
        if(!_inExtendedState){ msg('Không có gia hạn để hủy'); return }
        if(adminPage){ if(adminPage.subStart) adminPage.subStart.text=_origStart; if(adminPage.subEnd) adminPage.subEnd.text=_origEnd }
        _inExtendedState=false; msg('Đã khôi phục ngày cũ')
    }
    
    // Auto expiry every 60s
    Timer { 
        interval: 60000; 
        running: true; 
        repeat: true; 
        onTriggered: { 
            const r=rRepo();
            if(r && r.expireDueSubscriptions){ 
                const day=todayIso(); 
                const n=r.expireDueSubscriptions(day); 
                if(n>0){ 
                    msg('Tự động hết hạn '+n+' đăng ký'); 
                    refreshSubs() 
                } 
            } 
        } 
    }

    function markLost(){ 
        if(selectedSubId<=0){ 
            msg('Chưa chọn đăng ký'); 
            return 
        } 
        const r=rRepo();
        if(!r||!r.markSubscriptionLostCard){ 
            msg('Thiếu API lost card'); 
            return 
        } 
        const ok=r.markSubscriptionLostCard(selectedSubId); 
        msg(ok?'Đã đánh dấu mất thẻ':'Không thể đánh dấu mất'); 
        if(ok){ 
            refreshSubs(); 
            selectedSubId=-1 
        }
    }

    function cancelSub(){ 
        if(selectedSubId<=0){ 
            msg('Chưa chọn đăng ký'); 
            return 
        } 
        const r=rRepo();
        if(!r||!r.cancelSubscription){ 
            msg('Thiếu API cancelSubscription'); 
            return 
        } 
        const ok=r.cancelSubscription(selectedSubId); 
        msg(ok?'Đã hủy đăng ký':'Không thể hủy'); 
        if(ok){ 
            refreshSubs(); 
            selectedSubId=-1 
        } 
    }

    Connections { 
        target: adminPage; 
        function onTriggerSubCreateChanged(){ 
            if(adminPage.triggerSubCreate){ 
                createOrExtend(false); 
                adminPage.triggerSubCreate=false 
            } 
        } 
        function onTriggerSubExtendChanged(){ 
            if(adminPage.triggerSubExtend){ 
                createOrExtend(true); 
                adminPage.triggerSubExtend=false 
            } 
        } 
        function onTriggerSubCancelExtendChanged(){ 
            if(adminPage.triggerSubCancelExtend){ 
                cancelExtend(); 
                adminPage.triggerSubCancelExtend=false 
            } 
        } 
        function onTriggerSubLostDeleteChanged(){ 
            if(adminPage.triggerSubLostDelete){ 
                markLost(); 
                adminPage.triggerSubLostDelete=false 
            } 
        } 
        function onTriggerSubCancelChanged(){ 
            if(adminPage.triggerSubCancel){ 
                cancelSub(); 
                adminPage.triggerSubCancel=false 
            } 
        } 
        function onPendingSelectSubIndexChanged(){ 
            var idx=adminPage.pendingSelectSubIndex; 
            if(idx>=0 && idx<listModel.count){ 
                var r=listModel.get(idx); 
                selectSubscription(r.id, r.user_id, r.plate, r.rfid, r.plan_type, r.start_date, r.end_date, r.payment_mode, r.price, r.status) 
            } 
        } 
        function onTriggerUsersChangedChanged(){ 
            if(adminPage.triggerUsersChanged){ 
                refreshUsers() 
            } 
        } 
        function prefillSubscriptionForUser(userId) {
            const r=rRepo();
            if(userId <= 0 || !r || !r.getLatestSubscriptionForUser)
                return false
            const sub = r.getLatestSubscriptionForUser(userId)
            if(!sub || !sub.id){ return false }
            // Existing subscription => fill everything
            if(adminPage.subPlan) {
                const map = { 'monthly':0, 'quarterly':1, 'yearly':2 }
                adminPage.subPlan.currentIndex = (sub.plan_type in map) ? map[sub.plan_type] : 0
            }
            if(adminPage.subStart) adminPage.subStart.text = sub.start_date
            if(adminPage.subEnd) adminPage.subEnd.text = sub.end_date
            if(adminPage.subPayment) adminPage.subPayment.currentIndex = sub.payment_mode === 'postpaid' ? 1 : 0
            if(adminPage.subPrice) adminPage.subPrice.text = ''+sub.price
            return true
        }
        function onTriggerSubUserTextChangedChanged(){ 
            if(adminPage.triggerSubUserTextChanged){ 
                if(adminPage && adminPage.subUserText){ 
                    var nm=adminPage.subUserText.text; 
                    var u=findUserByName(nm); 
                    if(u){
                        if(adminPage.subPlate) adminPage.subPlate.text=u.plate||'';
                        if(adminPage.subRfid) adminPage.subRfid.text=u.rfid||'';
                        // Try prefill existing subscription; if returns false (no existing) then set new start/end
                        const had = prefillSubscriptionForUser(u.id);
                        if(!had){
                            const tk=planToTicket(adminPage.subPlan.currentText);
                            if(adminPage.subStart){ const today=todayIso(); adminPage.subStart.text=today; updateEnd() }
                            prefillPrice(u.id, tk);
                        }
                    } else {
                        // Unknown user -> clear fields
                        if(adminPage.subPlate) adminPage.subPlate.text='';
                        if(adminPage.subRfid) adminPage.subRfid.text='';
                        if(adminPage.subPrice) adminPage.subPrice.text='';
                        if(adminPage.subStart) adminPage.subStart.text='';
                        if(adminPage.subEnd) adminPage.subEnd.text='';
                    }
                } 
                adminPage.triggerSubUserTextChanged=false 
            } 
        }
    }
    Connections { 
        target: adminPage?adminPage.subPlan:null; 
        function onCurrentIndexChanged(){ 
            // on plan change: for new users (no prior sub) set start=today and recompute end
            if(adminPage && adminPage.subUserText && adminPage.subUserText.text){
                var u=findUserByName(adminPage.subUserText.text);
                if(u){
                    const r=rRepo();
                    // If no prior subscription: set start today
                    if(r && r.getLatestSubscriptionForUser){
                        var sub=r.getLatestSubscriptionForUser(u.id);
                        if(!sub || !sub.id){ if(adminPage.subStart){ adminPage.subStart.text=todayIso() } }
                    }
                    prefillPrice(u.id, planToTicket(adminPage.subPlan.currentText))
                }
            }
            updateEnd();
        } 
        function onCurrentTextChanged(){ 
            if(adminPage && adminPage.subUserText && adminPage.subUserText.text){
                var u=findUserByName(adminPage.subUserText.text);
                if(u){
                    const r=rRepo();
                    if(r && r.getLatestSubscriptionForUser){
                        var sub=r.getLatestSubscriptionForUser(u.id);
                        if(!sub || !sub.id){ if(adminPage.subStart){ adminPage.subStart.text=todayIso() } }
                    }
                    prefillPrice(u.id, planToTicket(adminPage.subPlan.currentText))
                }
            }
            updateEnd();
        } 
    }
    Connections { 
        target: adminPage?adminPage.subStart:null; 
        function onTextChanged(){ 
            updateEnd() 
        } 
    }

    function fullRefresh(){ refreshUsers(); refreshSubs() }

    function setFilter(mode){
        if(mode!==filterMode){ filterMode=mode; refreshSubs() }
    }

    function exportCsvForCurrentFilter(){
        const r=rRepo(); if(!r||!r.listSubscriptions){ msg('Thiếu API listSubscriptions'); return }
        const rows=r.listSubscriptions(5000,0)||[]
        let filtered=[];
        // Use current filter selection if available
        let mode = filterMode;
        if(adminPage && adminPage.subFilter){
            const idx = adminPage.subFilter.currentIndex; mode = (idx===1?'expired':(idx===2?'active':'all'))
        }
        for(let i=0;i<rows.length;i++){
            const r=rows[i];
            if(mode==='expired' && r.status!=='expired') continue;
            if(mode==='active' && r.status!=='active') continue;
            filtered.push(r);
        }
        if(filtered.length===0){ msg('Không có dữ liệu để xuất'); return }
        let csv='id,user_id,full_name,plate,rfid,plan_type,start_date,end_date,status,payment_mode,price\n'
        function esc(v){ if(v===undefined||v===null) return ''; const s=(''+v).replace(/"/g,'""'); return '"'+s+'"' }
        for(let i=0;i<filtered.length;i++){
            const r=filtered[i]
            csv+=r.id+','+r.user_id+','+esc(r.full_name)+','+esc(r.plate)+','+esc(r.rfid)+','+r.plan_type+','+r.start_date+','+r.end_date+','+r.status+','+r.payment_mode+','+r.price+'\n'
        }
        if(adminPage){ adminPage.expiredCsvBuffer = csv }
        console.log('[ExportCSV]\n'+csv)
        msg('Đã tạo CSV '+filtered.length+' dòng (copy từ log hoặc buffer)')
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
        function onTriggerExportExpiredChanged(){ if(adminPage && adminPage.triggerExportExpired){ exportCsvForCurrentFilter(); adminPage.triggerExportExpired=false } }
    }
    Component.onCompleted: fullRefresh()
}
