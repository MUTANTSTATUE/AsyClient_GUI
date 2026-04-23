import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.3
import "Utils.js" as Utils

ApplicationWindow {
    id: window
    visible: true
    width: 1100
    height: 750
    title: qsTr("AsyCDisk - Cloud Storage")

    // --- 数据模型 ---
    ListModel { id: transferModel }
    ListModel { id: fileListModel }

    // --- 状态管理 ---
    Item {
        id: appState
        state: "login"
        states: [ State { name: "login" }, State { name: "main" } ]
    }

    Item {
        id: currentView
        state: "cloud"
        states: [ State { name: "cloud" }, State { name: "transfer" } ]
    }

    // --- 辅助功能 ---
    FileDialog {
        id: fileDialog
        title: "选择上传文件"
        onAccepted: { client.upload(selectedFile.toString()); currentView.state = "transfer" }
    }

    function selectedCount() {
        var count = 0;
        for (var i = 0; i < fileListModel.count; i++) {
            if (fileListModel.get(i).checked) count++;
        }
        return count;
    }

    function clearCompleted() {
        for (var i = transferModel.count - 1; i >= 0; i--) {
            if (transferModel.get(i).status === "已完成") transferModel.remove(i);
        }
    }

    // --- 后端信号连接 ---
    Connections {
        target: client
        function onLoginResult(success, message) {
            loginPopupText.text = message
            loginPopup.open()
            if (success) { appState.state = "main"; client.listFiles() }
        }
        function onFileListReceived(files) {
            fileListModel.clear()
            for (var i = 0; i < files.length; i++) {
                var f = files[i]; f.checked = false; fileListModel.append(f)
            }
        }
        function onTransferStarted(sid, filename, totalSize, type) {
            transferModel.append({ "sid": sid, "filename": filename, "type": type, "totalSize": totalSize,
                "transferred": 0, "speed": 0, "progress": 0, "eta": 0, "status": "传输中", "startTime": Date.now() })
        }
        function onProgressUpdate(sid, cur, total) {
            for (var i = 0; i < transferModel.count; ++i) {
                var item = transferModel.get(i);
                if (item.sid === sid) {
                    var now = Date.now();
                    var duration = (now - item.startTime) / 1000;
                    var speed = duration > 0 ? cur / duration : 0;
                    var eta = speed > 0 ? (total - cur) / speed : 0;
                    transferModel.setProperty(i, "transferred", cur)
                    transferModel.setProperty(i, "progress", total > 0 ? cur / total : 0)
                    transferModel.setProperty(i, "speed", speed)
                    transferModel.setProperty(i, "eta", eta)
                    if (total > 0 && cur >= total) transferModel.setProperty(i, "status", "已完成")
                    break;
                }
            }
        }
        function onRemoveResult(success, message) { if (success) client.listFiles(); }
        function onUploadFinished() { client.listFiles(); }
    }

    // --- 界面布局 ---
    background: Rectangle { color: "#1a1a1a" }

    StackLayout {
        id: mainStack
        anchors.fill: parent
        currentIndex: appState.state === "login" ? 0 : 1

        LoginPage {
            onLoginRequested: (ip, user, pass) => {
                client.connectToServer(ip, 8080); client.login(user, pass)
            }
        }

        RowLayout {
            spacing: 0
            Sidebar {
                Layout.fillHeight: true; Layout.preferredWidth: 240
                currentState: currentView.state
                onNavClicked: (target) => currentView.state = target
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                TopBar {
                    Layout.fillWidth: true
                    placeholder: "搜索" + (currentView.state === "cloud" ? "云盘" : "传输") + "..."
                }

                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: currentView.state === "cloud" ? 0 : 1

                    CloudPage {
                        model: fileListModel
                        selectedCount: window.selectedCount()
                        onUploadClicked: fileDialog.open()
                        onRefreshClicked: client.listFiles()
                        onDownloadSelected: {
                            for (var i = 0; i < fileListModel.count; i++) {
                                var item = fileListModel.get(i);
                                if (item.checked) client.download(item.id, item.filename)
                            }
                            currentView.state = "transfer"
                        }
                        onRemoveSelected: {
                            for (var i = 0; i < fileListModel.count; i++) {
                                if (fileListModel.get(i).checked) client.remove(fileListModel.get(i).id)
                            }
                        }
                    }

                    TransferPage {
                        model: transferModel
                        onClearCompletedClicked: window.clearCompleted()
                    }
                }
            }
        }
    }

    Popup {
        id: loginPopup; anchors.centerIn: parent; width: 300; height: 100; modal: true
        background: Rectangle { color: "#222"; radius: 8; border.color: "#444" }
        Text { id: loginPopupText; anchors.centerIn: parent; color: "white" }
    }
}
