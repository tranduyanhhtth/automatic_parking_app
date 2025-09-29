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
        adminPage.tfEmployeePhone.text = modelData.phone;

        const roleIndex = adminPage.cbEmployeeRole.model.indexOf(modelData.role);
        if (roleIndex !== -1) {
            adminPage.cbEmployeeRole.currentIndex = roleIndex;
        }
    }

    function refresh() {
        employeeModel.clear()
        if (typeof repo !== 'undefined' && repo.listEmployees) {
            const employees = repo.listEmployees()
            employees.forEach(emp => employeeModel.append(emp));
        }
    }

    function addEmployee() {
        const name = adminPage.tfEmployeeName.text.trim();
        const phone = adminPage.tfEmployeePhone.text.trim();
        const role = adminPage.cbEmployeeRole.currentText;
        if(name.length === 0 || phone.length === 0) {
            if(notify) notify("Vui lòng nhập đầy đủ thông tin", "warn");
            return;
        }

        if (repo.addEmployee(name, phone, role)) {
            if(notify) notify("Thêm nhân viên thành công", "success");
            clearForm();
            refresh()
        } else {
            if(notify) notify("Lỗi khi thêm nhân viên", "error");
        }
    }

    function updateEmployee() {
        if (selectedEmployeeId <= 0) {
            if(notify) notify("Vui lòng chọn một nhân viên để cập nhật")
            return
        }
        const name = adminPage.tfEmployeeName.text
        const phone = adminPage.tfEmployeePhone.text
        const role = adminPage.cbEmployeeRole.currentText
        if (repo.updateEmployee(selectedEmployeeId, name, phone, role)) {
            if(notify) notify("Cập nhật thành công")
            refresh()
        } else {
            if(notify) notify("Lỗi khi cập nhật")
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

    function clearForm() {
        adminPage.tfEmployeeName.text = "";
        adminPage.tfEmployeePhone.text = "";
        adminPage.cbEmployeeRole.currentIndex = 0; // Default to the first role.
        selectedEmployeeId = -1; // Deselect the employee.
    }

    Connections {
        target: adminPage ? adminPage.tabBar : null
        function onCurrentIndexChanged() {
            if(adminPage.tabBar.currentIndex === 4) { // The new tab is at index 4
                refresh();
            }
        }
    }

    Component.onCompleted: {
        refresh();
    }
}
