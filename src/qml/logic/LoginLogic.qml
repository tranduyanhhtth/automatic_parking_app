import QtQuick

Item {
    id: loginLogic
    property Item adminPage
    property var notify
    property var allowedAccounts

    Connections {
        target: adminPage
        function onTriggerLoginChanged() {
            const u = adminPage.loginUserField.text || ""
            const p = adminPage.loginPassField.text || ""
            const ok = allowedAccounts && allowedAccounts.some(a => a.username === u && a.password === p)
            if (ok) {
                adminPage.loginVisible = false
                if (notify) notify('Đăng nhập thành công')
            } else {
                adminPage.loginErrorLabel.text = 'Sai tài khoản hoặc mật khẩu'
            }
        }
        function onTriggerLogoutAndCloseChanged() {
            if (!adminPage.triggerLogoutAndClose) return;
            adminPage.loginVisible = false;
            if (adminPage.loginUserField) adminPage.loginUserField.text = '';
            if (adminPage.loginPassField) adminPage.loginPassField.text = '';
            if (adminPage.loginErrorLabel) adminPage.loginErrorLabel.text = '';
            adminPage.triggerLogoutAndClose = false;
            adminPage.triggerClose = true;
        }
    }
}
