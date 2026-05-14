#include "ClientWrapper.h"
#include <thread>
#include <QDebug>
#include <QFileInfo>
#include <QSet>
#include <QMap>
#include <QTcpServer>
#include <QTcpSocket>
#include <QRegularExpression>
#include <QPointer>
#include <QHostAddress>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <nlohmann/json.hpp>

ClientWrapper::ClientWrapper(QObject *parent)
    : QObject(parent), m_client(nullptr), m_connected(false)
{
    m_proxyServer = new QTcpServer(this);
    connect(m_proxyServer, &QTcpServer::newConnection, this, &ClientWrapper::handleProxyConnection);
    if (m_proxyServer->listen(QHostAddress::LocalHost)) {
        m_proxyPort = m_proxyServer->serverPort();
        qDebug() << "Local HTTP proxy server listening on port:" << m_proxyPort;
    }
}

ClientWrapper::~ClientWrapper()
{
    if (m_client) {
        m_client->Close();
        delete m_client;
    }
}

void ClientWrapper::connectToServer(const QString &ip, int port)
{
    if (m_client) delete m_client;
    m_client = new AsyCClient(ip.toStdString(), port);
    
    if (m_client->Connect()) {
        m_connected = true;
        emit connectedChanged();
        qDebug() << "Connected to server";
    }
}

void ClientWrapper::login(const QString &user, const QString &pass)
{
    if (!m_client) return;
    
    std::thread([this, user, pass]() {
        bool ok = m_client->Login(user.toStdString(), pass.toStdString());
        if (ok) {
            emit loginResult(true, "Login Successful");
        } else {
            emit loginResult(false, "Login Failed: Check credentials or server status");
        }
    }).detach();
}

void ClientWrapper::registerUser(const QString &user, const QString &pass)
{
    if (!m_client) return;
    
    std::thread([this, user, pass]() {
        bool ok = m_client->Register(user.toStdString(), pass.toStdString());
        if (ok) {
            emit registerResult(true, "Registration Successful");
        } else {
            emit registerResult(false, "Registration Failed: User may exist or server error");
        }
    }).detach();
}

void ClientWrapper::listFiles(int parentId)
{
    if (!m_client) return;
    
    // std::thread run to not block GUI
    std::thread([this, parentId]() {
        json files = m_client->List(parentId);
        QVariantList qlist;
        
        for (const auto& f : files) {
            QVariantMap map;
            map["id"] = f["id"].get<int>();
            map["filename"] = QString::fromStdString(f["filename"].get<std::string>());
            map["filesize"] = f["filesize"].get<qint64>();
            map["is_dir"] = f["is_dir"].is_boolean() ? f["is_dir"].get<bool>() : (f["is_dir"].get<int>() != 0);
            map["created_at"] = QString::fromStdString(f["created_at"].get<std::string>());
            qlist.append(map);
        }
        
        emit fileListReceived(qlist);
    }).detach();
}

void ClientWrapper::upload(int parentId, const QString &localPath)
{
    if (!m_client) return;
    
    QString cleanPath = localPath;
    if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    
    QString filename = QFileInfo(cleanPath).fileName();

    m_client->Upload(cleanPath.toStdString(), parentId, [this, filename, cleanPath](uint32_t sid, uint64_t cur, uint64_t total) {
        static QSet<uint32_t> startedStreams;
        if (!startedStreams.contains(sid)) {
            emit transferStarted((int)sid, 0, filename, (qint64)total, "UP", cleanPath);
            startedStreams.insert(sid);
        }
        emit progressUpdate((int)sid, (qint64)cur, (qint64)total);
        if (total > 0 && cur >= total) {
            emit uploadFinished();
        }
    });
}

void ClientWrapper::download(int fileId, const QString &filename)
{
    if (!m_client) return;
    
    m_client->Download(fileId, filename.toStdString(), [this, filename, fileId](uint32_t sid, uint64_t cur, uint64_t total) {
        static QSet<uint32_t> startedStreams;
        if (!startedStreams.contains(sid)) {
            emit transferStarted((int)sid, fileId, filename, (qint64)total, "DL", "");
            startedStreams.insert(sid);
        }
        emit progressUpdate((int)sid, (qint64)cur, (qint64)total);
    });
}

void ClientWrapper::remove(int fileId)
{
    if (!m_client) return;
    m_client->Remove(fileId, [this](bool success, std::string msg) {
        emit removeResult(success, QString::fromStdString(msg));
    });
}

void ClientWrapper::makeDir(int parentId, const QString &dirname)
{
    if (!m_client) return;
    m_client->MakeDir(parentId, dirname.toStdString(), [this](bool success, std::string msg) {
        // emit a signal or we can just let QML refresh
        if (success) emit uploadFinished(); // uploadFinished will trigger a refresh in QML currently
    });
}

