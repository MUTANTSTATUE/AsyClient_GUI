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
                anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25; spacing: 10
                Text { text: "名称"; color: "#666"; Layout.preferredWidth: 300; font.pixelSize: 12 }
                Text { text: "类型"; color: "#666"; Layout.preferredWidth: 100; font.pixelSize: 12 }
                Text { text: "大小"; color: "#666"; Layout.preferredWidth: 100; font.pixelSize: 12 }
                Text { text: "已传输/进度"; color: "#666"; Layout.preferredWidth: 120; font.pixelSize: 12 }
                Text { text: "剩余时间 / 速度"; color: "#666"; Layout.fillWidth: true; font.pixelSize: 12 }
                Text { text: "状态"; color: "#666"; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
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
                        anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25; spacing: 10
                        RowLayout { 
                            Layout.preferredWidth: 300; spacing: 10
                            Text { 
                                text: model.type === "UP" ? "↑" : "↓"
                                color: model.type === "UP" ? "#e67e22" : "#2ecc71"
                                font.bold: true; font.pixelSize: 18
                            }
                            Text { text: Utils.getFileIcon(model.filename || ""); font.pixelSize: 22 }
                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: model.filename || ""; color: "white"; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14 }
                                Text { 
                                    text: (model.progress * 100).toFixed(1) + "%" 
                                    color: "#3498db"; font.pixelSize: 10; visible: model.status !== "已完成"
                                }
                            }
                        }
                        Text { text: Utils.getFileType(model.filename || ""); color: "#888"; Layout.preferredWidth: 100; font.pixelSize: 13 }
                        Text { text: Utils.formatBytes(model.totalSize || 0); color: "#888"; Layout.preferredWidth: 100; font.pixelSize: 13 }
                        Text { text: Utils.formatBytes(model.transferred || 0); color: "#888"; Layout.preferredWidth: 120; font.pixelSize: 13 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { 
                                text: (model.status === "已完成" || !model.eta) ? "" : Utils.formatTime(model.eta)
                                color: "white"; font.pixelSize: 13; font.bold: true
                            }
                            Text { 
                                text: model.status === "传输中" ? (Utils.formatBytes(model.speed || 0) + "/s") : ""
                                color: "#888"; font.pixelSize: 10
                            }
                        }
                        
                        // 状态与操作区
                        RowLayout {
                            Layout.preferredWidth: 100; spacing: 8
                            Text { 
                                text: model.status || ""; color: model.status === "已完成" ? "#2ecc71" : (model.status === "已暂停" || model.status === "中断" ? "#f39c12" : "#3498db")
                                Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.bold: true; font.pixelSize: 13
                            }
                            // 操作按钮
                            RowLayout {
                                spacing: 10; visible: model.status !== "已完成" && model.status !== "已取消"
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
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width * model.progress; height: 2; color: "#3498db"; visible: model.status !== "已完成" }
                }
            }
        }
    }
}
