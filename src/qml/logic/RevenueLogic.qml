import QtQuick

Item {
    id: revenueLogic
    property Item adminPage
    property var notify
    ListModel { id: revenueModel }
    property alias listModel: revenueModel
    property double totalRevenue: 0
    property int totalSession: 0
    property int totalSubscription: 0
    property bool triggerExportExcel: false
    // Preset triggers
    property bool triggerPreset7: false
    property bool triggerPreset30: false
    property bool triggerPreset90: false
    property bool triggerSeedDemo: false
    property string generatedCsvData: ""

    function todayIso(){ const d=new Date(); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    function defaultFrom(){ const d=new Date(); d.setDate(d.getDate()-30); function p(n){return n<10?'0'+n:n} return d.getFullYear()+"-"+p(d.getMonth()+1)+"-"+p(d.getDate()) }
    property string _revReqKey: ""
    function refresh(){
        if(!adminPage) return; if(!adminPage.revFrom || !adminPage.revTo) return; if(typeof repo==='undefined') return;
        const f=adminPage.revFrom.text||defaultFrom(); const t=adminPage.revTo.text||todayIso(); const tp = (!adminPage.revType)?'all': (adminPage.revType.currentIndex===1?'parking_session': (adminPage.revType.currentIndex===2?'subscription':'all'));
        _revReqKey = f+"|"+t+"|"+tp; if (repo.listRevenueSummaryAsync) { repo.listRevenueSummaryAsync(f,t,tp); return; }
        if (!repo.listRevenueSummary) return;
        const rows = repo.listRevenueSummary(f,t,tp)||[]; revenueModel.clear(); totalRevenue=0; totalSession=0; totalSubscription=0;
        for(let i=0;i<rows.length;i++){ const r=rows[i]; totalRevenue += parseInt(r.total_amount||0); totalSession += parseInt(r.session_count||0); totalSubscription += parseInt(r.subscription_count||0); revenueModel.append(r) }
        if(adminPage){ if(adminPage.revSummaryTotal) adminPage.revSummaryTotal.text='Tổng doanh thu: '+totalRevenue; if(adminPage.revSummaryBreakdown) adminPage.revSummaryBreakdown.text='Trong đó: vé lượt '+totalSession+', vé tháng '+totalSubscription }
    }
    property bool _debouncing: false
    function _debouncedRefresh(){
        if(_debouncing) return; _debouncing = true;
        Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 200; running: true; repeat: false; onTriggered: { revenueLogic._debouncing=false; revenueLogic.refresh() } }', revenueLogic)
    }
    function buildDate(yIndex, mIndex, dIndex) {
        var y = 2000 + (yIndex|0); var m = (mIndex|0) + 1; if (m < 10) m = "0"+m; else m = ""+m; var d = (dIndex|0) + 1; if (d < 10) d = "0"+d; else d = ""+d; return y + "-" + m + "-" + d;
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

        function onTriggerExportExcelChanged() {
                    if (!adminPage || !adminPage.triggerExportExcel) return;

                    // 1. Check if there is data
                    if (revenueModel.count === 0) {
                        if (notify) notify("Không có dữ liệu để xuất.");
                        adminPage.triggerExportExcel = false;
                        return;
                    }

                    // --- CHANGED: REMOVED DIALOG OPENING ---
                    // Instead of opening adminPage.fileSaveDialog.open(), we call export directly.
                    // We pass an empty string "" so C++ knows to use the default Desktop path.
                    revenueLogic.exportDataForExcel("");

                    // --- CHANGED: Reset trigger manually ---
                    // Since we aren't waiting for a dialog to close, we must reset this now.
                    adminPage.triggerExportExcel = false;
                }
    }

    Connections {
            target: (adminPage && adminPage.fileSaveDialog) ? adminPage.fileSaveDialog : null
            function onAccepted() {
                try {
                    var dlg = adminPage.fileSaveDialog;
                    var p = (dlg && dlg.selectedFile) ? dlg.selectedFile : ((dlg && dlg.selectedFiles && dlg.selectedFiles.length>0) ? dlg.selectedFiles[0] : (dlg ? dlg.file : ""));

                    // --- CHANGE 3: Call the Excel export function ---
                    revenueLogic.exportDataForExcel(p);
                } catch(e) {
                    if (notify) notify("Lỗi khi chọn file.");
                }
            }
        }

        // --- CHANGE 4: Add Logic to prepare data and call C++ ---
    function exportDataForExcel(filePath) {
            // --- CHANGED: ALLOW EMPTY PATH ---
            // OLD: if (!filePath) return;
            // NEW: We allow empty filePath because C++ handles it.

            let cleanPath = "";
            if (filePath) {
                cleanPath = filePath.toString();
                if (cleanPath.startsWith("file:///")) {
                    cleanPath = cleanPath.slice(8);
                }
            }

            let dataForExcel = [];
            let calcTotalRevenue = 0;
            let calcTotalSession = 0;
            let calcTotalSubscription = 0;

            // Prepare data list from the Model
            for (let i = 0; i < revenueModel.count; i++) {
                const item = revenueModel.get(i);
                let cleanRow = {
                    "d": item.d + "",
                    "session_count": parseInt(item.session_count || 0),
                    "subscription_count": parseInt(item.subscription_count || 0),
                    "total_amount": parseInt(item.total_amount || 0)
                };
                dataForExcel.push(cleanRow);

                calcTotalRevenue += cleanRow.total_amount;
                calcTotalSession += cleanRow.session_count;
                calcTotalSubscription += cleanRow.subscription_count;
            }

            // Call C++ Backend
            if (typeof repo !== 'undefined' && repo.exportRevenueToExcel) {
                const fromDate = (adminPage.revFrom && adminPage.revFrom.text) ? adminPage.revFrom.text : defaultFrom();
                const toDate = (adminPage.revTo && adminPage.revTo.text) ? adminPage.revTo.text : todayIso();

                // Pass cleanPath (which might be empty string)
                repo.exportRevenueToExcel(cleanPath, dataForExcel, fromDate, toDate, calcTotalRevenue, calcTotalSession, calcTotalSubscription);

                // Update notification to let user know where it went
                if (notify) notify("Đã xuất file Excel ra màn hình Desktop.");
            } else {
                if (notify) notify("Lỗi: Backend chưa hỗ trợ exportRevenueToExcel.");
            }
        }

    function generateCsvData() {
        if (revenueModel.count === 0) {
            if (notify) notify("Không có dữ liệu để xuất.");
            generatedCsvData = "";
            return;
        }

        let csv = "Ngày,Tổng lượt xe,Tổng vé tháng,Doanh thu (VNĐ)\n"; 

        for (let i = 0; i < revenueModel.count; i++) {
            const item = revenueModel.get(i);
            csv += item.d + ",";
            csv += item.session_count + ",";
            csv += item.subscription_count + ",";
            csv += item.total_amount + "\n";
        }

        csv += "\n";
        csv += "Tổng cộng," + totalSession + "," + totalSubscription + "," + totalRevenue + "\n";

        generatedCsvData = csv; 
    }

    function saveCsvToFile(filePath) {
        if (!filePath) return;
        if (typeof repo !== 'undefined' && repo.saveTextToFile) {
            const ok = repo.saveTextToFile(filePath, generatedCsvData);
            if (notify) notify(ok ? "Đã lưu file CSV thành công." : "Lỗi khi lưu file.");
        } else {
            if (notify) notify("Lỗi: Chức năng lưu file không tồn tại.");
        }
    }

    function exportDataForPdf() {
        if (revenueModel.count === 0) {
            if (notify) notify("Không có dữ liệu để xuất.");
            return;
        }

        let dataForPdf = [];
        let calcTotalRevenue = 0;
        let calcTotalSession = 0;
        let calcTotalSubscription = 0;
        for (let i = 0; i < revenueModel.count; i++) {
                    const item = revenueModel.get(i);

                    // --- FIX START: Create a clean JS object explicitly ---
                    // We force the values into the correct types to ensure C++ reads them correctly.
                    let cleanRow = {
                        "d": item.d + "", // Force string
                        "session_count": parseInt(item.session_count || 0),
                        "subscription_count": parseInt(item.subscription_count || 0),
                        "total_amount": parseInt(item.total_amount || 0)
                    };

                    dataForPdf.push(cleanRow);
                    // --- FIX END ---

                    // Calculate totals safely
                    calcTotalRevenue += cleanRow.total_amount;
                    calcTotalSession += cleanRow.session_count;
                    calcTotalSubscription += cleanRow.subscription_count;
                }
        if (typeof repo !== 'undefined' && repo.exportRevenueToPdf) {
            const fromDate = adminPage.revFrom.text || defaultFrom();
            const toDate = adminPage.revTo.text || todayIso();
            repo.exportRevenueToPdf(dataForPdf, fromDate, toDate, calcTotalRevenue, calcTotalSession, calcTotalSubscription);
            if (notify) notify("Đang xử lý file PDF...");
        } else {
            if (notify) notify("Lỗi: Chức năng xuất PDF không tồn tại.");
            console.log("repo.exportRevenueToPdf is not defined. You need to implement this in C++.");
        }
    }

    // Handle async result
    Connections {
        target: repo
        function onRevenueSummaryReady(fromIso, toIso, typeFilter, rows){
            const key = (fromIso||'')+"|"+(toIso||'')+"|"+(typeFilter||'');
            if (key !== _revReqKey) return;
            if (!rows) rows = []
            revenueModel.clear();
            totalRevenue=0; totalSession=0; totalSubscription=0;
            for(let i=0;i<rows.length;i++){ const r=rows[i]; totalRevenue += parseInt(r.total_amount||0); totalSession += parseInt(r.session_count||0); totalSubscription += parseInt(r.subscription_count||0); revenueModel.append(r) }
            if(adminPage){ if(adminPage.revSummaryTotal) adminPage.revSummaryTotal.text='Tổng doanh thu: '+totalRevenue; if(adminPage.revSummaryBreakdown) adminPage.revSummaryBreakdown.text='Trong đó: vé lượt '+totalSession+', vé tháng '+totalSubscription }
        }
        function onPdfExported(path, ok){ if (notify) notify(ok? ("Đã xuất PDF: "+path) : "Xuất PDF thất bại (thiếu Qt PDF?)"); }
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

    Connections {
            target: adminPage

            // +++ ADD THIS NEW FUNCTION +++
            function onTriggerOpenImageChanged() {
                if (!adminPage || !adminPage.triggerOpenImage) return;

                // Now you can safely call open() from the logic file
                if (adminPage.imageOpenDialog) {
                    adminPage.imageOpenDialog.open();
                }

                // Reset the trigger so it can be clicked again
                adminPage.triggerOpenImage = false;
            }
        }

    // Refresh upon async seeding done
    Connections {
        target: repo
        function onSeedDemoDone(ok){ if (notify) notify(ok?"Đã tạo dữ liệu demo":"Tạo dữ liệu demo lỗi");
            revenueLogic.refresh(); }
    }
}
