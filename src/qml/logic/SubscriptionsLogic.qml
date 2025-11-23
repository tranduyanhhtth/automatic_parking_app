import QtQuick

Item {
    id: subsLogic
    property Item adminPage
    property var notify
    property var repoRef
    function rRepo(){ return repoRef ? repoRef : (typeof repo !== 'undefined' ? repo : null) }

    ListModel { id: subsModel }
    property alias listModel: subsModel
    property int selectedSubId: -1
    property int selectedUserId: -1

    // CHANGED: We now cache RFID Cards instead of Users
    property var cardsCache: []
    property var dupPlates: []
    property string pendingUserNameQuery: ""
    property int expiredCount: 0
    property string filterMode: "all"
    property int expiredWarnThreshold: 5
    property bool _expiredWarned: false
    property string _origStart: ""
    property string _origEnd: ""
    property bool _inExtendedState: false

    function attachAdminPage(){
        if(!adminPage) return;
        if(!adminPage.subsLogic || adminPage.subsLogic !== subsLogic){
            adminPage.subsLogic = subsLogic;
        }
        if(adminPage.subscriptionListModel !== listModel){
            adminPage.subscriptionListModel = listModel;
        }
    }

    onAdminPageChanged: { attachAdminPage(); }

    function msg(m){ if(notify) notify(m); else console.log(m) }
    function planToTicket(p){ p=(''+p).toLowerCase(); if(p.indexOf('th')===0||p.indexOf('month')===0) return 'monthly'; if(p.indexOf('qu')===0||p.indexOf('quarter')===0) return 'quarterly'; if(p.indexOf('nă')===0||p.indexOf('ye')===0||p.indexOf('year')===0) return 'yearly'; return p }
    function labelFromTicket(t){ if(t==='monthly') return 'Tháng'; if(t==='quarterly') return 'Quý'; if(t==='yearly') return 'Năm'; return '' }

    function readPlanText(){
        if(!adminPage || !adminPage.subPlan) return ''
        if('text' in adminPage.subPlan) return adminPage.subPlan.text || ''
        if('currentText' in adminPage.subPlan) return adminPage.subPlan.currentText || ''
        return ''
    }
    function setPlanLabel(ticket){
        if(!adminPage || !adminPage.subPlan) return
        const lbl = labelFromTicket(ticket)
        if('text' in adminPage.subPlan) adminPage.subPlan.text = lbl
        else if('currentIndex' in adminPage.subPlan){ const map={'monthly':0,'quarterly':1,'yearly':2}; adminPage.subPlan.currentIndex = (ticket in map)? map[ticket]:0 }
    }
    function currentTicketFromRfid(){
        if(!adminPage || !adminPage.subRfid) return ''
        const code = adminPage.subRfid.text || ''
        if(!code) return ''
        const r = rRepo();
        if(!r || !r.getRfidCard) return ''
        const card = r.getRfidCard(code) || {}
        return card.ticket_type || ''
    }
    function pad2(n){ return n<10?('0'+n):''+n }
    function addMonths(iso, m){ if(!iso||m<=0) return iso||''; const parts=(''+iso).split('-'); if(parts.length<3) return iso; let y=parseInt(parts[0]); let mm=parseInt(parts[1])-1; let d=parseInt(parts[2]); const dt=new Date(y,mm,d); dt.setMonth(dt.getMonth()+m); return dt.getFullYear()+'-'+pad2(dt.getMonth()+1)+'-'+pad2(dt.getDate()) }

    function updateEnd(){
        if(!adminPage) return;
        const start=(adminPage.subStart&&adminPage.subStart.text)?adminPage.subStart.text:'';
        if(!start) return;
        const t = currentTicketFromRfid() || planToTicket(readPlanText());
        setPlanLabel(t);
        const m=t==='monthly'?1:(t==='quarterly'?3:(t==='yearly'?12:0));
        if(m>0 && adminPage.subEnd) adminPage.subEnd.text=addMonths(start,m)
    }
    function validate(){ if(!adminPage) return 'Trang Admin chưa sẵn sàng'; if(!adminPage.subUserText || !adminPage.subUserText.text || adminPage.subUserText.text.length<2) return 'Nhập tên user'; if(!(adminPage.subPlate&&adminPage.subPlate.text)||adminPage.subPlate.text.length<4) return 'Biển số không hợp lệ'; if(!(adminPage.subRfid&&adminPage.subRfid.text)||adminPage.subRfid.text.length<3) return 'RFID không hợp lệ'; if(!(adminPage.subPrice&&adminPage.subPrice.text)) return 'Thiếu giá'; return '' }

    // --- CHANGED: Load RFID Cards instead of Users ---
    function refreshCardOwners(){
        const r=rRepo();
        if(!r||!r.listRfidCards) return;
        // Retrieve all cards to cache their owners
        // Using listRfidCards(rfid, vehicle, status, limit, offset)
        cardsCache = r.listRfidCards('','','', 1000, 0) || []
    }

    // --- CHANGED: Search in cardsCache by owner_name ---
    function findCardOwnerByName(name){
        if(!name) return null;
        if(cardsCache.length === 0) refreshCardOwners()
        const low=(''+name).toLowerCase();
        let matches=[];

        for(let i=0;i<cardsCache.length;i++){
            // Only look at cards that have an owner name
            if (cardsCache[i].owner_name) {
                if((''+cardsCache[i].owner_name).toLowerCase().indexOf(low) >= 0) matches.push(cardsCache[i]);
            }
        }
        if(matches.length===0) return null;

        dupPlates = [];
        if(matches.length>1){
            const set={};
            for(let i=0;i<matches.length;i++){
                const pl = matches[i].plate || '';
                if(pl && !set[pl]){ set[pl]=true; dupPlates.push(pl); }
            }
        } else {
            dupPlates = [];
        }

        if(adminPage && adminPage.subPlatePick && dupPlates.length>1){
            const sel = adminPage.subPlatePick.currentIndex>=0 && adminPage.subPlatePick.currentIndex<dupPlates.length ? dupPlates[adminPage.subPlatePick.currentIndex] : '';
            if(sel){ for(let i=0;i<matches.length;i++){ if(matches[i].plate===sel) return matches[i]; } }
        }
        return matches[0]
    }

    function refreshSubs(){
        subsModel.clear();
        expiredCount = 0
        const r=rRepo();
        if(!r||!r.listSubscriptions) return
        const rows=r.listSubscriptions(500,0)||[]
        for(let i=0;i<rows.length;i++){
            const r = rows[i];
            if (typeof r.user_id !== 'number') r.user_id = r.user_id ? parseInt(r.user_id) || 0 : 0;
            if(r.status==='expired') expiredCount++
            if(filterMode==='expired' && r.status!=='expired') continue
            if(filterMode==='active' && r.status!=='active') continue
            subsModel.append(r)
        }
        if(adminPage && adminPage.cardExpiredSubs){ adminPage.cardExpiredSubs.text = ''+expiredCount }
        if(filterMode==='all' && expiredCount >= expiredWarnThreshold){
            if(!_expiredWarned){ msg('Cảnh báo: có '+expiredCount+' đăng ký đã hết hạn'); _expiredWarned = true }
        } else if(expiredCount < expiredWarnThreshold) {
            _expiredWarned = false
        }
    }

    function selectSubscription(id,user_id,plate,rfid,plan_type,start_date,end_date,payment_mode,price,status, payment_method){
        selectedSubId=id; selectedUserId=user_id; _inExtendedState=false; _origStart=''; _origEnd='';
        if(adminPage){
            if(adminPage.subPlate) adminPage.subPlate.text=plate;
            if(adminPage.subRfid) adminPage.subRfid.text=rfid;
            if(adminPage.subPlan){ setPlanLabel(plan_type) }
            if(adminPage.subStart) adminPage.subStart.text=start_date;
            if(adminPage.subEnd) adminPage.subEnd.text=end_date;
            if(adminPage.subPaymentMethod) {
                let methIdx = 0;
                if (payment_method === 'transfer') { methIdx = 1; }
                adminPage.subPaymentMethod.currentIndex = methIdx;
            }
            if(adminPage.subPayment) adminPage.subPayment.currentIndex= payment_mode==='postpaid'?1:0;
            if(adminPage.subPrice) adminPage.subPrice.text=''+price;

            // When selecting an existing sub, we still want to show the user name.
            // Since we don't have a full user list cache, we might just show the name from the subscription row
            // or try to find it in the card cache. For now, we rely on the subscription row data (full_name)
            // Note: The listModel rows normally contain 'full_name'.
            for(let i=0; i<listModel.count; i++) {
                if (listModel.get(i).id === id) {
                    if(adminPage.subUserText) adminPage.subUserText.text = listModel.get(i).full_name;
                    break;
                }
            }
        }
    }

    function todayIso(){
        const now = new Date(); const y = now.getFullYear();
        const m = now.getMonth()+1; const d = now.getDate();
        function p(x){return x<10?'0'+x:''+x}
        return y+'-'+p(m)+'-'+p(d)
    }
    function computeExtendDates(ticket, currentEnd){
        const t = todayIso(); let start = t;
        if(currentEnd){
            try { const ce=new Date(currentEnd); if(!isNaN(ce.getTime())) { ce.setDate(ce.getDate()+1); const cand=ce.toISOString().slice(0,10); if(cand>t) start=cand } } catch(e) {}
        }
        const months = ticket==='monthly'?1:(ticket==='quarterly'?3:(ticket==='yearly'?12:0));
        let end = start;
        if(months>0){ const parts=start.split('-'); const dt=new Date(parseInt(parts[0]), parseInt(parts[1])-1, parseInt(parts[2])); dt.setMonth(dt.getMonth()+months); end = dt.getFullYear()+'-'+pad2(dt.getMonth()+1)+'-'+pad2(dt.getDate()); }
        return {start:start, end:end};
    }
    function computeExtendOneYear(currentEnd){
        const t = todayIso(); let start = t;
        if(currentEnd){
            try { const ce=new Date(currentEnd); if(!isNaN(ce.getTime())) { ce.setDate(ce.getDate()+1); const cand=ce.toISOString().slice(0,10); if(cand>t) start=cand } } catch(e) {}
        }
        const end = addMonths(start, 12);
        return {start:start, end:end};
    }

    function prefillPrice(userId, ticket, vehicleTypeOverride){
        const r=rRepo(); if(!r || !r.getPricingId || !r.getLatestPricing) return;
        // If userId is invalid, use the vehicle type from the RFID card or override
        let vehicleType = vehicleTypeOverride || 'car';

        // Try to fetch vehicle type from userId if valid
        if (userId > 0) {
             const u = r.getUser && r.getUser(userId);
             if(u) vehicleType = u.vehicle_type;
        }

        const pid = r.getPricingId(vehicleType, ticket);
        if(pid>0 && adminPage && adminPage.subPrice){
            const pricing = r.getLatestPricing(vehicleType, ticket) || {};
            if(pricing.base_fee!==undefined) adminPage.subPrice.text=''+pricing.base_fee;
        }
    }

    function createOrExtend(isExtend){
            const err=validate();
            if(err){ msg(err); return }

            // Helper to get ticket type
            const ticket = currentTicketFromRfid() || planToTicket(readPlanText());

            // Validate ticket type for subscriptions
            if(ticket!=='monthly' && ticket!=='quarterly' && ticket!=='yearly'){
                msg('Loại thẻ RFID không phải vé tháng/quý/năm');
                return
            }

            const r=rRepo();
            if(!r) return;

            var userId=-1;
            var cardObj=null;

            // Try to find existing card data to help with auto-filling or validation
            if(adminPage && adminPage.subUserText){
                cardObj = findCardOwnerByName(adminPage.subUserText.text);
            }

            // Get Form Data from UI controls
            const formName = adminPage.subUserText ? adminPage.subUserText.text : '';
            const formPlate = (adminPage.subPlate && adminPage.subPlate.text) ? adminPage.subPlate.text : '';
            const formRfid = (adminPage.subRfid && adminPage.subRfid.text) ? adminPage.subRfid.text : '';

            // --- FIX START ---
            // If this is an extension, we MUST find the user/card.
            // But if it is a NEW creation (!isExtend), we can proceed if we have form data.
            if (isExtend && !cardObj) {
                 msg('Không tìm thấy thông tin thẻ/chủ thẻ để gia hạn');
                 return;
            }

            // If creating new, ensure we have minimum data
            if (!isExtend && (!formName || !formPlate || !formRfid)) {
                msg("Thiếu thông tin Tên, Biển số hoặc RFID để tạo mới");
                return;
            }
            // --- FIX END ---

            // Determine final values to send to DB
            // Use form data if available, otherwise fall back to card object (if exists)
            const finalName = formName || (cardObj ? cardObj.owner_name : '');
            const finalPlate = formPlate || (cardObj ? cardObj.plate : '');
            const finalRfid = formRfid || (cardObj ? cardObj.rfid : '');

            // Determine vehicle type (default to car if unknown)
            let vType = 'car';
            if (cardObj && cardObj.vehicle_type) {
                vType = cardObj.vehicle_type;
            }

            console.log('[SubsLogic] Auto-creating/updating user for sub:', finalName, finalPlate, finalRfid);

            // Create or Update the User
            userId = r.upsertUser(finalName, "", finalRfid, finalPlate, vType);

            if (userId <= 0) {
                 msg("Lỗi: Không thể tạo/cập nhật người dùng.");
                 return;
            }

            // 2. Soft guard for duplicates (check if this user already has an active sub for this rfid)
            (function(){
                if(!r.getLatestSubscriptionForUser) return;
                const sub = r.getLatestSubscriptionForUser(userId);
                if(sub && sub.id && sub.status==='active' && !isExtend){
                    const sameR = (finalRfid === sub.rfid);
                    if(sameR){ msg('Thẻ này đã có đăng ký đang hoạt động'); throw 'abort'; }
                }
            })();

            // Gather dates and payment info
            let startDate=(adminPage.subStart&&adminPage.subStart.text)?adminPage.subStart.text:'';
            let endDate=(adminPage.subEnd&&adminPage.subEnd.text)?adminPage.subEnd.text:'';

            const paymentRaw=adminPage.subPayment?adminPage.subPayment.currentText:'';
            const payment=paymentRaw.toLowerCase().indexOf('sau')>=0?'postpaid':'prepaid';

            const paymentMethodRaw=adminPage.subPaymentMethod?adminPage.subPaymentMethod.currentText:'';
            const paymentMethod=paymentMethodRaw.toLowerCase().indexOf('chuy')>=0?'transfer':'cash';

            // Auto-calculate price if missing
            if(!(adminPage.subPrice&&adminPage.subPrice.text && adminPage.subPrice.text.length>0))
                prefillPrice(userId, ticket, vType)

            const price=parseInt((adminPage.subPrice&&adminPage.subPrice.text)?adminPage.subPrice.text:'0')||0;

            // Handle "Extend" specific logic (calculating next dates)
            if(isExtend && selectedSubId>0){
                for(let i=0;i<listModel.count;i++) if(listModel.get(i).id===selectedSubId){
                    const current=listModel.get(i);
                    _origStart=current.start_date; _origEnd=current.end_date; _inExtendedState=true;
                    const dates=computeExtendOneYear(current.end_date);
                    startDate=dates.start; endDate=dates.end;
                    if(adminPage.subStart) adminPage.subStart.text=startDate;
                    if(adminPage.subEnd) adminPage.subEnd.text=endDate;
                    break;
                }
            }

            // Get Pricing ID
            const pid=(r&&r.getPricingId)? r.getPricingId(vType,ticket):-1;
            if(pid<=0){ msg('Không tìm thấy bảng giá phù hợp'); return }

            // 3. Create Subscription in DB
            const sid = r.createSubscription(userId,pid,finalPlate,finalRfid,ticket,startDate,endDate,payment,price,'active', paymentMethod);

            if(sid===-2){
                msg('Đăng ký trùng lặp');
                return;
            } else if (sid > -1) {
                // Add Revenue
                if (price > 0 && r.insertRevenue) {
                    try {
                        r.insertRevenue(null, sid, userId, price, paymentMethod, 'subscription', isExtend ? 'extend' : 'create');
                    } catch (e) {}
                }

                // Update RFID Status to 'assigned' (Redundant if C++ handles it, but safe to keep)
                if (r.setRfidCardStatus) {
                    r.setRfidCardStatus(finalRfid, 'assigned');
                    console.log('[SubsLogic] Updated RFID status to assigned for:', finalRfid);
                }

                msg((isExtend ? 'Gia hạn' : 'Tạo') + ' đăng ký thành công');
                _inExtendedState = false;

                // Clear inputs
                if (!isExtend && adminPage) {
                    if (adminPage.subUserText) adminPage.subUserText.text = '';
                    if (adminPage.subPlate) adminPage.subPlate.text = '';
                    if (adminPage.subRfid) adminPage.subRfid.text = '';
                    if (adminPage.subPrice) adminPage.subPrice.text = '';
                    if (adminPage.subPlan && 'text' in adminPage.subPlan) adminPage.subPlan.text = '';
                    if (adminPage.subStart) adminPage.subStart.text = '';
                    if (adminPage.subEnd) adminPage.subEnd.text = '';
                }

                refreshSubs();
                fullRefresh(); // Refresh card cache too
                if(adminPage) adminPage.triggerSubsChanged = !adminPage.triggerSubsChanged;
                if(adminPage) adminPage.triggerUsersChanged = !adminPage.triggerUsersChanged;
            } else {
                msg('Lỗi lưu đăng ký vào CSDL');
            }
        }

    function updateSubscription(){
        if(selectedSubId <= 0){ msg('Chưa chọn đăng ký để cập nhật'); return; }
        const r=rRepo();
        if(!r || !r.updateSubscriptionPaymentDetails){ msg('Thiếu API updateSubscription'); return; }
        const paymentRaw = adminPage.subPayment ? adminPage.subPayment.currentText : '';
        const payment = paymentRaw.toLowerCase().indexOf('sau') >= 0 ? 'postpaid' : 'prepaid';
        const paymentMethodRaw = adminPage.subPaymentMethod ? adminPage.subPaymentMethod.currentText : '';
        const paymentMethod = paymentMethodRaw.toLowerCase().indexOf('chuy') >= 0 ? 'transfer' : 'cash';
        const ok = r.updateSubscriptionPaymentDetails(selectedSubId, payment, paymentMethod);
        if(ok){ msg('Cập nhật đăng ký thành công'); refreshSubs(); } else { msg('Lỗi khi cập nhật đăng ký'); }
    }

    function cancelExtend(){
        if(!_inExtendedState){ msg('Không có gia hạn để hủy'); return }
        if(adminPage){ if(adminPage.subStart) adminPage.subStart.text=_origStart; if(adminPage.subEnd) adminPage.subEnd.text=_origEnd }
        _inExtendedState=false; msg('Đã khôi phục ngày cũ')
    }

    Timer {
        interval: 60000; running: true; repeat: true;
        onTriggered: {
            const r=rRepo();
            if(r && r.expireDueSubscriptions){
                const day=todayIso(); const n=r.expireDueSubscriptions(day);
                if(n>0){ msg('Tự động hết hạn '+n+' đăng ký'); refreshSubs() }
            }
        }
    }

    function markLost(){
        if(selectedSubId<=0){ msg('Chưa chọn đăng ký'); return }
        const r=rRepo(); if(!r||!r.markSubscriptionLostCard){ msg('Thiếu API lost card'); return }
        const ok=r.markSubscriptionLostCard(selectedSubId);
        msg(ok?'Đã đánh dấu mất thẻ':'Không thể đánh dấu mất');
        if(ok){ refreshSubs(); selectedSubId=-1 }
    }

    function cancelSub(){
        if(selectedSubId<=0){ msg('Chưa chọn đăng ký'); return }
        const r=rRepo(); if(!r||!r.cancelSubscription){ msg('Thiếu API cancelSubscription'); return }
        const ok=r.cancelSubscription(selectedSubId);
        msg(ok?'Đã hủy đăng ký':'Không thể hủy');
        if(ok){ refreshSubs(); selectedSubId=-1 }
    }

    Connections {
        target: adminPage;
        function onTriggerSubCreateChanged(){ if(adminPage.triggerSubCreate){ createOrExtend(false); adminPage.triggerSubCreate=false } }
        function onTriggerSubExtendChanged(){ if(adminPage.triggerSubExtend){ createOrExtend(true); adminPage.triggerSubExtend=false } }
        function onTriggerSubUpdateChanged(){ if(adminPage.triggerSubUpdate){ updateSubscription(); adminPage.triggerSubUpdate=false } }
        function onTriggerSubCancelExtendChanged(){ if(adminPage.triggerSubCancelExtend){ cancelExtend(); adminPage.triggerSubCancelExtend=false } }
        function onTriggerSubLostDeleteChanged(){ if(adminPage.triggerSubLostDelete){ markLost(); adminPage.triggerSubLostDelete=false } }
        function onTriggerSubCancelChanged(){ if(adminPage.triggerSubCancel){ cancelSub(); adminPage.triggerSubCancel=false } }
        function onPendingSelectSubIndexChanged(){
            var idx=adminPage.pendingSelectSubIndex;
            if(idx>=0 && idx<listModel.count){
                var r=listModel.get(idx);
                selectSubscription(r.id, r.user_id, r.plate, r.rfid, r.plan_type, r.start_date, r.end_date, r.payment_mode, r.price, r.status, r.payment_method)
            }
        }
        function onTriggerUsersChangedChanged(){ fullRefresh() }

        function onTriggerSubUserTextChangedChanged(){
            if(adminPage.triggerSubUserTextChanged){
                if(adminPage && adminPage.subUserText){
                    var nm=adminPage.subUserText.text;
                    // CHANGED: Find in Card Owners cache
                    var card=findCardOwnerByName(nm);
                    if(card){
                        if(adminPage.subPlate) adminPage.subPlate.text=card.plate||'';
                        if(adminPage.subRfid) adminPage.subRfid.text=card.rfid||'';

                        const tk=currentTicketFromRfid();
                        setPlanLabel(tk)
                        if(adminPage.subStart){ const today=todayIso(); adminPage.subStart.text=today; updateEnd() }
                        // Pass null for userId initially, fallback to card's vehicle type
                        prefillPrice(-1, tk, card.vehicle_type);

                    } else {
                        if(adminPage.subPlate) adminPage.subPlate.text='';
                        if(adminPage.subRfid) adminPage.subRfid.text='';
                        if(adminPage.subPrice) adminPage.subPrice.text='';
                        if(adminPage.subPlan && ('text' in adminPage.subPlan)) adminPage.subPlan.text='';
                        if(adminPage.subStart) adminPage.subStart.text='';
                        if(adminPage.subEnd) adminPage.subEnd.text='';
                    }
                }
                adminPage.triggerSubUserTextChanged=false
            }
        }
    }

    // React when subPlan changes (Combobox/Text)
    Connections {
        target: (adminPage && adminPage.subPlan && ('currentIndex' in adminPage.subPlan)) ? adminPage.subPlan : null
        function onCurrentIndexChanged(){
            // Update price based on new plan selection
            const tk = currentTicketFromRfid() || planToTicket(readPlanText())
            prefillPrice(-1, tk) // Just use the ticket type, we might not have user ID yet
            updateEnd();
        }
        function onCurrentTextChanged(){ updateEnd(); }
    }
    Connections {
        target: (adminPage && adminPage.subPlan && ('text' in adminPage.subPlan)) ? adminPage.subPlan : null
        function onTextChanged(){ updateEnd(); }
    }
    Connections {
        target: adminPage?adminPage.subRfid:null;
        function onTextChanged(){
            const tk = currentTicketFromRfid();
            setPlanLabel(tk)
            prefillPrice(-1, tk)
            updateEnd();
        }
    }
    Connections {
        target: adminPage?adminPage.subStart:null;
        function onTextChanged(){ updateEnd() }
    }

    function fullRefresh(){ refreshCardOwners(); refreshSubs() }

    function setFilter(mode){ if(mode!==filterMode){ filterMode=mode; refreshSubs() } }

    function exportCsvForCurrentFilter(){
        const r=rRepo();
        if(!r||!r.listSubscriptions){ msg('Thiếu API listSubscriptions'); return }
        const rows=r.listSubscriptions(5000,0)||[]
        let filtered=[];
        let mode = filterMode;
        if(adminPage && adminPage.subFilter){
            const idx = adminPage.subFilter.currentIndex;
            mode = (idx===1?'expired':(idx===2?'active':'all'))
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
        msg('Đã tạo CSV '+filtered.length+' dòng (copy từ log hoặc buffer)')
    }

    Connections {
        target: adminPage
        function onTriggerSubFilterChangedChanged(){
            if(adminPage && adminPage.triggerSubFilterChanged){
                if(adminPage.subFilter){
                    const idx = adminPage.subFilter.currentIndex
                    if(idx===0) setFilter('all')
                    else if(idx===1) setFilter('expired')
                    else setFilter('active')
                }
                adminPage.triggerSubFilterChanged = false
            }
        }
        function onTriggerExportExpiredChanged(){
            if(adminPage && adminPage.triggerExportExpired){
                try { if (adminPage.subFilter) adminPage.subFilter.currentIndex = 1; } catch(e) {}
                exportCsvForCurrentFilter();
                try {
                    if (adminPage.subsFileSaveDialog) {
                        adminPage.subsFileSaveDialog.file = "dang_ky_" + (filterMode==='expired'?"het_han":"tat_ca") + ".csv";
                        adminPage.subsFileSaveDialog.open();
                    }
                } catch(e) { console.log(e) }
                adminPage.triggerExportExpired=false
            }
        }
    }
    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged(){ if(adminPage && adminPage.tabBar.currentIndex===4) fullRefresh() }
    }
    Component.onCompleted: { attachAdminPage(); fullRefresh(); }
    Connections {
        target: adminPage
        function onTriggerSubsChangedChanged() { refreshSubs(); adminPage.triggerSubsChanged = false; }
        function onTriggerSubsSaveDialogAcceptedChanged() {
            if (adminPage.triggerSubsSaveDialogAccepted) {
                const r = rRepo();
                if (r && r.saveTextToFile && adminPage.subsFileSaveDialog) {
                    try {
                        const dialog = adminPage.subsFileSaveDialog;
                        const path = dialog.selectedFile || (dialog.selectedFiles && dialog.selectedFiles.length > 0 ? dialog.selectedFiles[0] : "");
                        const ok = r.saveTextToFile(path, adminPage.expiredCsvBuffer || "");
                        msg(ok ? "Đã lưu file CSV đăng ký" : "Lỗi khi lưu file");
                    } catch(e) { console.log('[SubscriptionsLogic] Save dialog error:', e); msg("Lỗi khi lưu file"); }
                } else { msg("Thiếu API lưu file"); }
                adminPage.triggerSubsSaveDialogAccepted = false;
            }
        }
    }
    Connections {
        target: adminPage ? adminPage.subPlatePick : null
        function onVisibleChanged(){
            if (adminPage && adminPage.subPlatePick && adminPage.subPlatePick.visible &&
                (adminPage.subPlatePick.currentIndex === -1 || adminPage.subPlatePick.currentIndex === undefined)) {
                try {
                    if (adminPage.subPlatePick.popup && !adminPage.subPlatePick.popup.visible) { adminPage.subPlatePick.popup.open(); }
                    else if (adminPage.subPlatePick.showPopup) { adminPage.subPlatePick.showPopup(); }
                    adminPage.subPlatePick.forceActiveFocus();
                } catch(e) {}
            }
        }
    }
}
