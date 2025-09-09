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
    function todayIso(){ const d=new Date(); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function defaultFrom(){ const d=new Date(); d.setDate(d.getDate()-30); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function refresh(){ if(!adminPage) return; if(!adminPage.revFrom || !adminPage.revTo) return; if(typeof repo==='undefined'||!repo.listRevenueSummary) return; const f=adminPage.revFrom.text||defaultFrom(); const t=adminPage.revTo.text||todayIso(); const tp = (!adminPage.revType)?'all': (adminPage.revType.currentIndex===1?'session': (adminPage.revType.currentIndex===2?'subscription':'all')); const rows = repo.listRevenueSummary(f,t,tp)||[]; revenueModel.clear(); totalRevenue=0; totalSession=0; totalSubscription=0; for(let i=0;i<rows.length;i++){ const r=rows[i]; totalRevenue += parseInt(r.total_amount||0); totalSession += parseInt(r.session_count||0); totalSubscription += parseInt(r.subscription_count||0); revenueModel.append(r) } if(adminPage){ if(adminPage.revSummaryTotal) adminPage.revSummaryTotal.text='Tổng doanh thu: '+totalRevenue; if(adminPage.revSummaryBreakdown) adminPage.revSummaryBreakdown.text='Trong đó: vé lượt '+totalSession+', vé tháng '+totalSubscription } }
    Component.onCompleted: refresh()
}
