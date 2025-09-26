import QtQuick

Item {
    id: dashboardLogic
    signal ready()
    signal refreshCharts()
    property Item adminPage
    property var notify
    property int inToday: 0
    property int outToday: 0
    property int revenueToday: 0
    property int expiredSubs: 0
    function todayIso(){ const d=new Date(); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function defaultFrom(){ const d=new Date(); d.setDate(d.getDate()-30); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    // Async-aware refresh of dashboard cards
    property string _statsReqKey: ""
    function refresh(){
        if (typeof repo==='undefined') return;
        const t=todayIso();
        _statsReqKey = t;
        if (repo.getDashboardStatsAsync) {
            repo.getDashboardStatsAsync(t);
            return;
        }
        if (!repo.getDashboardStats) return;
        const stats=repo.getDashboardStats(t)||{}; inToday=parseInt(stats.in_today||0); outToday=parseInt(stats.out_today||0); revenueToday=parseInt(stats.revenue_today||0); expiredSubs=parseInt(stats.expired_subscriptions||0); if(adminPage){ if(adminPage.cardInToday) adminPage.cardInToday.text=''+inToday; if(adminPage.cardOutToday) adminPage.cardOutToday.text=''+outToday; if(adminPage.cardRevenueToday) adminPage.cardRevenueToday.text=revenueToday+' VNĐ'; if(adminPage.cardExpiredSubs) adminPage.cardExpiredSubs.text=''+expiredSubs }
    }

    function daysAgoIso(days) {
        const d = new Date();
        d.setDate(d.getDate() - days);
        function p(n){return n<10?'0'+n:n}
        return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate());
    }

    function updateDailyChartRange(rangeIndex) {
        let fromDate;
        switch (rangeIndex) {
            case 0: // 7 days
                fromDate = daysAgoIso(7);
                break;
            case 1: // 30 days
                fromDate = daysAgoIso(30);
                break;
            case 2: // 90 days
                fromDate = daysAgoIso(90);
                break;
            default: // Fallback
                fromDate = daysAgoIso(30);
                break;
        }

        // Check if the chart objects are available and call the existing refresh function
        if (_dailySeries && _dailyAxisX && _dailyAxisY) {
            refreshDailyChart(_dailySeries, _dailyAxisX, _dailyAxisY, fromDate, todayIso());
        }
    }

    // Charts helpers
    property string _dailyReqKey: ""
    property var _dailySeries
    property var _dailyAxisX
    property var _dailyAxisY
    function refreshDailyChart(series, axisX, axisY, fromIso, toIso){
        if (!series || !axisX || !axisY) return;
        if (typeof repo==='undefined') return;
        const f = fromIso || defaultFrom();
        const t = toIso || todayIso();
        _dailySeries = series; _dailyAxisX = axisX; _dailyAxisY = axisY;
        _dailyReqKey = f+"|"+t+"|all";
        if (repo.listRevenueSummaryAsync) {
            repo.listRevenueSummaryAsync(f, t, 'all');
            return;
        }
        if (!repo.listRevenueSummary) return;
        const rows = repo.listRevenueSummary(f, t, 'all') || [];
        series.clear();
        let maxY = 0;
        for (let i=rows.length-1; i>=0; --i){
            const r = rows[i];
            const d = new Date((r.d||'')+"T00:00:00");
            const v = parseInt(r.total_amount||0);
            const vk = Math.floor(v/1000);
            series.append(d.getTime(), vk);
            if (vk>maxY) maxY=vk;
        }
        axisY.min = 0;
        axisY.max = maxY>0 ? Math.round(maxY*1.2) : 1;
        if (rows.length>0){
            const d0 = new Date(rows[rows.length-1].d+"T00:00:00");
            const d1 = new Date(rows[0].d+"T00:00:00");
            axisX.min = new Date(f + "T00:00:00");
            axisX.max = new Date(f + "T00:00:00");
        }
    }
    property string _pieReqKey: ""
    property var _pieSeries
    function refreshBreakdownPie(pieSeries, fromIso, toIso){
        if (!pieSeries) return;
        if (typeof repo==='undefined') return;
        const f = fromIso || defaultFrom();
        const t = toIso || todayIso();
        _pieSeries = pieSeries;
        _pieReqKey = f+"|"+t+"|all";
        if (repo.listRevenueSummaryAsync) { repo.listRevenueSummaryAsync(f, t, 'all'); return; }
        if (!repo.listRevenueSummary) return;
        const rows = repo.listRevenueSummary(f, t, 'all') || [];
        let sessionTotal = 0, subTotal = 0;
        for (let i=0;i<rows.length;i++){
            const r=rows[i];
            sessionTotal += parseInt(r.session_count||0);
            subTotal += parseInt(r.subscription_count||0);
        }
        pieSeries.clear();
        pieSeries.append("Vé lượt", sessionTotal);
        pieSeries.append("Vé tháng", subTotal);
        try {
            for (var i=0;i<pieSeries.count;i++) { pieSeries.at(i).labelVisible = true; }
        } catch(e) {}
    }

    // New: 7-type revenue chart (hourly, daily_day, daily_night, overnight, monthly, quarterly, yearly)
    property string _barReqKey: ""
    property var _barSeries
    property var _barCatAxis
    property var _barValAxis
    function refreshByTicketBar(barSeries, catAxis, valAxis, fromIso, toIso){
        if (!barSeries || !catAxis || !valAxis) return;
        if (typeof repo==='undefined') return;
        const f = fromIso || defaultFrom();
        const t = toIso || todayIso();
        _barSeries = barSeries; _barCatAxis = catAxis; _barValAxis = valAxis;
        _barReqKey = f+"|"+t;
        if (repo.listRevenueByTicketTypeAsync) { repo.listRevenueByTicketTypeAsync(f, t); return; }
        if (!repo.listRevenueByTicketType) return;
    const rows = repo.listRevenueByTicketType(f, t) || [];
        const order = ["hourly","daily_day","daily_night","overnight","monthly","quarterly","yearly"];
        const labels = ["Giờ","Ngày (ngày)","Ngày (đêm)","Qua đêm","Tháng","Quý","Năm"];
        const map = {};
    for (let i=0;i<rows.length;i++){ const r=rows[i]; const k=(''+(r.ticket_type||'')).toLowerCase(); map[k]=Math.floor(parseInt(r.total_amount||0)/1000); }
    const data = order.map(k => map[k]||0);
        // Prepare axes
        catAxis.categories = labels;
        valAxis.min = 0;
        const max = data.reduce((a,b)=>Math.max(a,b),0);
        valAxis.max = max>0 ? Math.round(max*1.2) : 1;
        // Reset series and append one bar set
        try { barSeries.clear(); } catch(e) {}
        barSeries.append("Doanh thu", data);
    }
    // Handle async results
    Connections {
        target: repo
        function onDashboardStatsReady(day, stats){
            if (day !== _statsReqKey) return;
            const s=stats||{}; inToday=parseInt(s.in_today||0); outToday=parseInt(s.out_today||0); revenueToday=parseInt(s.revenue_today||0); expiredSubs=parseInt(s.expired_subscriptions||0);
            if(adminPage){ if(adminPage.cardInToday) adminPage.cardInToday.text=''+inToday; if(adminPage.cardOutToday) adminPage.cardOutToday.text=''+outToday; if(adminPage.cardRevenueToday) adminPage.cardRevenueToday.text=revenueToday+' VNĐ'; if(adminPage.cardExpiredSubs) adminPage.cardExpiredSubs.text=''+expiredSubs }            
        }
        function onRevenueSummaryReady(fromIso, toIso, typeFilter, rows){
            const key = fromIso+"|"+toIso+"|"+typeFilter;
            // daily
            if (key === _dailyReqKey) {
                const series = _dailySeries; const axisX = _dailyAxisX; const axisY = _dailyAxisY;
                if (series && axisX && axisY){
                    series.clear();
                    let maxY = 0;
                    for (let i=rows.length-1; i>=0; --i){
                        const r = rows[i]; const d = new Date((r.d||'')+"T00:00:00"); const v = parseInt(r.total_amount||0); const vk=Math.floor(v/1000);
                        series.append(d.getTime(), vk); if (vk>maxY) maxY=vk;
                    }
                    axisY.min=0; axisY.max = maxY>0 ? Math.round(maxY*1.2) : 1;
                    if (rows.length>0){ const d0=new Date(rows[rows.length-1].d+"T00:00:00"); const d1=new Date(rows[0].d+"T00:00:00"); axisX.min= new Date(fromIso + "T00:00:00"); axisX.max= new Date(toIso + "T00:00:00"); }
                }
            }
            // pie
            if (key === _pieReqKey) {
                const pieSeries = _pieSeries;
                if (pieSeries){ let sc=0, sub=0; for(let i=0;i<rows.length;i++){ const r=rows[i]; sc+=parseInt(r.session_count||0); sub+=parseInt(r.subscription_count||0) } pieSeries.clear(); pieSeries.append("Vé lượt", sc); pieSeries.append("Vé tháng", sub); try { for (var i=0;i<pieSeries.count;i++) { pieSeries.at(i).labelVisible = true; } } catch(e) {} }
            }
        }
        function onRevenueByTicketReady(fromIso, toIso, rows){
            const key = fromIso+"|"+toIso;
            if (key !== _barReqKey) return;
            const barSeries = _barSeries; const catAxis = _barCatAxis; const valAxis = _barValAxis;
            if (!barSeries || !catAxis || !valAxis) return;
            const order = ["hourly","daily_day","daily_night","overnight","monthly","quarterly","yearly"];
            const labels = ["Giờ","Ngày (ngày)","Ngày (đêm)","Qua đêm","Tháng","Quý","Năm"];
            const map = {}; for (let i=0;i<rows.length;i++){ const r=rows[i]; const k=(''+(r.ticket_type||'')).toLowerCase(); map[k]=Math.floor(parseInt(r.total_amount||0)/1000); }
            const data = order.map(k => map[k]||0);
            catAxis.categories = labels; valAxis.min=0; const max=data.reduce((a,b)=>Math.max(a,b),0); valAxis.max = max>0 ? Math.round(max*1.2) : 1;
            try { barSeries.clear(); } catch(e) {}
            barSeries.append("Doanh thu", data);
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (adminPage && adminPage.tabBar && adminPage.tabBar.currentIndex === 0 && (!adminPage.loginVisible)) {
                refresh();
                refreshCharts();
            }
        }
    }
    Component.onCompleted: {
        refresh()
        // Defer ready emission to ensure UI is constructed
        if (Qt && Qt.callLater) {
            Qt.callLater(function(){ ready() })
        } else {
            ready()
        }
    }
}
