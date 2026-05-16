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
#include <QSemaphore>
#include <atomic>
#include <QUrl>
#include <QUrlQuery>
#include <QDesktopServices>
#ifdef _WIN32
#include <winsock2.h>
#else
#include <sys/socket.h>
#endif
#include <nlohmann/json.hpp>

ClientWrapper::ClientWrapper(QObject *parent)
    : QObject(parent), m_client(nullptr), m_connected(false), m_isDestroying(false)
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
    m_isDestroying = true;
    for (auto state : m_streamStates) {
        if (state) state->isDestroying = true;
    }
    
    if (m_proxyServer) m_proxyServer->close();
    
    for (auto socket : m_proxySockets) {
        if (socket) {
            socket->abort();
            socket->deleteLater();
        }
    }
    m_proxySockets.clear();

    if (m_client) {
        m_client->Close();
        delete m_client;
    }
}

QString ClientWrapper::currentUsername() const
{
    if (m_client) return QString::fromStdString(m_client->GetCurrentUsername());
    return "";
}

void ClientWrapper::connectToServer(const QString &ip, int port)
{
    if (m_client) delete m_client;
    m_client = new AsyCClient(ip.toStdString(), port);
    
    if (m_client->Connect()) {
        m_connected = true;
        
        m_client->SetOnKicked([this]() {
            emit loginResult(false, "您的账号在其他设备登录，已被强制下线。");
        });

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
            emit currentUsernameChanged();
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

void ClientWrapper::logout()
{
    if (!m_client) return;
    
    // Stop all transfers and connections
    m_client->Close();
    
    // Re-connect to allow new login
    std::string ip = "127.0.0.1"; // Default or cached
    uint16_t port = 8080;
    
    // Re-create client
    delete m_client;
    m_client = new AsyCClient(ip, port);
    if (m_client->Connect()) {
        m_connected = true;
    } else {
        m_connected = false;
    }
    
    emit connectedChanged();
    emit currentUsernameChanged();
    emit logoutFinished();
}

void ClientWrapper::listFiles(int parentId)
{
    if (!m_client) return;
    
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
            map["checked"] = false;
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
    if (!m_client || m_client->GetCurrentUserId() == -1) return;
    
    QString userDir = QString("usr/%1").arg(m_client->GetCurrentUserId());
    QDir().mkpath(userDir);
    QString fullPath = userDir + "/" + filename;

    m_client->Download(fileId, fullPath.toStdString(), [this, filename, fileId, fullPath](uint32_t sid, uint64_t cur, uint64_t total) {
        static QSet<uint32_t> startedStreams;
        if (!startedStreams.contains(sid)) {
            emit transferStarted((int)sid, fileId, filename, (qint64)total, "DL", fullPath);
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
        if (success) emit uploadFinished(); 
    });
}

void ClientWrapper::search(const QString &keyword)
{
    if (!m_client) return;

    std::thread([this, keyword]() {
        json files = m_client->Search(keyword.toStdString());
        QVariantList qlist;
        for (const auto& f : files) {
            QVariantMap map;
            map["id"] = f["id"].get<int>();
            map["filename"] = QString::fromStdString(f["filename"].get<std::string>());
            map["filesize"] = f["filesize"].get<qint64>();
            map["is_dir"] = f["is_dir"].is_boolean() ? f["is_dir"].get<bool>() : (f["is_dir"].get<int>() != 0);
            map["created_at"] = QString::fromStdString(f["created_at"].get<std::string>());
            map["checked"] = false;
            qlist.append(map);
        }
        
        emit fileListReceived(qlist);
    }).detach();
}

void ClientWrapper::moveFile(int fileId, int newParentId)
{
    if (!m_client) return;
    m_client->Move(fileId, newParentId, [this](bool success, std::string msg) {
        if (success) emit uploadFinished(); 
    });
}

void ClientWrapper::getAllDirectories()
{
    if (!m_client) return;

    std::thread([this]() {
        json dirs = m_client->GetAllDirs();
        QVariantList result;
        
        std::map<int, std::pair<int, std::string>> dirMap;
        for (const auto& d : dirs) {
            int id = d["id"].get<int>();
            int parent_id = d["parent_id"].get<int>();
            std::string filename = d["filename"].get<std::string>();
            dirMap[id] = {parent_id, filename};
        }

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
                    break; 
                }
            }
            
            path = "根目录/" + path;

            QVariantMap map;
            map["id"] = id;
            map["path"] = QString::fromStdString(path);
            result.append(map);
        }

        emit directoriesReceived(result);
    }).detach();
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

void ClientWrapper::saveCompletedTasks(const QVariantList &tasks)
{
    if (!m_client || m_client->GetCurrentUserId() == -1) return;
    QString userDir = QString("usr/%1").arg(m_client->GetCurrentUserId());
    QDir().mkpath(userDir);

    QJsonArray array;
    for (const auto &task : tasks) {
        array.append(QJsonObject::fromVariantMap(task.toMap()));
    }
    QJsonDocument doc(array);
    QFile file(userDir + "/completed.json");
    if (file.open(QFile::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
    }
}

QVariantList ClientWrapper::loadCompletedTasks()
{
    QVariantList result;
    if (!m_client || m_client->GetCurrentUserId() == -1) return result;

    QString userDir = QString("usr/%1").arg(m_client->GetCurrentUserId());
    QFile file(userDir + "/completed.json");
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
    if (m_isDestroying) return;
    QTcpSocket *socket = m_proxyServer->nextPendingConnection();
    if (!socket) return;

    m_proxySockets.append(socket);
    connect(socket, &QTcpSocket::disconnected, socket, &QTcpSocket::deleteLater);
    connect(socket, &QTcpSocket::destroyed, this, [this, socket]() {
        m_proxySockets.removeAll(socket);
    });

    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        if (m_isDestroying) return;
        QByteArray data = socket->readAll();
        QString request = QString::fromUtf8(data);
        
        if (!request.startsWith("GET")) return;
        
        QStringList requestParts = request.split(" ");
        if (requestParts.size() < 2) return;
        
        QUrl url(requestParts[1]);
        QUrlQuery query(url);
        int fileId = query.queryItemValue("file_id").toInt();
        
        uint64_t offset = 0;
        bool hasRange = false;
        bool hasEndOffset = false;
        uint64_t req_end_offset = 0;
        
        QStringList lines = request.split("\r\n");
        for (const QString& line : lines) {
            if (line.startsWith("Range: bytes=")) {
                QString rangeVal = line.mid(13);
                QStringList parts = rangeVal.split("-");
                if (!parts.isEmpty()) {
                    offset = parts[0].toULongLong();
                    hasRange = true;
                    if (parts.size() > 1 && !parts[1].isEmpty()) {
                        req_end_offset = parts[1].toULongLong();
                        hasEndOffset = true;
                    }
                }
                break;
            }
        }

        QPointer<QTcpSocket> pSocket(socket);

        auto state = std::make_shared<StreamState>();
        state->socketDescriptor = pSocket->socketDescriptor();
        m_streamStates.append(state);

        connect(pSocket.data(), &QTcpSocket::disconnected, this, [state]() {
            state->socketValid = false;
        });
        connect(pSocket.data(), &QTcpSocket::destroyed, this, [this, state]() {
            state->socketValid = false;
            state->isDestroying = true;
            m_streamStates.removeAll(state);
            
            int sid = state->streamId.load();
            if (sid != -1 && m_client) {
                m_client->AbortStream(sid);
            }
        });

        auto bytes_sent = std::make_shared<uint64_t>(0);
        m_client->StreamDownload(fileId, offset, [this, pSocket_raw = pSocket.data(), state, offset, hasRange, hasEndOffset, req_end_offset, bytes_sent](uint32_t sid, const std::vector<char>& chunk, uint64_t total, const std::string& name, bool is_eof) mutable -> bool {
            state->streamId.store(sid);
            if (state->isDestroying || !state->socketValid) return false;
            
            bool currentSocketValid = false;
            uint64_t end_offset = hasEndOffset ? qMin(req_end_offset, total - 1) : (total > 0 ? total - 1 : 0);
            uint64_t content_length = (total > 0 && end_offset >= offset) ? (end_offset - offset + 1) : 0;
            
            if (state->socketValid) {
                bool invoked = QMetaObject::invokeMethod(this, [this, pSocket_raw, state, chunk, total, name, is_eof, content_length, bytes_sent, offset, end_offset, hasRange]() {
                    if (state->isDestroying || !state->socketValid || !pSocket_raw || pSocket_raw->state() != QAbstractSocket::ConnectedState) {
                        state->socketValid = false;
                        state->sem.release();
                        return;
                    }
                        
                        if (!state->headersSent) {
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
                            pSocket_raw->write(response.toUtf8());
                            state->headersSent = true;
                        }
                        
                        if (!chunk.empty()) {
                            uint64_t remaining = content_length - *bytes_sent;
                            if (remaining > 0) {
                                size_t send_size = qMin((uint64_t)chunk.size(), remaining);
                                qint64 written = pSocket_raw->write(chunk.data(), send_size);
                                if (written == (qint64)send_size) {
                                    *bytes_sent += written;
                                } else {
                                    state->socketValid = false;
                                }
                            }
                        }
                        
                        if (is_eof || *bytes_sent >= content_length) {
                            pSocket_raw->disconnectFromHost();
                        }
                        
                        state->sem.release();
                }, Qt::QueuedConnection);
                
                if (invoked) {
                    if (state->sem.tryAcquire(1, 50)) {
                        currentSocketValid = state->socketValid;
                    } else {
#ifdef _WIN32
                        ::shutdown(state->socketDescriptor, SD_BOTH);
#else
                        ::shutdown(state->socketDescriptor, SHUT_RDWR);
#endif
                        state->socketValid = false;
                        currentSocketValid = false;
                    }
                } else {
                    currentSocketValid = false;
                }
                
                if (currentSocketValid && *bytes_sent >= content_length) {
                    currentSocketValid = false; 
                }
            }
            
            return currentSocketValid;
        });

    });
}

int ClientWrapper::getCurrentUserId()
{
    return m_client ? m_client->GetCurrentUserId() : -1;
}

void ClientWrapper::openLocalFile(const QString &localPath)
{
    QFileInfo fi(localPath);
    QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absoluteFilePath()));
}

void ClientWrapper::openLocalFolder(const QString &localPath)
{
    QFileInfo fi(localPath);
    QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absolutePath()));
}

bool ClientWrapper::deleteLocalFile(const QString &localPath)
{
    return QFile::remove(localPath);
}

QVariantList ClientWrapper::scanIncompleteDownloads(const QString &dir)
{
    QVariantList list;
    auto tasks = AsyCClient::ScanIncompleteDownloads(dir.toStdString());
    for (const auto &t : tasks) {
        QVariantMap map;
        map["sid"] = -1; 
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
