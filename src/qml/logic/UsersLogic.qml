import QtQuick

Item {
    id: usersLogic
    property Item adminPage
    property var notify

    Connections {
        target: adminPage
        function onTriggerAddUserChanged() {
            if (!adminPage.triggerAddUser) return;
            var name = adminPage.userName.text;
            var phone = adminPage.userPhone.text;
            var rfid = adminPage.userRfid.text;
            var plate = adminPage.userPlate.text;
            var vehicleType = adminPage.userVehicleType.currentText;
            var note = adminPage.userNote.text;
            var ok = repo && repo.addUser ? repo.addUser(name, phone, rfid, plate, vehicleType, note) : false;
            if (notify) notify(ok ? 'Đã thêm user' : 'Lỗi thêm user');
            adminPage.triggerAddUser = false;
        }
        function onTriggerUpdateUserChanged() {
            if (!adminPage.triggerUpdateUser) return;
            var id = adminPage.userId ? adminPage.userId.text : '';
            var name = adminPage.userName.text;
            var phone = adminPage.userPhone.text;
            var rfid = adminPage.userRfid.text;
            var plate = adminPage.userPlate.text;
            var vehicleType = adminPage.userVehicleType.currentText;
            var note = adminPage.userNote.text;
            var ok = repo && repo.updateUser ? repo.updateUser(id, name, phone, rfid, plate, vehicleType, note) : false;
            if (notify) notify(ok ? 'Đã cập nhật user' : 'Lỗi cập nhật user');
            adminPage.triggerUpdateUser = false;
        }
        function onTriggerDeleteUserChanged() {
            if (!adminPage.triggerDeleteUser) return;
            var id = adminPage.userId ? adminPage.userId.text : '';
            var ok = repo && repo.deleteUser ? repo.deleteUser(id) : false;
            if (notify) notify(ok ? 'Đã xóa user' : 'Lỗi xóa user');
            adminPage.triggerDeleteUser = false;
        }
    }
}