void ClientWrapper::moveFile(int fileId, int newParentId)
{
    if (!m_client) return;
    m_client->Move(fileId, newParentId, [this](bool success, std::string msg) {
        if (success) emit uploadFinished(); // reuse uploadFinished to trigger refresh
    });
}

QVariantList ClientWrapper::getAllDirectories()
{
    QVariantList result;
    if (!m_client) return result;

    json dirs = m_client->GetAllDirs();
    
    // id -> {parent_id, filename}
    std::map<int, std::pair<int, std::string>> dirMap;
    for (const auto& d : dirs) {
        int id = d["id"].get<int>();
        int parent_id = d["parent_id"].get<int>();
        std::string filename = d["filename"].get<std::string>();
        dirMap[id] = {parent_id, filename};
    }

    // Always add root
    QVariantMap rootMap;
    rootMap["id"] = 0;
    rootMap["path"] = QString("根目录");
    result.append(rootMap);

    for (const auto& d : dirs) {
        int id = d["id"].get<int>();
        std::string path = d["filename"].get<std::string>();
        int current_parent = d["parent_id"].get<int>();
        
        while (current_parent != 0) {
            auto it = dirMap.find(current_parent);
            if (it != dirMap.end()) {
                path = it->second.second + "/" + path;
                current_parent = it->second.first;
            } else {
                break; // Should not happen if db is consistent
            }
        }
        
        path = "根目录/" + path;

        QVariantMap map;
        map["id"] = id;
        map["path"] = QString::fromStdString(path);
        result.append(map);
    }

    return result;
}

QString ClientWrapper::getPreviewUrl(int fileId)
{
    return QString("http://127.0.0.1:%1/preview?file_id=%2").arg(m_proxyPort).arg(fileId);
}

void ClientWrapper::pauseTransfer(int sid)
{
    if (m_client) m_client->PauseStream(sid);
}

void ClientWrapper::resumeTransfer(int sid)
{
    if (m_client) m_client->ResumeStream(sid);
}

void ClientWrapper::cancelTransfer(int sid)
{
    if (m_client) m_client->AbortStream(sid);
}

void ClientWrapper::cancelAllTransfers()
{
    // Individual cancel should be used via model loop in QML
}

void ClientWrapper::saveTasks(const QVariantList &tasks)
{
    if (!m_client || m_client->GetCurrentUserId() == -1) return;
    
    QString userDir = QString("usr/%1").arg(m_client->GetCurrentUserId());
    QDir().mkpath(userDir);

    QJsonArray array;
    for (const auto &task : tasks) {
        array.append(QJsonObject::fromVariantMap(task.toMap()));
    }
    QJsonDocument doc(array);
    QFile file(userDir + "/tasks.json");
    if (file.open(QFile::WriteOnly)) {
        file.write(doc.toJson());
        file.flush();
        file.close();
        qDebug() << "Tasks saved successfully to" << file.fileName();
    } else {
        qCritical() << "Failed to open tasks.json for writing:" << file.errorString();
    }
}

