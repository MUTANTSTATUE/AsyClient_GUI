import QtQuick 2.15
import QtQuick.Layouts 1.15
import "Utils.js" as Utils

Rectangle {
    id: root
    color: "transparent"
    
    property var model
    signal clearCompletedClicked()
    signal pauseAllClicked()
    signal resumeAllClicked()
    signal cancelAllClicked()
    signal itemActionClicked(int sid, string action)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 顶部工具栏
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "transparent"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                Text { text: "↑ 已完成"; color: "white"; font.pixelSize: 18; font.bold: true; visible: root.model.count > 0 }
                Item { Layout.fillWidth: true }
                RowLayout {
                    spacing: 25
                    // 暂停/恢复所有
                    MouseArea {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        cursorShape: Qt.PointingHandCursor
                        RowLayout { 
                            anchors.fill: parent; spacing: 8
                            Text { text: "⏸/▶"; color: "white"; font.pixelSize: 14 }
                            Text { text: "全部暂停/恢复"; color: "white" }
                        }
                        onClicked: {
                            // Simple logic: if any is running, pause all; otherwise resume all
                            var hasRunning = false;
                            for (var i = 0; i < root.model.count; i++) {
                                if (root.model.get(i).status === "传输中") { hasRunning = true; break; }
                            }
                            if (hasRunning) root.pauseAllClicked();
                            else root.resumeAllClicked();
                        }
                    }
                    
                    // 清除已完成
                    MouseArea {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        cursorShape: Qt.PointingHandCursor
                        RowLayout { 
                            anchors.fill: parent; spacing: 8
                            Text { text: "↻"; color: "white"; font.pixelSize: 14 }
                            Text { text: "清除已完成"; color: "white" }
                        }
                        onClicked: root.clearCompletedClicked()
                    }
                    
                    // 取消所有
                    MouseArea {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        cursorShape: Qt.PointingHandCursor
                        RowLayout { 
                            anchors.fill: parent; spacing: 8
                            Text { text: "✕"; color: "#e74c3c"; font.pixelSize: 14 }
                            Text { text: "取消所有"; color: "#e74c3c" }
                        }
                        onClicked: root.cancelAllClicked()
                    }
                }
            }
        }

        // 表头
        Rectangle {
            Layout.fillWidth: true; height: 40; color: "#111"; visible: root.model.count > 0
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25
                Text { text: "名称"; color: "#666"; Layout.preferredWidth: 300; font.pixelSize: 12 }
                Text { text: "类型"; color: "#666"; Layout.preferredWidth: 150; font.pixelSize: 12 }
                Text { text: "大小"; color: "#666"; Layout.preferredWidth: 100; font.pixelSize: 12 }
                Text { text: "已传输"; color: "#666"; Layout.preferredWidth: 100; font.pixelSize: 12 }
                Text { text: "预计完成时间"; color: "#666"; Layout.fillWidth: true; font.pixelSize: 12 }
                Text { text: "状态"; color: "#666"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            }
        }

        // 列表/空状态
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
            ColumnLayout {
                anchors.centerIn: parent; spacing: 20; visible: root.model.count === 0
                Rectangle { 
                    width: 160; height: 160; radius: 80; color: "#222"
                    Text { anchors.centerIn: parent; text: "⇅"; color: "#444"; font.pixelSize: 70 } 
                }
                Text { text: "无传输"; color: "white"; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            }

            ListView {
                anchors.fill: parent; model: root.model; clip: true
                delegate: Item {
                    width: parent.width; height: 55
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#111" }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25
                        RowLayout { 
                            Layout.preferredWidth: 300; spacing: 15
                            Text { text: Utils.getFileIcon(model.filename || ""); font.pixelSize: 22 }
                            Text { text: model.filename || ""; color: "white"; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        Text { text: Utils.getFileType(model.filename || ""); color: "#888"; Layout.preferredWidth: 150 }
                        Text { text: Utils.formatBytes(model.totalSize || 0); color: "#888"; Layout.preferredWidth: 100 }
                        Text { text: Utils.formatBytes(model.transferred || 0); color: "#888"; Layout.preferredWidth: 100 }
                        Text { text: model.status === "已完成" ? "" : Utils.formatTime(model.eta || 0); color: "#888"; Layout.fillWidth: true }
                        Text { text: model.status || ""; color: model.status === "已完成" ? "#2ecc71" : (model.status === "已暂停" || model.status === "中断" ? "#f39c12" : "#3498db"); Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; font.bold: true }
                        
                        // 操作按钮
                        RowLayout {
                            Layout.preferredWidth: 60; spacing: 10; visible: model.status !== "已完成" && model.status !== "已取消"
                            Text { 
                                text: (model.status === "已暂停" || model.status === "中断") ? "▶" : "⏸"
                                color: "white"; font.pixelSize: 16
                                MouseArea { 
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.itemActionClicked(model.sid, (model.status === "已暂停" || model.status === "中断") ? "resume" : "pause")
                                }
                            }
                            Text { 
                                text: "✕"
                                color: "#e74c3c"; font.pixelSize: 16
                                MouseArea { 
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.itemActionClicked(model.sid, "cancel")
                                }
                            }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width * model.progress; height: 2; color: "#3498db"; visible: model.status !== "已完成" }
                }
            }
        }
    }
}
