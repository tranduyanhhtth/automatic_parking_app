import QtQuick

Item {
    id: employeeLogic
    property Item adminPage
    property var notify
    property alias listModel: employeeModel
    // These trigger properties are toggled by the UI buttons.
    property bool triggerAdd: false
    property bool triggerUpdate: false
    property bool triggerDelete: false

    // Internal state to keep track of the currently selected employee.
    property int selectedEmployeeId: -1
    property bool canCheckIn: false
    property bool canCheckOut: false

    ListModel { id: employeeModel }

    function attachAdminPage(){
        if(!adminPage) return;
        adminPage.employeeListModel = listModel;
        adminPage.canEmployeeCheckIn = canCheckIn;
        adminPage.canEmployeeCheckOut = canCheckOut;
    }

    onAdminPageChanged: attachAdminPage()

    Connections {
        target: adminPage
        function onTriggerAddEmployeeChanged() { 
            if (adminPage.triggerAddEmployee) {
                console.log('[EmployeeLogic] onTriggerAddEmployeeChanged triggered');
                addEmployee();
                adminPage.triggerAddEmployee = false;
            }
        }
        function onTriggerUpdateEmployeeChanged() { 
            if (adminPage.triggerUpdateEmployee) {
                updateEmployee();
                adminPage.triggerUpdateEmployee = false;
            }
        }
        function onTriggerDeleteEmployeeChanged() { 
            if (adminPage.triggerDeleteEmployee) {
                deleteEmployee();
                adminPage.triggerDeleteEmployee = false;
            }
        }
    }
    function selectEmployee(modelData) {
        if (!adminPage || !modelData) return;
        selectedEmployeeId = modelData.id;
        adminPage.tfEmployeeName.text = modelData.full_name;
        adminPage.tfEmployeeStaffId.text = modelData.staff_id;
        adminPage.taEmployeeNote.text = modelData.note;

        // Logic to determine if check-in or check-out is possible
        const hasCheckedIn = modelData.shift_start_at !== null && modelData.shift_start_at !== "";
        const hasCheckedOut = modelData.shift_end_at !== null && modelData.shift_end_at !== "";

        canCheckIn = !hasCheckedIn || hasCheckedOut; // Can check in if never checked in, or after checking out.
        canCheckOut = hasCheckedIn && !hasCheckedOut; // Can only check out if checked in but not yet checked out.
        
        // Update AdminPage properties
        if (adminPage) {
            adminPage.canEmployeeCheckIn = canCheckIn;
            adminPage.canEmployeeCheckOut = canCheckOut;
        }

        const roleIndex = adminPage.cbEmployeeRole.model.indexOf(modelData.role);
        if (roleIndex !== -1) {
            adminPage.cbEmployeeRole.currentIndex = roleIndex;
        }
    }

    function refresh() {
        console.log('[EmployeeLogic] refresh() called');
        const currentId = selectedEmployeeId;
        employeeModel.clear();
        
        if (typeof repo === 'undefined' || !repo) {
            console.error('[EmployeeLogic] repo not available for refresh');
            return;
        }
        
        if (!repo.listEmployees) {
            console.error('[EmployeeLogic] repo.listEmployees not available');
            return;
        }
        
        try {
            const employees = repo.listEmployees();
            console.log('[EmployeeLogic] Retrieved employees:', employees.length);
            let newSelectionData = null;
            for (let i = 0; i < employees.length; i++) {
                const emp = employees[i];
                employeeModel.append(emp);
                if (emp.id === currentId) {
                    newSelectionData = emp;
                }
            }
            if (newSelectionData) {
                // re-select the employee to refresh button states
                selectEmployee(newSelectionData);
            }
        } catch (e) {
            console.error('[EmployeeLogic] Error in refresh:', e);
        }
    }

    function addEmployee() {
        console.log('[EmployeeLogic] addEmployee called');
        const name = adminPage.tfEmployeeName.text.trim();
        const staffId = adminPage.tfEmployeeStaffId.text.trim();
        const role = adminPage.cbEmployeeRole.currentText;
        const note = adminPage.taEmployeeNote.text.trim();

        console.log('[EmployeeLogic] Form data:', {name, staffId, role, note});

        if (name.length === 0 || staffId.length === 0) {
            if(notify) notify("Vui lòng nhập Tên và Mã NV");
            return;
        }

        if (typeof repo === 'undefined' || !repo || !repo.addEmployee) {
            console.error('[EmployeeLogic] repo or addEmployee not available');
            if(notify) notify("Lỗi: Không thể truy cập cơ sở dữ liệu");
            return;
        }

        console.log('[EmployeeLogic] Calling repo.addEmployee with params:', name, staffId, role, note);
        const addResult = repo.addEmployee(name, staffId, role, note);
        console.log('[EmployeeLogic] addEmployee result:', addResult);
        
        if (addResult === 1) {
            if(notify) notify("Thêm nhân viên thành công");
            clearForm();
            Qt.callLater(function() {
                refresh();
            });
        } else if (addResult === -2) {
            if(notify) notify("Mã nhân viên đã tồn tại. Vui lòng nhập mã khác.");
        } else {
            if(notify) notify("Lỗi khi thêm nhân viên (mã lỗi: " + addResult + ")");
        }
    }

    function updateEmployee() {
        if (selectedEmployeeId <= 0) {
            if(notify) notify("Vui lòng chọn một nhân viên để cập nhật");
            return;
        }
        const name = adminPage.tfEmployeeName.text.trim();
        const staffId = adminPage.tfEmployeeStaffId.text.trim();
        const role = adminPage.cbEmployeeRole.currentText;
        const note = adminPage.taEmployeeNote.text.trim();

        if (repo.updateEmployee(selectedEmployeeId, name, staffId, role, note)) {
            if(notify) notify("Cập nhật thành công");
            refresh();
        } else {
            if(notify) notify("Lỗi khi cập nhật");
        }
    }

    function deleteEmployee() {
        if (selectedEmployeeId <= 0) {
            if(notify) notify("Vui lòng chọn một nhân viên để xóa", "warn");
            return;
        }
        if (repo.deleteEmployee(selectedEmployeeId)) {
            if(notify) notify("Xóa thành công", "success");
            clearForm();
            refresh();
        } else {
            if(notify) notify("Lỗi khi xóa", "error");
        }
    }

    function handleCheckIn() {
        if (selectedEmployeeId <= 0) {
            if(notify) notify("Vui lòng chọn một nhân viên", "warn");
            return;
        }
        if (repo.checkInEmployee(selectedEmployeeId)) {
            notify("Đã chấm công cho: " + adminPage.tfEmployeeName.text, "success");
            refresh();
        } else {
            notify("Lỗi khi chấm công", "error");
        }
    }

    function handleCheckOut() {
        if (selectedEmployeeId <= 0) {
            if(notify) notify("Vui lòng chọn một nhân viên", "warn");
            return;
        }
        if (repo.checkOutEmployee(selectedEmployeeId)) {
            notify("Đã kết thúc ca cho: " + adminPage.tfEmployeeName.text, "success");
            refresh();
        } else {
            notify("Lỗi khi kết thúc ca (có thể nhân viên chưa chấm công)", "error");
        }
    }

    function clearForm() {
        adminPage.tfEmployeeName.text = "";
        adminPage.tfEmployeeStaffId.text = "";
        adminPage.taEmployeeNote.text = "";
        adminPage.cbEmployeeRole.currentIndex = 0;
        selectedEmployeeId = -1;
        canCheckIn = false;
        canCheckOut = false;
        
        // Update AdminPage properties
        if (adminPage) {
            adminPage.canEmployeeCheckIn = false;
            adminPage.canEmployeeCheckOut = false;
        }
    }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged() {
            if (adminPage.tabBar.currentIndex === 5) {
                refresh();
            }
        }
    }

    Connections {
        target: adminPage
        function onTriggerEmployeeCheckInChanged() {
            if (adminPage.triggerEmployeeCheckIn) {
                handleCheckIn()
            }
        }
        function onTriggerEmployeeCheckOutChanged() {
            if (adminPage.triggerEmployeeCheckOut) {
                handleCheckOut()
            }
        }
    }

    Connections {
           target: adminPage
           function onPendingSelectEmployeeIndexChanged() {
               // Check for a valid index
               if (adminPage.pendingSelectEmployeeIndex >= 0 && adminPage.pendingSelectEmployeeIndex < employeeModel.count) {
                   // Get the data for the selected row from the model
                   const modelData = employeeModel.get(adminPage.pendingSelectEmployeeIndex);
                   // Call the existing function to select the employee and update the form
                   selectEmployee(modelData);
               }
           }
       }

    Component.onCompleted: {
        console.log('[EmployeeLogic] Component completed');
        console.log('[EmployeeLogic] repo available:', typeof repo !== 'undefined');
        console.log('[EmployeeLogic] repo methods:', repo ? Object.keys(repo) : 'N/A');
        attachAdminPage();
        refresh();
    }
}