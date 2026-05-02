.pragma library

function formatBytes(bytes) {
    if (bytes === 0) return "0 B";
    var k = 1024;
    var sizes = ["B", "KB", "MB", "GB", "TB"];
    var i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
}

function formatTime(seconds) {
    if (seconds === Infinity || isNaN(seconds)) return "--:--";
    var h = Math.floor(seconds / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    var s = Math.floor(seconds % 60);
    return (h > 0 ? h + "h " : "") + (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
}

function getFileIcon(filename) {
    if (!filename) return "📄";
    var parts = filename.split('.');
    if (parts.length < 2) return "📄";
    var ext = parts.pop().toLowerCase();
    if (["jpg", "jpeg", "png", "gif", "bmp"].indexOf(ext) >= 0) return "🖼️";
    if (["mp4", "mkv", "avi", "mov", "flv", "mpv"].indexOf(ext) >= 0) return "🎬";
    if (["mp3", "flac", "wav", "m4a"].indexOf(ext) >= 0) return "🎵";
    return "📄";
}

function getFileType(filename) {
    if (!filename) return "文件";
    var parts = filename.split('.');
    if (parts.length < 2) return "文件";
    var ext = parts.pop().toLowerCase();
    if (["jpg", "jpeg", "png", "gif", "bmp"].indexOf(ext) >= 0) return "图像";
    if (["mp4", "mkv", "avi", "mov", "flv", "mpv"].indexOf(ext) >= 0) return "视频";
    if (["mp3", "flac", "wav", "m4a"].indexOf(ext) >= 0) return "音频";
    return "文件";
}
