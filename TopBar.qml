import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    height: 60
    color: "#1a1a1a"
    
    property string placeholder: "搜索..."

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20; anchors.rightMargin: 20
        
        Rectangle {
            Layout.preferredWidth: 500; Layout.preferredHeight: 35; color: "#2a2a2a"; radius: 18
            TextInput {
                anchors.fill: parent; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; color: "white"
                Text { text: root.placeholder; color: "#666"; visible: parent.text === "" }
            }
        }
        
        Item { Layout.fillWidth: true }
        
        Text { text: "🔔"; font.pixelSize: 18; color: "white"; opacity: 0.7 }
        Rectangle {
            width: 32; height: 32; radius: 16; color: "#e74c3c"
            Text { anchors.centerIn: parent; text: "M"; color: "white" }
        }
    }
}
