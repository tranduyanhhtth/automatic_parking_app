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

    Connections {
        target: employeeLogic
        function onTriggerAddChanged() { addEmployee() }
        function onTriggerUpdateChanged() { updateEmployee() }
        function onTriggerDeleteChanged() { deleteEmployee() }
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

        const roleIndex = adminPage.cbEmployeeRole.model.indexOf(modelData.role);
        if (roleIndex !== -1) {
            adminPage.cbEmployeeRole.currentIndex = roleIndex;
        }
    }

    function refresh() {
        const currentId = selectedEmployeeId;
        employeeModel.clear();
        if (typeof repo !== 'undefined' && repo.listEmployees) {
            const employees = repo.listEmployees();
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
        }
    }

    function addEmployee() {
        const name = adminPage.tfEmployeeName.text.trim();
        const staffId = adminPage.tfEmployeeStaffId.text.trim();
        const role = adminPage.cbEmployeeRole.currentText;
        const note = adminPage.taEmployeeNote.text.trim();

        if (name.length === 0 || staffId.length === 0) {
            if(notify) notify("Vui lòng nhập Tên và Mã NV", "warn");
            return;
        }

        const addResult = repo.addEmployee(name, staffId, role, note);
        if (addResult === 1) {
            if(notify) notify("Thêm nhân viên thành công", "success");
            clearForm();
            refresh();
        } else if (addResult === -2) {
            if(notify) notify("Mã nhân viên đã tồn tại. Vui lòng nhập mã khác.", "error");
        } else {
            if(notify) notify("Lỗi khi thêm nhân viên (mã lỗi: " + addResult + ")", "error");
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
    }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged() {
            if (adminPage.tabBar.currentIndex === 4) {
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
        refresh();
    }
}