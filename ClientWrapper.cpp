#include "ClientWrapper.h"
#include <thread>
#include <QDebug>
#include <QFileInfo>
#include <QSet>
#include <QMap>

ClientWrapper::ClientWrapper(QObject *parent)
    : QObject(parent), m_client(nullptr), m_connected(false)
{
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

void ClientWrapper::listFiles()
{
    if (!m_client) return;
    std::thread([this]() {
        json files = m_client->List();
        QVariantList qFiles;
        for (auto& f : files) {
            QVariantMap item;
            item["id"] = f["id"].get<int>();
            item["filename"] = QString::fromStdString(f["filename"].get<std::string>());
            item["filesize"] = (qint64)f["filesize"].get<uint64_t>();
            item["created_at"] = QString::fromStdString(f["created_at"].get<std::string>());
            qFiles.append(item);
        }
        emit fileListReceived(qFiles);
    }).detach();
}

void ClientWrapper::upload(const QString &path)
{
    if (!m_client) return;
    
    QString cleanPath = path;
    if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    
    QString filename = QFileInfo(cleanPath).fileName();

    m_client->Upload(cleanPath.toStdString(), [this, filename](uint32_t sid, uint64_t cur, uint64_t total) {
        static QSet<uint32_t> startedStreams;
        if (!startedStreams.contains(sid)) {
            emit transferStarted((int)sid, filename, (qint64)total, "UP");
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
    
    // 我们用一个随机 SID 或临时 SID 占位？
    // 不，库里的 SID 是自增的。我们可以通过一个简单的机制获取它，
    // 或者让库支持在启动时立刻回调。
    
    // 方案：让库的 Download 逻辑在发送请求前就先回调一次，或者由 Wrapper 预判。
    // 为了最快解决“看不见”的问题，我们直接在回调里移除 total > 0 的限制。

    m_client->Download(fileId, [this, filename](uint32_t sid, uint64_t cur, uint64_t total) {
        static QSet<uint32_t> startedStreams;
        if (!startedStreams.contains(sid)) {
            emit transferStarted((int)sid, filename, (qint64)total, "DL");
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
