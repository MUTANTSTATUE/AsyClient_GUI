import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1a1a"
    
    signal loginRequested(string ip, string user, string pass)
    signal registerRequested(string ip, string user, string pass)

    property bool isRegisterMode: false

    ColumnLayout {
        anchors.centerIn: parent
        width: 350
        spacing: 25

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 80; height: 80; radius: 15; color: isRegisterMode ? "#27ae60" : "#e74c3c"
            Text { anchors.centerIn: parent; text: isRegisterMode ? "+" : "A"; color: "white"; font.pixelSize: 40; font.bold: true }
        }

        Text {
            text: isRegisterMode ? "创建新账户" : "登录到 AsyCDisk"
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
            text: isRegisterMode ? "立即注册" : "登录"; Layout.fillWidth: true; Layout.preferredHeight: 45
            onClicked: {
                if (isRegisterMode) {
                    root.registerRequested(ipField.text, userField.text, passField.text)
                } else {
                    root.loginRequested(ipField.text, userField.text, passField.text)
                }
            }
            background: Rectangle { radius: 6; color: parent.pressed ? (isRegisterMode ? "#1e8449" : "#c0392b") : (isRegisterMode ? "#27ae60" : "#e74c3c") }
            contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }

        Text {
            text: isRegisterMode ? "已有账号？返回登录" : "没有账号？点击注册"
            color: "#999"; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isRegisterMode = !root.isRegisterMode
            }
        }
    }
}
