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
        
        RowLayout {
            spacing: 15
            
            Column {
                Layout.alignment: Qt.AlignRight
                Text {
                    text: client.currentUsername
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                }
                Text {
                    id: logoutBtn
                    text: "注销"
                    color: "#e74c3c"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            client.logout();
                        }
                    }
                }
            }

            Rectangle {
                width: 36; height: 36; radius: 18; color: "#3498db"
                Text { 
                    anchors.centerIn: parent
                    text: client.currentUsername.substring(0, 1).toUpperCase()
                    color: "white"
                    font.bold: true
                }
            }
        }
    }
}
