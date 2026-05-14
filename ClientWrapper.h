#pragma once

#include "AsyCClient.h"
#include <QObject>
#include <QString>
#include <QVariantList>

class ClientWrapper : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
  explicit ClientWrapper(QObject *parent = nullptr);
  ~ClientWrapper();

  bool connected() const { return m_connected; }

  Q_INVOKABLE void connectToServer(const QString &ip, int port);
  Q_INVOKABLE void login(const QString &user, const QString &pass);
  Q_INVOKABLE void registerUser(const QString &user, const QString &pass);
  Q_INVOKABLE void listFiles(int parentId = 0);
  Q_INVOKABLE void upload(int parentId, const QString &localPath);
  Q_INVOKABLE void download(int fileId, const QString &filename);
  Q_INVOKABLE void remove(int fileId);
  Q_INVOKABLE void makeDir(int parentId, const QString &dirname);
  Q_INVOKABLE QVariantList scanIncompleteDownloads(const QString &dir);
  Q_INVOKABLE void moveFile(int fileId, int newParentId);
  Q_INVOKABLE QVariantList getAllDirectories();
  Q_INVOKABLE QString getPreviewUrl(int fileId);
  Q_INVOKABLE int getCurrentUserId();

  Q_INVOKABLE void pauseTransfer(int sid);
  Q_INVOKABLE void resumeTransfer(int sid);
  Q_INVOKABLE void cancelTransfer(int sid);
  Q_INVOKABLE void cancelAllTransfers();

  Q_INVOKABLE void saveTasks(const QVariantList &tasks);
  Q_INVOKABLE QVariantList loadTasks();

signals:
  void connectedChanged();
  void loginResult(bool success, QString message);
  void registerResult(bool success, QString message);
  void fileListReceived(QVariantList files);
  void transferStarted(int sid, int fileId, const QString &filename,
                       qint64 totalSize, const QString &type,
                       const QString &localPath = "");
  void progressUpdate(int sid, qint64 cur, qint64 total);
  void removeResult(bool success, QString message);
  void uploadFinished();

private slots:
  void handleProxyConnection();

private:
  AsyCClient *m_client;
  bool m_connected;

  class QTcpServer *m_proxyServer;
  int m_proxyPort;
};
