import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Utils.js" as Utils

ColumnLayout {
    id: root
    spacing: 0
    
    property var model
    property int selectedCount: 0
    property var pathStack: [{"id": 0, "name": "根目录"}]
    
    signal uploadClicked()
    signal refreshClicked()
    signal downloadSelected()
    signal removeSelected()
    signal previewSelected()
    signal makeDirClicked()
    signal moveClicked()
    signal enterDirectory(int id, string name)
    signal navigateBreadcrumb(int index)

    // 工具栏
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 50; color: "transparent"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; spacing: 15
            Button {
                text: "⬆️ 上传"; background: Rectangle { radius: 4; color: "white" }
                contentItem: Text { text: parent.text; color: "black"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.uploadClicked()
            }
            Button {
                text: "➕ 新建文件夹"; background: Rectangle { radius: 4; color: "#333" }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.makeDirClicked()
            }
            Rectangle { width: 1; height: 20; color: "#444"; visible: root.selectedCount > 0 }
            Button {
                text: "📥 下载 (" + root.selectedCount + ")"; visible: root.selectedCount > 0
                background: Rectangle { radius: 4; color: "#3498db" }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.downloadSelected()
            }
            Button {
                text: "➡️ 移动"; visible: root.selectedCount > 0
                background: Rectangle { radius: 4; color: "#f39c12" }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.moveClicked()
            }
            Button {
                text: "🗑️ 删除"; visible: root.selectedCount > 0
                background: Rectangle { radius: 4; color: "#e74c3c" }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.removeSelected()
            }
            Button {
                text: "👁️ 预览"; visible: root.selectedCount === 1
                background: Rectangle { radius: 4; color: "#9b59b6" }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.previewSelected()
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "↻ 刷新"
                background: Rectangle { radius: 4; color: "#333" }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.refreshClicked()
            }
        }
    }

    // 面包屑导航
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 30; color: "#1e1e1e"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; spacing: 5
            Repeater {
                model: root.pathStack
                delegate: RowLayout {
                    spacing: 5
                    Text { 
                        text: modelData.name; color: "#3498db"; font.pixelSize: 14; font.bold: true
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateBreadcrumb(index) }
                    }
                    Text { text: ">"; color: "#888"; visible: index < root.pathStack.length - 1 }
                }
            }
        }
    }

    // 网格内容
    Rectangle {
        Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
        ColumnLayout {
            anchors.centerIn: parent; spacing: 20; opacity: 0.5; visible: root.model.count === 0
            Image { sourceSize: Qt.size(200, 200); source: "https://via.placeholder.com/200"; Layout.alignment: Qt.AlignHCenter; visible: false }
            Text { text: "您的云盘还什么都没有"; color: "white"; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
            Button { text: "刷新"; Layout.alignment: Qt.AlignHCenter; onClicked: root.refreshClicked() }
        }

        GridView {
            id: fileGrid; anchors.fill: parent; anchors.margins: 20; cellWidth: 180; cellHeight: 220; model: root.model; clip: true; visible: root.model.count > 0
            delegate: Item {
                width: 180; height: 220
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 160; Layout.preferredHeight: 160; color: "#252525"; radius: 8
                        border.color: gridMouse.containsMouse ? "#444" : "transparent"
                        Rectangle {
                            anchors.centerIn: parent; width: 60; height: 75; radius: 4; color: is_dir ? "#f1c40f" : "#3498db"
                            Text { anchors.centerIn: parent; text: is_dir ? "📁" : Utils.getFileIcon(filename); color: "white"; font.pixelSize: 30 }
                        }
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8; width: 20; height: 20; radius: 4
                            color: checked ? "#3498db" : "transparent"; border.color: "white"; border.width: 1
                            visible: gridMouse.containsMouse || checked
                            Text { anchors.centerIn: parent; text: "✓"; color: "white"; visible: checked }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: filename; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
                MouseArea { 
                    id: gridMouse; anchors.fill: parent; hoverEnabled: true; 
                    onClicked: root.model.setProperty(index, "checked", !checked) 
                    onDoubleClicked: {
                        if (is_dir) {
                            root.enterDirectory(id, filename)
                        }
                    }
                }
            }
        }
    }
}
