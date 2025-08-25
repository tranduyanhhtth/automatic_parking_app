#pragma once
#include <QObject>
#include <QString>

class SettingsManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString camera1Url READ camera1Url WRITE setCamera1Url NOTIFY camera1UrlChanged)
    Q_PROPERTY(QString camera2Url READ camera2Url WRITE setCamera2Url NOTIFY camera2UrlChanged)
    Q_PROPERTY(QString camera3Url READ camera3Url WRITE setCamera3Url NOTIFY camera3UrlChanged)
    Q_PROPERTY(QString camera4Url READ camera4Url WRITE setCamera4Url NOTIFY camera4UrlChanged)
    Q_PROPERTY(QString barrier1Port READ barrier1Port WRITE setBarrier1Port NOTIFY barrier1PortChanged)
    Q_PROPERTY(int barrier1Baud READ barrier1Baud WRITE setBarrier1Baud NOTIFY barrier1BaudChanged)
    Q_PROPERTY(QString barrier2Port READ barrier2Port WRITE setBarrier2Port NOTIFY barrier2PortChanged)
    Q_PROPERTY(int barrier2Baud READ barrier2Baud WRITE setBarrier2Baud NOTIFY barrier2BaudChanged)
    // Windows: phân biệt đầu đọc thẻ theo thiết bị HID cụ thể
    Q_PROPERTY(QString entranceReaderPath READ entranceReaderPath WRITE setEntranceReaderPath NOTIFY entranceReaderPathChanged)
    Q_PROPERTY(QString exitReaderPath READ exitReaderPath WRITE setExitReaderPath NOTIFY exitReaderPathChanged)
public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString camera1Url() const { return m_camera1Url; }
    QString camera2Url() const { return m_camera2Url; }
    QString camera3Url() const { return m_camera3Url; }
    QString camera4Url() const { return m_camera4Url; }
    QString barrier1Port() const { return m_barrier1Port; }
    int barrier1Baud() const { return m_barrier1Baud; }
    QString barrier2Port() const { return m_barrier2Port; }
    int barrier2Baud() const { return m_barrier2Baud; }
    QString entranceReaderPath() const { return m_entranceReaderPath; }
    QString exitReaderPath() const { return m_exitReaderPath; }

public slots:
    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    void setCamera1Url(const QString &url);
    void setCamera2Url(const QString &url);
    void setCamera3Url(const QString &url);
    void setCamera4Url(const QString &url);
    void setBarrier1Port(const QString &port);
    void setBarrier1Baud(int baud);
    void setBarrier2Port(const QString &port);
    void setBarrier2Baud(int baud);
    void setEntranceReaderPath(const QString &p);
    void setExitReaderPath(const QString &p);

signals:
    void camera1UrlChanged();
    void camera2UrlChanged();
    void camera3UrlChanged();
    void camera4UrlChanged();
    void barrier1PortChanged();
    void barrier1BaudChanged();
    void barrier2PortChanged();
    void barrier2BaudChanged();
    void entranceReaderPathChanged();
    void exitReaderPathChanged();

private:
    QString m_camera1Url;
    QString m_camera2Url;
    QString m_camera3Url;
    QString m_camera4Url;
    QString m_barrier1Port;
    int m_barrier1Baud = 9600;
    QString m_barrier2Port;
    int m_barrier2Baud = 9600;
    QString m_entranceReaderPath;
    QString m_exitReaderPath;
};
