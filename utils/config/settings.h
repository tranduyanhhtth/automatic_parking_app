#pragma once
#include <QObject>
#include <QString>

class SettingsManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString camera1Url READ camera1Url WRITE setCamera1Url NOTIFY camera1UrlChanged)
    Q_PROPERTY(QString camera2Url READ camera2Url WRITE setCamera2Url NOTIFY camera2UrlChanged)
    Q_PROPERTY(QString barrierPort READ barrierPort WRITE setBarrierPort NOTIFY barrierPortChanged)
    Q_PROPERTY(int barrierBaud READ barrierBaud WRITE setBarrierBaud NOTIFY barrierBaudChanged)
public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString camera1Url() const { return m_camera1Url; }
    QString camera2Url() const { return m_camera2Url; }
    QString barrierPort() const { return m_barrierPort; }
    int barrierBaud() const { return m_barrierBaud; }

public slots:
    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    void setCamera1Url(const QString &url);
    void setCamera2Url(const QString &url);
    void setBarrierPort(const QString &port);
    void setBarrierBaud(int baud);

signals:
    void camera1UrlChanged();
    void camera2UrlChanged();
    void barrierPortChanged();
    void barrierBaudChanged();

private:
    QString m_camera1Url;
    QString m_camera2Url;
    QString m_barrierPort;
    int m_barrierBaud = 9600;
};
