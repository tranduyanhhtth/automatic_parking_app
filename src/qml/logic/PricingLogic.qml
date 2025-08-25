import QtQuick

Item {
    Connections {
        target: form.miAdmin
        function onTriggered() { form.adminDialog.dialog.open() }
    }
    Connections {
        target: form.adminDialog.dialog
        function onTriggerLoginChanged() {
            const username = form.adminDialog.dialog.loginUser
            const password = form.adminDialog.dialog.loginPass
            const ok = root.allowedAccounts.some(a => a.username === username && a.password === password)
            form.adminDialog.dialog.loggedIn = ok
            form.adminDialog.dialog.error = ok ? "" : "Sai tài khoản hoặc mật khẩu"
        }
        function onTriggerSavePricingChanged() {
            var base = {
                grace_minutes: parseInt(form.pricingGrace.text) || 0,
                base_minutes: parseInt(form.pricingBaseMinutes.text) || 0,
                base_price: parseInt(form.pricingBasePrice.text) || 0,
                increment_minutes: parseInt(form.pricingIncMinutes.text) || 0,
                increment_price: parseInt(form.pricingIncPrice.text) || 0,
                cap_per_day: parseInt(form.pricingCapPerDay.text) || 0
            }
            var slots = []
            for (var i = 0; i < form.pricingSlotsModel.count; ++i) {
                var it = form.pricingSlotsModel.get(i)
                slots.push({
                    start: it.start || "",
                    end: it.end || "",
                    pricing: {
                        increment_minutes: parseInt(it.inc_minutes) || 0,
                        increment_price: parseInt(it.inc_price) || 0,
                        cap: parseInt(it.cap) || 0
                    }
                })
            }
            var json = {
                base: base,
                incremental: form.pricingIncremental.currentText,
                time_slots: slots,
                rules: {
                    overnight_fee: parseInt(form.pricingOvernight.text) || 0,
                    lost_card_penalty: parseInt(form.pricingLostCard.text) || 0
                }
            }
            if (!repo) { root.showToast("Repo không sẵn sàng"); return }
            const ok = repo.savePricingJson(form.pricingVehicleCombo.currentText, form.pricingTicketCombo.currentText, JSON.stringify(json), "ui update")
            root.showToast(ok ? "Đã lưu bảng giá" : "Lỗi lưu bảng giá")
        }
        function onTriggerLoadPricingChanged() {
            if (!repo) { root.showToast("Repo không sẵn sàng"); return }
            const m = repo.getLatestPricing(form.pricingVehicleCombo.currentText, form.pricingTicketCombo.currentText)
            if (!m) { root.showToast("Chưa có cấu hình"); return }
            try {
                var js = null
                if (m.json) {
                    js = m.json
                } else if (m.time_slot_text && m.time_slot_text.length > 0) {
                    js = JSON.parse(m.time_slot_text)
                }
                if (!js) { root.showToast("Dữ liệu rỗng"); return }
                form.pricingGrace.text = (js.base && js.base.grace_minutes != null) ? ("" + js.base.grace_minutes) : ""
                form.pricingBaseMinutes.text = (js.base && js.base.base_minutes != null) ? ("" + js.base.base_minutes) : ""
                form.pricingBasePrice.text = (js.base && js.base.base_price != null) ? ("" + js.base.base_price) : ""
                form.pricingIncMinutes.text = (js.base && js.base.increment_minutes != null) ? ("" + js.base.increment_minutes) : ""
                form.pricingIncPrice.text = (js.base && js.base.increment_price != null) ? ("" + js.base.increment_price) : ""
                form.pricingCapPerDay.text = (js.base && js.base.cap_per_day != null) ? ("" + js.base.cap_per_day) : ""
                var incIdx = ["flat", "increasing", "decreasing"].indexOf(js.incremental || "flat")
                form.pricingIncremental.currentIndex = incIdx < 0 ? 0 : incIdx
                form.pricingOvernight.text = (js.rules && js.rules.overnight_fee != null) ? ("" + js.rules.overnight_fee) : ""
                form.pricingLostCard.text = (js.rules && js.rules.lost_card_penalty != null) ? ("" + js.rules.lost_card_penalty) : ""
                form.pricingSlotsModel.clear()
                if (js.time_slots && js.time_slots.length) {
                    for (var i = 0; i < js.time_slots.length; ++i) {
                        var s = js.time_slots[i]
                        var p = s.pricing || {}
                        form.pricingSlotsModel.append({
                            start: s.start || "",
                            end: s.end || "",
                            inc_minutes: p.increment_minutes || 0,
                            inc_price: p.increment_price || 0,
                            cap: p.cap || 0
                        })
                    }
                }
                root.showToast("Đã tải cấu hình")
            } catch (e) {
                root.showToast("Dữ liệu không hợp lệ")
            }
        }
        function onTriggerAddSlotChanged() {
            form.pricingSlotsModel.append({ start: "07:00", end: "19:00", inc_minutes: 60, inc_price: 5000, cap: 0 })
        }
    }
}