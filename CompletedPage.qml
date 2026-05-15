import QtQuick 2.15
import QtQuick.Layouts 1.15
import "Utils.js" as Utils

Rectangle {
    id: root
    color: "transparent"
    
    property var model
    signal openFile(string localPath)
    signal openFolder(string localPath)
    signal deleteFile(int index)

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
                Text { text: "✅ 已完成下载"; color: "white"; font.pixelSize: 18; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { 
                    text: "共 " + root.model.count + " 个文件"
                    color: "#888"
                    font.pixelSize: 14
                    visible: root.model.count > 0
                }
            }
        }

        // 表头
        Rectangle {
            Layout.fillWidth: true; height: 40; color: "#111"; visible: root.model.count > 0
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25; spacing: 10
                Text { text: "名称"; color: "#666"; Layout.preferredWidth: 400; font.pixelSize: 12 }
                Text { text: "类型"; color: "#666"; Layout.preferredWidth: 100; font.pixelSize: 12 }
                Text { text: "大小"; color: "#666"; Layout.preferredWidth: 120; font.pixelSize: 12 }
                Text { text: "操作"; color: "#666"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 }
            }
        }

        // 列表/空状态
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
            
            ColumnLayout {
                anchors.centerIn: parent; spacing: 20; visible: root.model.count === 0
                Rectangle { 
                    width: 160; height: 160; radius: 80; color: "#222"
                    Text { anchors.centerIn: parent; text: "📦"; color: "#444"; font.pixelSize: 70 } 
                }
                Text { text: "暂无完成任务"; color: "white"; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            }

            ListView {
                anchors.fill: parent; model: root.model; clip: true
                delegate: Item {
                    width: parent.width; height: 60
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#111" }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 25; anchors.rightMargin: 25; spacing: 10
                        
                        RowLayout { 
                            Layout.preferredWidth: 400; spacing: 15
                            Text { text: Utils.getFileIcon(model.filename || ""); font.pixelSize: 24 }
                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: model.filename || ""; color: "white"; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14; font.bold: true }
                                Text { text: model.localPath || ""; color: "#555"; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11 }
                            }
                        }
                        
                        Text { text: Utils.getFileType(model.filename || ""); color: "#888"; Layout.preferredWidth: 100; font.pixelSize: 13 }
                        Text { text: Utils.formatBytes(model.totalSize || 0); color: "#888"; Layout.preferredWidth: 120; font.pixelSize: 13 }
                        
                        // 操作区
                        RowLayout {
                            Layout.fillWidth: true; spacing: 15; Layout.alignment: Qt.AlignRight
                            
                            Item { Layout.fillWidth: true }

                            Text {
                                text: "打开"
                                color: "#3498db"; font.pixelSize: 13; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFile(model.localPath)
                                }
                            }
                            
                            Text {
                                text: "文件夹"
                                color: "#95a5a6"; font.pixelSize: 13; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFolder(model.localPath)
                                }
                            }

                            Text {
                                text: "删除"
                                color: "#e74c3c"; font.pixelSize: 13; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteFile(index)
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onEntered: parent.children[0].color = "#222"
                        onExited: parent.children[0].color = "transparent"
                    }
                }
            }
        }
    }
}
