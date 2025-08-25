import QtQuick

Item {
    // Handle login request from AdminPage overlay
    Connections {
        target: adminPage
        function onTriggerLoginChanged() {
            const u = adminPage.loginUserField.text || ""
            const p = adminPage.loginPassField.text || ""
            const ok = root.allowedAccounts && root.allowedAccounts.some(a => a.username === u && a.password === p)
            if (ok) {
                adminPage.loginVisible = false
                root.isAuthenticated = true
                root.showToast("Đăng nhập thành công")
            } else {
                adminPage.loginErrorLabel.text = "Sai tài khoản hoặc mật khẩu"
            }
        }
        function onTriggerLogoutAndCloseChanged() {
            if (!adminPage.triggerLogoutAndClose) return;
            root.isAuthenticated = false;
            adminPage.loginVisible = false;
            if (adminPage.loginUserField) adminPage.loginUserField.text = "";
            if (adminPage.loginPassField) adminPage.loginPassField.text = "";
            if (adminPage.loginErrorLabel) adminPage.loginErrorLabel.text = "";
            adminPage.triggerLogoutAndClose = false; // Reset trigger
            adminPage.triggerClose = true;           // Đóng page
        }
        function onTriggerCloseChanged() {
            if (adminPage.triggerClose) {
                adminPage.triggerClose = false
            }
        }
        function onTriggerAddUserChanged() {
            if (!adminPage.triggerAddUser) return;
            var name = adminPage.userName.text;
            var phone = adminPage.userPhone.text;
            var rfid = adminPage.userRfid.text;
            var plate = adminPage.userPlate.text;
            var vehicleType = adminPage.userVehicleType.currentText;
            var note = adminPage.userNote.text;
            var ok = repo && repo.addUser ? repo.addUser(name, phone, rfid, plate, vehicleType, note) : false;
            if (root && root.showToast) root.showToast(ok ? "Đã thêm user" : "Lỗi thêm user");
            adminPage.triggerAddUser = false;
        }
        function onTriggerUpdateUserChanged() {
            if (!adminPage.triggerUpdateUser) return;
            var id = adminPage.userId ? adminPage.userId.text : "";
            var name = adminPage.userName.text;
            var phone = adminPage.userPhone.text;
            var rfid = adminPage.userRfid.text;
            var plate = adminPage.userPlate.text;
            var vehicleType = adminPage.userVehicleType.currentText;
            var note = adminPage.userNote.text;
            var ok = repo && repo.updateUser ? repo.updateUser(id, name, phone, rfid, plate, vehicleType, note) : false;
            if (root && root.showToast) root.showToast(ok ? "Đã cập nhật user" : "Lỗi cập nhật user");
            adminPage.triggerUpdateUser = false;
        }
        function onTriggerDeleteUserChanged() {
            if (!adminPage.triggerDeleteUser) return;
            var id = adminPage.userId ? adminPage.userId.text : "";
            var ok = repo && repo.deleteUser ? repo.deleteUser(id) : false;
            if (root && root.showToast) root.showToast(ok ? "Đã xóa user" : "Lỗi xóa user");
            adminPage.triggerDeleteUser = false;
        }
    }
}
