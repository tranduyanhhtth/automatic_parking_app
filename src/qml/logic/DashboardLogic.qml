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
    function refresh(){ if(typeof repo==='undefined'||!repo.getDashboardStats) return; const stats=repo.getDashboardStats(todayIso())||{}; inToday=parseInt(stats.in_today||0); outToday=parseInt(stats.out_today||0); revenueToday=parseInt(stats.revenue_today||0); expiredSubs=parseInt(stats.expired_subscriptions||0); if(adminPage){ if(adminPage.cardInToday) adminPage.cardInToday.text=''+inToday; if(adminPage.cardOutToday) adminPage.cardOutToday.text=''+outToday; if(adminPage.cardRevenueToday) adminPage.cardRevenueToday.text=revenueToday+' VNĐ'; if(adminPage.cardExpiredSubs) adminPage.cardExpiredSubs.text=''+expiredSubs } }

    // Charts helpers
    function refreshDailyChart(series, axisX, axisY, fromIso, toIso){
        if (!series || !axisX || !axisY) return;
        if (typeof repo==='undefined' || !repo.listRevenueSummary) return;
        const f = fromIso || defaultFrom();
        const t = toIso || todayIso();
        const rows = repo.listRevenueSummary(f, t, 'all') || [];
        series.clear();
        let maxY = 0;
        for (let i=rows.length-1; i>=0; --i){
            const r = rows[i];
            const d = new Date((r.d||'')+"T00:00:00");
            const v = parseInt(r.total_amount||0);
            series.append(d.getTime(), v);
            if (v>maxY) maxY=v;
        }
        axisY.min = 0;
        axisY.max = maxY>0 ? Math.round(maxY*1.2) : 1;
        if (rows.length>0){
            const d0 = new Date(rows[rows.length-1].d+"T00:00:00");
            const d1 = new Date(rows[0].d+"T00:00:00");
            axisX.min = d0;
            axisX.max = d1;
        }
    }
    function refreshBreakdownPie(pieSeries, fromIso, toIso){
        if (!pieSeries) return;
        if (typeof repo==='undefined' || !repo.listRevenueSummary) return;
        const f = fromIso || defaultFrom();
        const t = toIso || todayIso();
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
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { refresh(); refreshCharts() } }
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
