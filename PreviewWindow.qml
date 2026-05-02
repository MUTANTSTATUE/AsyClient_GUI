import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Window {
    id: previewWindow
    width: 800
    height: 600
    title: "预览 - " + filename
    visible: true
    color: "black"

    property string filename: ""
    property string fileType: ""
    property string sourceUrl: ""

    // 图像预览
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: fileType === "图像" ? sourceUrl : ""
        visible: fileType === "图像"
        asynchronous: true
    }

    // 音视频播放器
    MediaPlayer {
        id: player
        source: (fileType === "视频" || fileType === "音频") ? sourceUrl : ""
        audioOutput: AudioOutput {}
        videoOutput: videoOutput
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: fileType === "视频" || fileType === "音频"
        fillMode: VideoOutput.PreserveAspectFit
    }

    // 播放控制栏
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 60
        color: "#AA000000"
        visible: fileType === "视频" || fileType === "音频"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 15

            Button {
                text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                font.pixelSize: 20
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause()
                    else
                        player.play()
                }
            }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: player.duration
                value: player.position
                onMoved: player.setPosition(value)
            }

            Text {
                color: "white"
                font.pixelSize: 14
                text: formatDuration(player.position) + " / " + formatDuration(player.duration)
            }
        }
    }

    function formatDuration(ms) {
        var seconds = Math.floor(ms / 1000)
        var m = Math.floor(seconds / 60)
        var s = seconds % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    Component.onCompleted: {
        if (fileType === "视频" || fileType === "音频") {
            player.play()
        }
    }

    onClosing: {
        player.stop()
    }
}
