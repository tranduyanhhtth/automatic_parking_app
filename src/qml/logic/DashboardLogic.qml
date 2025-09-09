import QtQuick

Item {
    id: dashboardLogic
    property Item adminPage
    property var notify
    property int inToday: 0
    property int outToday: 0
    property int revenueToday: 0
    property int expiredSubs: 0
    function todayIso(){ const d=new Date(); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function refresh(){ if(typeof repo==='undefined'||!repo.getDashboardStats) return; const stats=repo.getDashboardStats(todayIso())||{}; inToday=parseInt(stats.in_today||0); outToday=parseInt(stats.out_today||0); revenueToday=parseInt(stats.revenue_today||0); expiredSubs=parseInt(stats.expired_subscriptions||0); if(adminPage){ if(adminPage.cardInToday) adminPage.cardInToday.text=''+inToday; if(adminPage.cardOutToday) adminPage.cardOutToday.text=''+outToday; if(adminPage.cardRevenueToday) adminPage.cardRevenueToday.text=revenueToday+' VNĐ'; if(adminPage.cardExpiredSubs) adminPage.cardExpiredSubs.text=''+expiredSubs } }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: refresh() }
    Component.onCompleted: refresh()
}
