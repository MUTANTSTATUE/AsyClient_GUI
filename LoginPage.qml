import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1a1a"
    
    signal loginRequested(string ip, string user, string pass)

    ColumnLayout {
        anchors.centerIn: parent
        width: 350
        spacing: 25

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 80; height: 80; radius: 15; color: "#e74c3c"
            Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 40; font.bold: true }
        }

        Text {
            text: "登录到 AsyCDisk"
            color: "white"; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: ipField; Layout.fillWidth: true; placeholderText: "服务器 IP"; text: "127.0.0.1"
            background: Rectangle { radius: 6; color: "#2a2a2a"; border.color: "#333" }
            color: "white"
        }

        TextField {
            id: userField; Layout.fillWidth: true; placeholderText: "用户名"
            background: Rectangle { radius: 6; color: "#2a2a2a"; border.color: "#333" }
            color: "white"
        }

        TextField {
            id: passField; Layout.fillWidth: true; placeholderText: "密码"; echoMode: TextInput.Password
            background: Rectangle { radius: 6; color: "#2a2a2a"; border.color: "#333" }
            color: "white"
        }

        Button {
            text: "登录"; Layout.fillWidth: true; Layout.preferredHeight: 45
            onClicked: root.loginRequested(ipField.text, userField.text, passField.text)
            background: Rectangle { radius: 6; color: parent.pressed ? "#c0392b" : "#e74c3c" }
            contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
}
