import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#111111"
    
    property string currentState: "cloud"
    signal navClicked(string target)

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 20
        spacing: 10

        RowLayout {
            Layout.leftMargin: 20; spacing: 10
            Rectangle { width: 32; height: 32; radius: 4; color: "#e74c3c"; Text { anchors.centerIn: parent; text: "A"; color: "white"; font.bold: true } }
            Text { text: "AsyCDisk"; color: "white"; font.pixelSize: 18; font.bold: true }
        }

        Item { Layout.preferredHeight: 20 }

        Repeater {
            model: [
                { id: "cloud", icon: "☁️", label: "云盘" },
                { id: "transfer", icon: "🔄", label: "传输" },
                { id: "completed", icon: "✅", label: "已完成" }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 45
                color: root.currentState === modelData.id ? "#222222" : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 20; spacing: 15
                    Text { text: modelData.icon; font.pixelSize: 18 }
                    Text { text: modelData.label; color: "white"; font.pixelSize: 14 }
                }
                MouseArea { anchors.fill: parent; onClicked: root.navClicked(modelData.id) }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
