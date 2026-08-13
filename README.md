[README.md](https://github.com/user-attachments/files/31025713/README.md)
# AsyClient_GUI - AsyCDisk 桌面图形客户端

[![Language](https://img.shields.io/badge/Language-C%2B%2B17-blue.svg)](https://en.cppreference.com/w/cpp/17)
[![Framework](https://img.shields.io/badge/Framework-Qt6%20%2F%20QML-green.svg)](https://www.qt.io/)
[![Controls](https://img.shields.io/badge/UI-QuickControls2-brightgreen.svg)](https://doc.qt.io/qt-6/qtquickcontrols-index.html)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**AsyClient_GUI** 是为 **AsyCDisk 高性能网络云盘** 打造的跨平台现代化桌面图形客户端。基于 C++17 与 Qt 6 / QML 技术栈构建，融合深色极简 UI 设计、多任务传输管理、断点续传恢复以及创新的**嵌入式本地 HTTP 代理在线视频流播放与任意 Seek** 功能。

---

## 目录

- [核心特性](#核心特性)
- [软件架构设计](#软件架构设计)
- [界面与项目结构](#界面与项目结构)
- [环境依赖](#环境依赖)
- [编译与构建](#编译与构建)
- [核心功能说明](#核心功能说明)
  - [1. 在线视频预览与 Seek (内置 HTTP 代理)](#1-在线视频预览与-seek-内置-http-代理)
  - [2. 传输中心与断点续传](#2-传输中心与断点续传)
  - [3. 多账号安全隔离](#3-多账号安全隔离)

---

## 核心特性

- **🎨 现代化 QML 界面**：深色极简设计语言，支持面包屑路径导航、全局搜索、目录树展示以及文件平铺/列表视图切换。
- **🎬 本地 HTTP 代理在线流媒体播放**：
  内置 `QTcpServer` 高效 HTTP 代理服务器，将云盘二进制分块下载无缝转换为标准 `HTTP Range` 响应，支持 QML `MediaPlayer` 或外部播放器 (VLC/mpv) 秒开视频播放与任意位置毫秒级拖拽 (Seek)。
- **🚀 多任务传输与速率控制**：
  实时计算上传/下载速度、已传输字节与剩余百分比，支持任务的暂停 (`Pause`)、继续 (`Resume`) 与取消 (`Cancel`)。
- **⏯️ 任务持久化与断点续传**：
  客户端自动维持未完成任务列表 (`tasks.json`) 与分块进度 (.meta)，应用意外关闭或重启后可一键恢复未完成的传输任务。
- **🔒 用户数据与安全隔离**：
  所有传输任务、完成历史记录与缓存元数据均严格绑定 `user_id`，防止多用户切换时的任务泄漏与越权访问。
- **📂 全功能云盘文件管理**：
  支持在线文件上传、指定位置下载、新建文件夹、文件删除、文件移动与重命名 (`moveFile`)。

---

## 软件架构设计

GUI 客户端采用经典的 QML UI + C++ 业务逻辑桥接 + 核心网络引擎架构：

```text
+------------------------------------------------------------------+
|                    QML Visual Layer (Front-End)                  |
|  +--------------+  +---------------+  +-----------------------+  |
|  | LoginPage.qml|  | CloudPage.qml |  | Transfer/CompletedPage|  |
|  +------+-------+  +-------+-------+  +-----------+-----------+  |
|         |                  |                      |              |
+---------|------------------|----------------------|--------------+
          | Qt Property & Q_INVOKABLE Signals / Slots
+---------v------------------v----------------------v--------------+
|                   ClientWrapper (Qt C++ Bridge)                  |
|  - QObject Wrapper        - Proxy HTTP Server (QTcpServer)       |
|  - Transfer Task State    - User Session & Task Persistence      |
+------------------------------------+-----------------------------+
                                     |
+------------------------------------v-----------------------------+
|                      libasyc_client (Core Engine)                |
|  - ACDK Protocol Handler  - Async Socket Loop  - Stream Receiver |
+------------------------------------+-----------------------------+
                                     | (ACDK Binary TCP Protocol)
                                     v
                           AsyCDisk Server (Remote)
```

---

## 界面与项目结构

```
AsyClient_GUI/
├── CMakeLists.txt          # CMake 构建配置文件
├── ClientWrapper.h/.cpp    # C++ Qt 桥接类及嵌入式本地 HTTP Range 代理服务器
├── main.cpp                # GUI 程序主入口
├── main.qml                # 主窗口容器、深色主题样式与全局弹窗组件
├── Sidebar.qml             # 侧边栏导航控件 (云端网盘/传输中心/完成列表)
├── TopBar.qml              # 顶部状态栏与用户信息控件
├── LoginPage.qml           # 用户登录与注册界面
├── CloudPage.qml           # 云端文件浏览器 (面包屑、搜索、右键菜单)
├── TransferPage.qml        # 进行中传输任务管理 (进度条/速率/暂停/继续)
├── CompletedPage.qml       # 已完成传输历史 (打开文件/打开所在文件夹)
├── PreviewWindow.qml       # 视频在线播放与预览弹窗
├── Utils.js                # QML 前端通用工具函数 (文件大小格式化等)
├── qml.qrc                 # Qt 资源文件清单
└── lib/                    # 依赖的 asyc_client 核心库 (libasyc_client.a)
```

---

## 环境依赖

- **操作系统**：Linux (Ubuntu 20.04+, Debian, Arch 等) / macOS / Windows
- **编译器**：GCC >= 8.0, Clang >= 7.0 或 MSVC 2019+ (支持 C++17)
- **构建工具**：CMake >= 3.16
- **Qt 框架**：Qt 6.x (推荐) 或 Qt 5.15+，需安装以下模块：
  - `Core`, `Gui`, `Qml`, `Quick`, `QuickControls2`
  - `Network`
  - `Multimedia` (用于视频在线播放)
- **底层依赖**：`libasyc_client.a` 静态库（由 `AsyCDisk/AsyCClient_CLI` 编译生成）

---

## 编译与构建

### 1. 准备核心静态库

编译 GUI 前，请确保 `AsyCClient_CLI` 已编译出 `libasyc_client.a` 并存放在 `AsyClient_GUI/lib/` 目录下：

```bash
# 在 AsyCDisk 项目中编译 CLI 库
cd ../AsyCDisk/AsyCClient_CLI
mkdir -p build && cd build
cmake .. && make -j$(nproc)

# 确认 libasyc_client.a 已存在于 AsyClient_GUI/lib 目录
```

### 2. 编译 GUI 客户端

```bash
cd AsyClient_GUI
mkdir -p build && cd build
cmake ..
make -j$(nproc)
```

### 3. 运行 GUI

```bash
./AsyClient_GUI
```

---

## 核心功能说明

### 1. 在线视频预览与 Seek (内置 HTTP 代理)
- 当用户在 `CloudPage` 点击视频预览或调用 `getPreviewUrl(fileId)` 时，`ClientWrapper` 会启动一个本地随机端口的 `QTcpServer` HTTP 代理。
- 当 QML `MediaPlayer` 或外部播放器请求 `http://127.0.0.1:<port>/stream?file_id=xxx` 时，代理服务器会拦截 HTTP `Range: bytes=start-end` 请求。
- 代理层将 Range 请求转换为 ACDK 协议中的 `DownloadReq (cmd: 12)` 发送给 AsyCDisk 服务端，实现高效率按需分块流式读取，无需下载完整个大视频即可实时 Seek 拖拽播放。

### 2. 传输中心与断点续传
- 支持并发文件上传与下载，界面实时刷新速率与预计剩余时间。
- 未完成的任务进度会自动写盘备份，应用异常中断重启后，用户可通过传输界面恢复中断的任务。

### 3. 多账号安全隔离
- `ClientWrapper` 在保存与加载 `tasks.json` 及 `completed.json` 时校验当前 `user_id`。
- 切换用户登录时，客户端会自动清理并隔离上个用户的未完成任务视图与临时文件路径，保证多用户共享设备时的隐私与安全。
