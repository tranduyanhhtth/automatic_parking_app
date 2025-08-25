import QtQuick

Item {
    // Expose the model for UI binding
    property alias hidLogModel: hidLogModel
    ListModel { id: hidLogModel }

    function addHidLog(source, msg) {
        var time = Qt.formatTime(new Date(), "HH:mm:ss")
        hidLogModel.append({ t: time, s: source, m: msg })
        if (hidLogModel.count > 200)
            hidLogModel.remove(0, hidLogModel.count - 200)
    }

    Connections {
        target: app
        function onDebugLog(message) { addHidLog("APP", message) }
    }
    Connections {
        target: cardReaderEntrance
        function onDebugLog(msg) { addHidLog("IN", msg) }
    }
    Connections {
        target: cardReaderExit
        function onDebugLog(msg) { addHidLog("OUT", msg) }
    }
    function clear() {
        hidLogModel.clear()
    }
}