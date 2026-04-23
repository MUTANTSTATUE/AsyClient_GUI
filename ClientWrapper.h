#pragma once

#include <QObject>
#include <QVariantList>
#include "AsyCClient.h"

class ClientWrapper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit ClientWrapper(QObject *parent = nullptr);
    ~ClientWrapper();

    bool connected() const { return m_connected; }

    Q_INVOKABLE void connectToServer(const QString &ip, int port);
    Q_INVOKABLE void login(const QString &user, const QString &pass);
    Q_INVOKABLE void listFiles();
    Q_INVOKABLE void upload(const QString &path);
    Q_INVOKABLE void download(int fileId, const QString &filename);
    Q_INVOKABLE void remove(int fileId);

signals:
    void connectedChanged();
    void loginResult(bool success, QString message);
    void fileListReceived(QVariantList files);
    void transferStarted(int sid, QString filename, qint64 totalSize, QString type);
    void progressUpdate(int sid, qint64 cur, qint64 total);
    void removeResult(bool success, QString message);
    void uploadFinished();

private:
    AsyCClient *m_client;
    bool m_connected;
};
