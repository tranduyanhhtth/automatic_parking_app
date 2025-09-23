import QtQuick

Item {
    id: revenueLogic
    property Item adminPage
    property var notify
    ListModel { id: revenueModel }
    property alias listModel: revenueModel
    property int totalRevenue: 0
    property int totalSession: 0
    property int totalSubscription: 0
    // Preset triggers
    property bool triggerPreset7: false
    property bool triggerPreset30: false
    property bool triggerPreset90: false
    property bool triggerSeedDemo: false
    function todayIso(){ const d=new Date(); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function defaultFrom(){ const d=new Date(); d.setDate(d.getDate()-30); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    property string _revReqKey: ""
    function refresh(){
        if(!adminPage) return; if(!adminPage.revFrom || !adminPage.revTo) return; if(typeof repo==='undefined') return;
        const f=adminPage.revFrom.text||defaultFrom(); const t=adminPage.revTo.text||todayIso(); const tp = (!adminPage.revType)?'all': (adminPage.revType.currentIndex===1?'parking_session': (adminPage.revType.currentIndex===2?'subscription':'all'));
        _revReqKey = f+"|"+t+"|"+tp;
        if (repo.listRevenueSummaryAsync) { repo.listRevenueSummaryAsync(f,t,tp); return; }
        if (!repo.listRevenueSummary) return;
        const rows = repo.listRevenueSummary(f,t,tp)||[];
        revenueModel.clear(); totalRevenue=0; totalSession=0; totalSubscription=0;
        for(let i=0;i<rows.length;i++){ const r=rows[i]; totalRevenue += parseInt(r.total_amount||0); totalSession += parseInt(r.session_count||0); totalSubscription += parseInt(r.subscription_count||0); revenueModel.append(r) }
        if(adminPage){ if(adminPage.revSummaryTotal) adminPage.revSummaryTotal.text='Tổng doanh thu: '+totalRevenue; if(adminPage.revSummaryBreakdown) adminPage.revSummaryBreakdown.text='Trong đó: vé lượt '+totalSession+', vé tháng '+totalSubscription }
    }
    // Debounce filter to avoid spamming DB when user clicks fast
    property bool _debouncing: false
    function _debouncedRefresh(){
        if(_debouncing) return;
        _debouncing = true;
        Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 200; running: true; repeat: false; onTriggered: { revenueLogic._debouncing=false; revenueLogic.refresh() } }', revenueLogic)
    }
    function buildDate(yIndex, mIndex, dIndex) {
        var y = 2000 + (yIndex|0);
        var m = (mIndex|0) + 1; if (m < 10) m = "0"+m; else m = ""+m;
        var d = (dIndex|0) + 1; if (d < 10) d = "0"+d; else d = ""+d;
        return y + "-" + m + "-" + d;
    }
    Connections {
        target: adminPage
        function onTriggerRevFromSelectChanged() {
            if (!adminPage || !adminPage.triggerRevFromSelect) return;
            try {
                var y = adminPage.revFromYear ? adminPage.revFromYear.currentIndex : 25;
                var m = adminPage.revFromMonth ? adminPage.revFromMonth.currentIndex : 0;
                var d = adminPage.revFromDay ? adminPage.revFromDay.currentIndex : 0;
                var iso = buildDate(y, m, d);
                if (adminPage.revFrom) adminPage.revFrom.text = iso;
            } finally {
                adminPage.revFromPickerVisible = false;
                adminPage.triggerRevFromSelect = false;
            }
            _debouncedRefresh();
        }
        function onTriggerRevToSelectChanged() {
            if (!adminPage || !adminPage.triggerRevToSelect) return;
            try {
                var y = adminPage.revToYear ? adminPage.revToYear.currentIndex : 25;
                var m = adminPage.revToMonth ? adminPage.revToMonth.currentIndex : 0;
                var d = adminPage.revToDay ? adminPage.revToDay.currentIndex : 0;
                var iso = buildDate(y, m, d);
                if (adminPage.revTo) adminPage.revTo.text = iso;
            } finally {
                adminPage.revToPickerVisible = false;
                adminPage.triggerRevToSelect = false;
            }
            _debouncedRefresh();
        }
        function onTriggerRevenueFilterChanged() {
            _debouncedRefresh();
        }
    }
    // Handle async result
    Connections {
        target: repo
        function onRevenueSummaryReady(fromIso, toIso, typeFilter, rows){
            const key = (fromIso||'')+"|"+(toIso||'')+"|"+(typeFilter||'');
            if (key !== _revReqKey) return;
            if (!rows) rows = []
            revenueModel.clear(); totalRevenue=0; totalSession=0; totalSubscription=0;
            for(let i=0;i<rows.length;i++){ const r=rows[i]; totalRevenue += parseInt(r.total_amount||0); totalSession += parseInt(r.session_count||0); totalSubscription += parseInt(r.subscription_count||0); revenueModel.append(r) }
            if(adminPage){ if(adminPage.revSummaryTotal) adminPage.revSummaryTotal.text='Tổng doanh thu: '+totalRevenue; if(adminPage.revSummaryBreakdown) adminPage.revSummaryBreakdown.text='Trong đó: vé lượt '+totalSession+', vé tháng '+totalSubscription }
        }
    }
    Connections {
        target: revenueLogic
        function onTriggerPreset7Changed() {
            if (!revenueLogic.triggerPreset7) return;
            const to = todayIso();
            const d = new Date(); d.setDate(d.getDate()-7);
            function p(n){return n<10?'0'+n:n}
            const from = d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate());
            if (adminPage && adminPage.revFrom) adminPage.revFrom.text = from;
            if (adminPage && adminPage.revTo) adminPage.revTo.text = to;
            revenueLogic.triggerPreset7 = false;
            refresh();
        }
        function onTriggerPreset30Changed() {
            if (!revenueLogic.triggerPreset30) return;
            const to = todayIso();
            const d = new Date(); d.setDate(d.getDate()-30);
            function p(n){return n<10?'0'+n:n}
            const from = d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate());
            if (adminPage && adminPage.revFrom) adminPage.revFrom.text = from;
            if (adminPage && adminPage.revTo) adminPage.revTo.text = to;
            revenueLogic.triggerPreset30 = false;
            refresh();
        }
        function onTriggerPreset90Changed() {
            if (!revenueLogic.triggerPreset90) return;
            const to = todayIso();
            const d = new Date(); d.setDate(d.getDate()-90);
            function p(n){return n<10?'0'+n:n}
            const from = d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate());
            if (adminPage && adminPage.revFrom) adminPage.revFrom.text = from;
            if (adminPage && adminPage.revTo) adminPage.revTo.text = to;
            revenueLogic.triggerPreset90 = false;
            refresh();
        }
        function onTriggerSeedDemoChanged() {
            if (!revenueLogic.triggerSeedDemo) return;
            try {
                if (typeof repo!== 'undefined' && typeof repo.seedDemoDataAsync === 'function') {
                    repo.seedDemoDataAsync(30, 40, 6);
                    if (notify) notify("Đang tạo dữ liệu demo...");
                } else if (typeof repo.seedDemoData === 'function') {
                    repo.seedDemoData(30, 40, 6);
                    if (notify) notify("Đã tạo dữ liệu demo");
                }
            } catch (e) {}
            revenueLogic.triggerSeedDemo = false;
        }
    }
    Component.onCompleted: {
        if (adminPage) {
            if (adminPage.revFrom && !adminPage.revFrom.text) adminPage.revFrom.text = defaultFrom();
            if (adminPage.revTo && !adminPage.revTo.text) adminPage.revTo.text = todayIso();
        }
        // Defer empty-db seeding slightly to avoid blocking UI thread at startup
        Qt.callLater(function(){
            try {
                if (typeof repo!== 'undefined' && repo.listRevenueSummary) {
                    var rows = repo.listRevenueSummary(defaultFrom(), todayIso(), 'all') || [];
                    if ((rows.length|0) === 0) {
                        if (typeof repo.seedDemoDataAsync === 'function') repo.seedDemoDataAsync(30, 40, 6);
                        else if (typeof repo.seedDemoData === 'function') repo.seedDemoData(30, 40, 6);
                    }
                }
            } catch(e) {}
            refresh();
        });
    }

    // Refresh upon async seeding done
    Connections {
        target: repo
        function onSeedDemoDone(ok){ if (notify) notify(ok?"Đã tạo dữ liệu demo":"Tạo dữ liệu demo lỗi"); revenueLogic.refresh(); }
    }
}
