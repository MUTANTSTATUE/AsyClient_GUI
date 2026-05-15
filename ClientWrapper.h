#pragma once

#include <QObject>
#include <QVariantList>
#include <QPointer>
#include <memory>
#include <atomic>
#include "AsyCClient.h"

class ClientWrapper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString currentUsername READ currentUsername NOTIFY currentUsernameChanged)

public:
    explicit ClientWrapper(QObject *parent = nullptr);
    ~ClientWrapper();

    bool connected() const { return m_connected; }
    QString currentUsername() const;

    Q_INVOKABLE void connectToServer(const QString &ip, int port);
    Q_INVOKABLE void login(const QString &user, const QString &pass);
    Q_INVOKABLE void registerUser(const QString &user, const QString &pass);
    Q_INVOKABLE void logout();
    
    Q_INVOKABLE void listFiles(int parentId = 0);
    Q_INVOKABLE void upload(int parentId, const QString &localPath);
    Q_INVOKABLE void download(int fileId, const QString &filename);
    Q_INVOKABLE void remove(int fileId);
    Q_INVOKABLE void makeDir(int parentId, const QString &dirname);
    Q_INVOKABLE QVariantList scanIncompleteDownloads(const QString &dir);
    Q_INVOKABLE void moveFile(int fileId, int newParentId);
    Q_INVOKABLE void getAllDirectories();
    Q_INVOKABLE QString getPreviewUrl(int fileId);
    Q_INVOKABLE int getCurrentUserId();
    
    Q_INVOKABLE void openLocalFile(const QString &localPath);
    Q_INVOKABLE void openLocalFolder(const QString &localPath);
    Q_INVOKABLE bool deleteLocalFile(const QString &localPath);
    
    Q_INVOKABLE void pauseTransfer(int sid);
    Q_INVOKABLE void resumeTransfer(int sid);
    Q_INVOKABLE void cancelTransfer(int sid);
    Q_INVOKABLE void cancelAllTransfers();

    Q_INVOKABLE void saveTasks(const QVariantList &tasks);
    Q_INVOKABLE QVariantList loadTasks();
    Q_INVOKABLE void saveCompletedTasks(const QVariantList &tasks);
    Q_INVOKABLE QVariantList loadCompletedTasks();

signals:
    void connectedChanged();
    void currentUsernameChanged();
    void loginResult(bool success, QString message);
    void registerResult(bool success, QString message);
    void fileListReceived(QVariantList files);
    void directoriesReceived(QVariantList dirs);
    void transferStarted(int sid, int fileId, const QString &filename, qint64 totalSize, const QString &type, const QString &localPath = "");
    void progressUpdate(int sid, qint64 cur, qint64 total);
    void removeResult(bool success, QString message);
    void uploadFinished();
    void logoutFinished();

private slots:
    void handleProxyConnection();

private:
    struct StreamState {
        class QSemaphore *sem; 
        bool headersSent{false};
        std::atomic<bool> socketValid{true};
        std::atomic<bool> isDestroying{false};
        qintptr socketDescriptor;
    };

    AsyCClient *m_client;
    bool m_connected;
    
    class QTcpServer *m_proxyServer;
    int m_proxyPort;
    bool m_isDestroying;
    QList<class QTcpSocket*> m_proxySockets;
    QList<std::shared_ptr<StreamState>> m_streamStates;
};
