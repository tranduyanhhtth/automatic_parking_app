import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: cameraSettingsDialog
    // Expose fields to outside
    property alias tfCam1: tfCam1
    property alias tfCam2: tfCam2
    property alias tfCam3: tfCam3
    property alias tfCam4: tfCam4
    // Expose inner dialog for open()/accepted
    property alias dialog: dlg

    Dialog {
        id: dlg
        title: "Cấu hình Camera"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        parent: (Overlay.overlay ? Overlay.overlay : cameraSettingsDialog)
        anchors.centerIn: parent
        contentItem: ColumnLayout {
        anchors.margins: 12
        spacing: 10
        Label { text: "Camera 1 URL" }
        TextField {
            id: tfCam1
            text: settings.camera1Url
            Layout.preferredWidth: 520
        }
        Label { text: "Camera 2 URL" }
        TextField {
            id: tfCam2
            text: settings.camera2Url
            Layout.preferredWidth: 520
        }
        Label { text: "Camera 3 URL" }
        TextField {
            id: tfCam3
            text: settings.camera3Url
            Layout.preferredWidth: 520
        }
        Label { text: "Camera 4 URL" }
        TextField {
            id: tfCam4
            text: settings.camera4Url
            Layout.preferredWidth: 520
        }
        }
    }
}