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
        property string currentUser: "" // 记录当前登录用户名
        states: [ State { name: "login" }, State { name: "main" } ]
    }

    Item {
        id: currentView
        state: "cloud"
        states: [ State { name: "cloud" }, State { name: "transfer" } ]
    }

    // --- 目录状态管理 ---
    property int currentParentId: 0
    property var sidToIndex: ({}) // 移动到这里：根层级
    property var pathStack: [{"id": 0, "name": "根目录"}]

    // --- 持久化计时器 ---
    function saveTasks() {
        var tasks = []
        for (var i = 0; i < transferModel.count; i++) {
            var item = transferModel.get(i)
            // 核心优化：下载任务通过物理扫描恢复，json 只存储无法物理找回的上传任务
            if (item.type !== "UP") continue;
            
            tasks.push({
                "sid": item.sid,
                "fileId": item.fileId,
                "filename": item.filename,
                "localPath": item.localPath || "",
                "parentId": item.parentId || 0,
                "type": item.type,
                "totalSize": item.totalSize,
                "transferred": item.transferred,
                "status": item.status,
                "progress": item.progress,
                "eta": item.eta,
                "username": item.username || ""
            })
        }
        console.log("[QML] Explicitly saving " + tasks.length + " tasks...")
        client.saveTasks(tasks)
    }

    Component.onDestruction: {
        saveTasks()
    }

    Component.onCompleted: {
        // 启动时不再自动扫描，改为登录成功后再根据用户名扫描
        // (保持 Component.onCompleted 为空或仅处理通用初始化)
    }

    // --- 辅助功能 ---
    FileDialog {
        id: fileDialog
        title: "选择上传文件"
        onAccepted: { 
            var path = selectedFile.toString();
            // 查重逻辑：检查是否已经在上传同一文件
            var exists = false;
            var cleanPath = path.replace("file://", "");
            for (var i = 0; i < transferModel.count; i++) {
                if (transferModel.get(i).localPath === cleanPath && transferModel.get(i).status !== "已完成") {
                    exists = true; break;
                }
            }
            if (!exists) {
                client.upload(currentParentId, path); 
                currentView.state = "transfer"
            } else {
                loginPopupText.text = "该文件已经在上传列表中！"
                loginPopup.open()
            }
        }
    }

    function selectedCount() {
        var count = 0;
        for (var i = 0; i < fileListModel.count; i++) {
            if (fileListModel.get(i).checked) count++;
        }
        return count;
    }

    function clearCompleted() {
        var removed = false;
        for (var i = transferModel.count - 1; i >= 0; i--) {
            var status = transferModel.get(i).status;
            if (status === "已完成" || status === "已取消") {
                transferModel.remove(i);
                removed = true;
            }
        }
        if (removed) saveTasks();
    }

    function cancelAll() {
        for (var i = 0; i < transferModel.count; i++) {
            var item = transferModel.get(i);
            if (item.status === "传输中" || item.status === "已暂停") {
                client.cancelTransfer(item.sid);
                transferModel.setProperty(i, "status", "已取消");
            }
        }
    }

    function pauseAll() {
        for (var i = 0; i < transferModel.count; i++) {
            var item = transferModel.get(i);
            if (item.status === "传输中") {
                client.pauseTransfer(item.sid);
                transferModel.setProperty(i, "status", "已暂停");
            }
        }
    }

    function resumeAll() {
        for (var i = 0; i < transferModel.count; i++) {
            var item = transferModel.get(i);
            if (item.status === "已暂停") {
                client.resumeTransfer(item.sid);
                transferModel.setProperty(i, "status", "传输中");
            }
        }
    }

    // --- 后端信号连接 ---
    Connections {
        target: client
        
        function onLoginResult(success, message) {
            loginPopupText.text = message
            loginPopup.open()
            if (success) { 
                appState.state = "main"
                // 1. 下载任务扫描
                var incompleteDownloads = client.scanIncompleteDownloads("usr/" + client.getCurrentUserId())
                for (var i = 0; i < incompleteDownloads.length; i++) {
                    var t = incompleteDownloads[i]
                    if (t.username === appState.currentUser) {
                        t.speed = 0; t.eta = 0; t.progress = t.totalSize > 0 ? t.transferred / t.totalSize : 0;
                        t.startTime = Date.now(); t.initialTransferred = t.transferred || 0;
                        t.baselineReady = false; t.lastUpdate = 0;
                        transferModel.append(t)
                    }
                }
                // 2. 上传任务加载
                var savedTasks = client.loadTasks()
                for (var j = 0; j < savedTasks.length; j++) {
                    var st = savedTasks[j]
                    if (st.type === "UP" && st.username === appState.currentUser) {
                        var exists = false
                        for (var k = 0; k < transferModel.count; k++) {
                            if (transferModel.get(k).localPath === st.localPath) { exists = true; break; }
                        }
                        if (!exists) {
                            st.status = "中断"; st.speed = 0; st.eta = 0; st.startTime = Date.now();
                            transferModel.append(st)
                        }
                    }
                }
                client.listFiles(currentParentId) 
            }
        }

        function onRegisterResult(success, message) {
            loginPopupText.text = message
            loginPopup.open()
            // 如果注册成功，可以切换回登录模式或自动登录
            // 这里我们保持在注册界面，让用户看到成功提示后手动返回登录
        }

        function onFileListReceived(files) {
            fileListModel.clear()
            for (var i = 0; i < files.length; i++) {
                var f = files[i]; f.checked = false; fileListModel.append(f)
            }
        }

        function onTransferStarted(sid, fileId, filename, totalSize, type, localPath) {
            var pId = (type === "UP") ? currentParentId : 0
            var cleanPath = (localPath || "").replace("file://", "")
            var existingIdx = -1
            for (var i = 0; i < transferModel.count; i++) {
                var item = transferModel.get(i)
                if (type === "DL" && item.fileId === fileId) { existingIdx = i; break; }
                if (type === "UP" && item.localPath === cleanPath) { existingIdx = i; break; }
            }
            if (existingIdx !== -1) {
                var oldItem = transferModel.get(existingIdx)
                transferModel.setProperty(existingIdx, "sid", sid)
                transferModel.setProperty(existingIdx, "status", "传输中")
                transferModel.setProperty(existingIdx, "startTime", Date.now())
                transferModel.setProperty(existingIdx, "initialTransferred", oldItem.transferred || 0)
                transferModel.setProperty(existingIdx, "speed", 0)
                transferModel.setProperty(existingIdx, "eta", 0)
                sidToIndex[sid] = existingIdx
            } else {
                transferModel.append({ 
                    "sid": sid, "fileId": fileId, "filename": filename, "type": type, "totalSize": totalSize,
                    "localPath": cleanPath, "parentId": pId, "username": appState.currentUser,
                    "transferred": 0, "speed": 0, "progress": 0, "eta": 0, "status": "传输中", 
                    "startTime": Date.now(), "initialTransferred": 0 
                })
            }
            saveTasks()
        }

        function onProgressUpdate(sid, cur, total) {
            var idx = sidToIndex[sid]
            if (idx === undefined) {
                for (var i = 0; i < transferModel.count; ++i) {
                    if (transferModel.get(i).sid === sid) {
                        sidToIndex[sid] = i; idx = i; break;
                    }
                }
            }
            if (idx !== undefined && idx < transferModel.count) {
                var now = Date.now()
                var isFinished = (total > 0 && cur >= total)
                var latestItem = transferModel.get(idx)
                if (!isFinished && latestItem.status === "传输中" && latestItem.lastUpdate && (now - latestItem.lastUpdate < 150)) return 
                
                transferModel.setProperty(idx, "lastUpdate", now)
                transferModel.setProperty(idx, "transferred", cur)
                transferModel.setProperty(idx, "progress", total > 0 ? cur / total : 0)

                var initialT = latestItem.initialTransferred
                var startT = latestItem.startTime
                if (initialT === undefined || initialT === 0 || startT === 0) {
                    transferModel.setProperty(idx, "initialTransferred", cur)
                    transferModel.setProperty(idx, "startTime", now)
                    return 
                }
                var deltaBytes = cur - initialT
                var deltaTime = (now - startT) / 1000
                if (deltaTime > 1.5 && deltaBytes > 0) {
                    var speed = deltaBytes / deltaTime
                    transferModel.setProperty(idx, "speed", isFinished ? 0 : speed)
                    transferModel.setProperty(idx, "eta", (isFinished || speed <= 0) ? 0 : (total - cur) / speed)
                }
                if (isFinished) {
                    transferModel.setProperty(idx, "status", "已完成")
                    transferModel.setProperty(idx, "speed", 0); transferModel.setProperty(idx, "eta", 0)
                    delete sidToIndex[sid]; saveTasks()
                }
            }
        }
        function onRemoveResult(success, message) { if (success) client.listFiles(currentParentId); }
        function onUploadFinished() { client.listFiles(currentParentId); }
    }

    // --- 界面布局 ---
    background: Rectangle { color: "#1a1a1a" }

    StackLayout {
        id: mainStack
        anchors.fill: parent
        currentIndex: appState.state === "login" ? 0 : 1

        LoginPage {
            onLoginRequested: (ip, user, pass) => {
                appState.currentUser = user // 预存用户名
                client.connectToServer(ip, 8080); client.login(user, pass)
            }
            onRegisterRequested: (ip, user, pass) => {
                client.connectToServer(ip, 8080); client.registerUser(user, pass)
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
                        pathStack: window.pathStack
                        onUploadClicked: fileDialog.open()
                        onRefreshClicked: client.listFiles(currentParentId)
                        onMakeDirClicked: makeDirDialog.open()
                        onMoveClicked: {
                            // Populate move list, just simple "Root" for now as example or parent
                            // A proper tree view takes more time, let's keep it simple: Move to Root or Parent
                            moveDialog.open()
                        }
                        onDownloadSelected: {
                            for (var i = 0; i < fileListModel.count; i++) {
                                var item = fileListModel.get(i);
                                if (item.checked) {
                                    // 查重逻辑：检查是否已在下载列表中
                                    var exists = false;
                                    for (var j = 0; j < transferModel.count; j++) {
                                        if (transferModel.get(j).fileId === item.id && transferModel.get(j).status !== "已完成") {
                                            exists = true; break;
                                        }
                                    }
                                    if (!exists) {
                                        client.download(item.id, item.filename)
                                    } else {
                                        console.log("[UI] Download task already exists for: " + item.filename)
                                    }
                                }
                            }
                            currentView.state = "transfer"
                        }
                        onRemoveSelected: {
                            confirmDeleteDialog.open()
                        }
                        onPreviewSelected: {
                            for (var i = 0; i < fileListModel.count; i++) {
                                var item = fileListModel.get(i);
                                if (item.checked) {
                                    var comp = Qt.createComponent("PreviewWindow.qml");
                                    if (comp.status === Component.Ready) {
                                        var win = comp.createObject(window, {
                                            "filename": item.filename,
                                            "fileType": Utils.getFileType(item.filename),
                                            "sourceUrl": client.getPreviewUrl(item.id)
                                        });
                                        win.show();
                                    }
                                    break;
                                }
                            }
                        }
                        onEnterDirectory: (id, name) => {
                            var newStack = window.pathStack.slice();
                            newStack.push({"id": id, "name": name});
                            window.pathStack = newStack;
                            window.currentParentId = id;
                            client.listFiles(id);
                        }
                        onNavigateBreadcrumb: (index) => {
                            var newStack = window.pathStack.slice(0, index + 1);
                            window.pathStack = newStack;
                            window.currentParentId = newStack[newStack.length - 1].id;
                            client.listFiles(window.currentParentId);
                        }
                    }

                    TransferPage {
                        model: transferModel
                        onClearCompletedClicked: window.clearCompleted()
                        onCancelAllClicked: window.cancelAll()
                        onPauseAllClicked: window.pauseAll()
                        onResumeAllClicked: window.resumeAll()
                        onItemActionClicked: (sid, action) => {
                            for (var i = 0; i < transferModel.count; i++) {
                                if (transferModel.get(i).sid === sid) {
                                    if (action === "pause") {
                                        client.pauseTransfer(sid);
                                        transferModel.setProperty(i, "status", "已暂停");
                                        saveTasks()
                                    } else if (action === "resume") {
                                        if (transferModel.get(i).status === "中断") {
                                            // 重新启动任务前，记录当前的已完成量作为初始值，并重置开始时间
                                            var item = transferModel.get(i)
                                            transferModel.setProperty(i, "initialTransferred", item.transferred)
                                            transferModel.setProperty(i, "startTime", Date.now())
                                            
                                            if (item.type === "DL") {
                                                client.download(item.fileId, item.filename)
                                                transferModel.remove(i)
                                            } else if (item.type === "UP") {
                                                client.upload(item.parentId, item.localPath)
                                                transferModel.remove(i)
                                            }
                                        } else {
                                            client.resumeTransfer(sid);
                                            transferModel.setProperty(i, "status", "传输中");
                                        }
                                        saveTasks()
                                    } else if (action === "cancel") {
                                        client.cancelTransfer(sid);
                                        transferModel.setProperty(i, "status", "已取消");
                                        saveTasks()
                                    }
                                    break;
                                }
                            }
                        }
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

    Dialog {
        id: makeDirDialog; anchors.centerIn: parent; width: 300; modal: true
        title: "新建文件夹"
        background: Rectangle { color: "#222"; radius: 8; border.color: "#444" }
        contentItem: ColumnLayout {
            TextField {
                id: dirNameInput; Layout.fillWidth: true; placeholderText: "文件夹名称"
                color: "white"; background: Rectangle { color: "#333"; radius: 4 }
            }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (dirNameInput.text.trim() !== "") {
                client.makeDir(window.currentParentId, dirNameInput.text.trim());
                dirNameInput.text = "";
            }
        }
    }

    Dialog {
        id: confirmDeleteDialog; anchors.centerIn: parent; width: 350; modal: true
        title: "确认删除"
        background: Rectangle { color: "#222"; radius: 8; border.color: "#444" }
        contentItem: Text {
            text: "确定要删除选中的项目吗？如果是文件夹，其内容也将被全部删除！"
            color: "white"; wrapMode: Text.WordWrap; width: 300
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            for (var i = 0; i < fileListModel.count; i++) {
                if (fileListModel.get(i).checked) client.remove(fileListModel.get(i).id)
            }
        }
    }

    Dialog {
        id: moveDialog; anchors.centerIn: parent; width: 350; modal: true
        title: "选择目标文件夹"
        background: Rectangle { color: "#222"; radius: 8; border.color: "#444" }
        
        property var dirList: []
        
        onOpened: {
            dirList = client.getAllDirectories()
            var paths = []
            for (var i = 0; i < dirList.length; i++) {
                paths.push(dirList[i].path)
            }
            moveCombo.model = paths
            moveCombo.currentIndex = 0
        }

        contentItem: ColumnLayout {
            Text { text: "移动到:"; color: "white" }
            ComboBox {
                id: moveCombo
                Layout.fillWidth: true
            }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (dirList.length > 0 && moveCombo.currentIndex >= 0) {
                var targetId = dirList[moveCombo.currentIndex].id
                for (var i = 0; i < fileListModel.count; i++) {
                    if (fileListModel.get(i).checked) client.moveFile(fileListModel.get(i).id, targetId)
                }
            }
        }
    }
}