QVariantList ClientWrapper::loadTasks()
{
    QVariantList result;
    if (!m_client || m_client->GetCurrentUserId() == -1) return result;

    QString userDir = QString("usr/%1").arg(m_client->GetCurrentUserId());
    QFile file(userDir + "/tasks.json");
    if (file.open(QFile::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        QJsonArray array = doc.array();
        for (int i = 0; i < array.size(); i++) {
            result.append(array[i].toObject().toVariantMap());
        }
        file.close();
    }
    return result;
}

void ClientWrapper::handleProxyConnection()
{
    QTcpSocket *socket = m_proxyServer->nextPendingConnection();
    if (!socket) return;

    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        if (!socket->canReadLine()) return;
        
        QString requestLine = socket->readLine();
        QRegularExpression re("GET /preview\\?file_id=(\\d+)");
        QRegularExpressionMatch match = re.match(requestLine);
        
        if (!match.hasMatch()) {
            socket->close();
            socket->deleteLater();
            return;
        }
        
        int fileId = match.captured(1).toInt();
        uint64_t offset = 0;
        bool hasRange = false;
        bool hasEndOffset = false;
        uint64_t req_end_offset = 0;
        
        // 解析 HTTP 头部，查找 Range
        while (socket->canReadLine()) {
            QString header = socket->readLine();
            if (header == "\r\n") break;
            if (header.startsWith("Range: bytes=")) {
                hasRange = true;
                QString rangeStr = header.mid(13).trimmed();
                QStringList parts = rangeStr.split("-");
                if (!parts.isEmpty() && !parts[0].isEmpty()) {
                    offset = parts[0].toULongLong();
                }
                if (parts.size() > 1 && !parts[1].isEmpty()) {
                    req_end_offset = parts[1].toULongLong();
                    hasEndOffset = true;
                }
            }
        }
        
        // 停止监听 read，防止冲突
        socket->disconnect(SIGNAL(readyRead()));
        connect(socket, &QTcpSocket::disconnected, socket, &QTcpSocket::deleteLater);

        if (!m_client) {
            socket->close();
            return;
        }

        QPointer<QTcpSocket> pSocket(socket);

        // Share the bytes_sent counter
        std::shared_ptr<uint64_t> bytes_sent = std::make_shared<uint64_t>(0);

        m_client->StreamDownload(fileId, offset, [pSocket, offset, hasRange, hasEndOffset, req_end_offset, bytes_sent, headersSent = false](const std::vector<char>& chunk, uint64_t total, const std::string& name, bool is_eof) mutable -> bool {
            bool socketValid = false;
            uint64_t end_offset = hasEndOffset ? qMin(req_end_offset, total - 1) : (total > 0 ? total - 1 : 0);
            uint64_t content_length = (total > 0 && end_offset >= offset) ? (end_offset - offset + 1) : 0;
            
            if (pSocket) {
                bool invoked = QMetaObject::invokeMethod(pSocket.data(), [&]() {
                    if (pSocket && pSocket->state() == QAbstractSocket::ConnectedState) {
                        
                        if (!headersSent) {
                            QString response;
                            if (hasRange) {
                                response = "HTTP/1.1 206 Partial Content\r\n";
                                response += QString("Content-Range: bytes %1-%2/%3\r\n")
                                                .arg(offset).arg(end_offset).arg(total);
                            } else {
                                response = "HTTP/1.1 200 OK\r\n";
                            }
                            
                            QString mimeType = "application/octet-stream";
                            QString lowerName = QString::fromStdString(name).toLower();
                            if (lowerName.endsWith(".mp4") || lowerName.endsWith(".mpv") || lowerName.endsWith(".mkv") || lowerName.endsWith(".avi")) mimeType = "video/mp4";
                            else if (lowerName.endsWith(".mp3")) mimeType = "audio/mpeg";
                            else if (lowerName.endsWith(".jpg") || lowerName.endsWith(".jpeg")) mimeType = "image/jpeg";
                            else if (lowerName.endsWith(".png")) mimeType = "image/png";
                            
                            response += "Content-Type: " + mimeType + "\r\n";
                            response += QString("Content-Length: %1\r\n").arg(content_length);
                            response += "Accept-Ranges: bytes\r\n";
                            response += "Connection: close\r\n";
                            response += "\r\n";
                            pSocket->write(response.toUtf8());
                            headersSent = true;
                        }
                        
                        if (!chunk.empty()) {
                            // Calculate how much we can actually send
                            uint64_t remaining = content_length - *bytes_sent;
                            if (remaining > 0) {
                                size_t send_size = qMin((uint64_t)chunk.size(), remaining);
                                pSocket->write(chunk.data(), send_size);
                                *bytes_sent += send_size;
                            }
                        }
                        
                        // If we've sent everything requested, or the file ended naturally
                        if (is_eof || *bytes_sent >= content_length) {
                            pSocket->disconnectFromHost();
                        }
                        
                        socketValid = true;
                    }
                }, Qt::BlockingQueuedConnection);
                
                if (!invoked) socketValid = false;
                
                // Tell StreamDownload to abort if we hit our requested limit
                if (socketValid && *bytes_sent >= content_length) {
                    socketValid = false; 
                }
            }
            
            return socketValid;
        });

    });
}

int ClientWrapper::getCurrentUserId()
{
    return m_client ? m_client->GetCurrentUserId() : -1;
}

QVariantList ClientWrapper::scanIncompleteDownloads(const QString &dir)
{
    QVariantList list;
    auto tasks = AsyCClient::ScanIncompleteDownloads(dir.toStdString());
    for (const auto &t : tasks) {
        QVariantMap map;
        map["sid"] = -1; // 还没分配 sid
        map["fileId"] = t.file_id;
        map["filename"] = QString::fromStdString(t.filename);
        map["username"] = QString::fromStdString(t.username);
        map["totalSize"] = (qint64)t.total_size;
        map["transferred"] = (qint64)t.current_offset;
        map["localPath"] = QString::fromStdString(t.local_path);
        map["type"] = "DL";
        map["status"] = "中断";
        map["progress"] = t.total_size > 0 ? (double)t.current_offset / t.total_size : 0;
        list.append(map);
    }
    return list;
}
