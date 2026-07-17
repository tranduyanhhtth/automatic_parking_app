import QtQuick
import "./"

// Orchestrator for Admin area: delegates to tab-level logic modules
Item {
    id: adminLogic
    // References
    property Item adminPage           // AdminPage.ui.qml instance
    property var notify               // function(message)
    property var authManager          // C++ AuthManager context object
    property alias rfidLogic: rfidLogic
    property alias subsLogic: subsLogic
    property alias usersLogic: usersLogic
    property alias employeeLogic: employeeLogic

    // Sub-logic modules
    LoginLogic {
        id: loginLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
        authManager: adminLogic.authManager
    }
    UsersLogic {
        id: usersLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
    }
    EmployeeLogic {
        id: employeeLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
    }
    SubscriptionsLogic {
        id: subsLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
    }
    RevenueLogic { 
        id: revenueLogic
        adminPage: adminLogic.adminPage 
        notify: adminLogic.notify 
    }
    DashboardLogic { 
        id: dashboardLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
    }
    RfidCardsLogic {
        id: rfidLogic
        adminPage: adminLogic.adminPage
        notify: adminLogic.notify
    }

    // Pricing save pipeline (migrated from AdminPricingActions)
    Connections {
        target: adminLogic.adminPage
        function onTriggerSavePricingChanged() {
            if (!adminLogic.adminPage || !adminLogic.adminPage.triggerSavePricing) return
            // Try use JSON produced by Pricing UI
            let json = null
            try {
                if (adminLogic.adminPage.pricingJson && adminLogic.adminPage.pricingJson.text && adminLogic.adminPage.pricingJson.text.length > 0) {
                    json = adminLogic.adminPage.pricingJson.text
                }
            } catch(e) { json = null }
            if (!json) {
                try { console.log('[AdminLogic] No JSON from UI; aborting save') } catch(e) {}
                adminLogic.adminPage.triggerSavePricing = false
                if (adminLogic.notify) adminLogic.notify('Thiếu dữ liệu để lưu')
                return
            }
            let ok = false
            let savedCount = 0
            try {
                const arr = JSON.parse(json)
                try { console.log('[AdminLogic] Parsed JSON type:', Array.isArray(arr) ? 'array' : (typeof arr), 'length:', Array.isArray(arr) ? arr.length : -1) } catch(e) {}
                try { console.log('[AdminLogic] repo exists:', (typeof repo !== 'undefined'), 'has upsertPricingRow:', (repo && typeof repo.upsertPricingRow !== 'undefined')) } catch(e) {}
                if (Array.isArray(arr) && typeof repo !== 'undefined' && repo.upsertPricingRow) {
                    for (let i = 0; i < arr.length; ++i) {
                        const r = arr[i] || {}
                        const vt = (r.vehicle_type || '').toString()
                        const tt = (r.ticket_type || '').toString()
                        const base = parseInt(r.base_fee || 0)
                        const dur = (r.duration_minutes === null || r.duration_minutes === undefined) ? -1 : parseInt(r.duration_minutes)
                        const inc = (r.incremental_fee === null || r.incremental_fee === undefined) ? -1 : parseInt(r.incremental_fee)
                        const cap = (r.max_daily_fee === null || r.max_daily_fee === undefined) ? -1 : parseInt(r.max_daily_fee)
                        const disc = (r.discount_percentage === null || r.discount_percentage === undefined) ? 0 : parseFloat(r.discount_percentage)
                        const grace = (r.grace_period === null || r.grace_period === undefined) ? 0 : parseInt(r.grace_period)
                        const desc = (r.description || '').toString()
                        const st = (r.start_time || '').toString()
                        const et = (r.end_time || '').toString()
                        try { console.log('[AdminLogic] Upsert row', i, vt, tt, 'base', base) } catch(e) {}
                        const okRow = repo.upsertPricingRow(vt, tt, base, dur, inc, cap, disc, grace, desc, st, et)
                        if (okRow) savedCount++
                    }
                    ok = savedCount > 0
                    try { console.log('[AdminLogic] Saved rows count:', savedCount) } catch(e) {}
                } else {
                    try { console.log('[AdminLogic] Not an array JSON or missing repo.upsertPricingRow; aborting save.') } catch(e) {}
                    ok = false
                }
            } catch (e) {
                try { console.log('[AdminLogic] JSON parse error:', e) } catch(e2) {}
                ok = false
            }
            if (adminLogic.notify) adminLogic.notify(ok ? 'Đã lưu bảng giá' : 'Không thể lưu bảng giá')
            adminLogic.adminPage.triggerSavePricing = false
        }
    }
}
