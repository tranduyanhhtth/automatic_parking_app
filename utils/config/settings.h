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
    Q_PROPERTY(QString ocrSpaceApiKey READ ocrSpaceApiKey WRITE setOcrSpaceApiKey NOTIFY ocrSpaceApiKeyChanged)
    Q_PROPERTY(bool useHardwareDecode READ useHardwareDecode WRITE setUseHardwareDecode NOTIFY useHardwareDecodeChanged)
public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString camera1Url() const { return m_camera1Url; }
    QString camera2Url() const { return m_camera2Url; }
    QString barrierPort() const { return m_barrierPort; }
    int barrierBaud() const { return m_barrierBaud; }
    QString ocrSpaceApiKey() const { return m_ocrApiKey; }
    bool useHardwareDecode() const { return m_useHwDecode; }

public slots:
    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    void setCamera1Url(const QString &url);
    void setCamera2Url(const QString &url);
    void setBarrierPort(const QString &port);
    void setBarrierBaud(int baud);
    void setOcrSpaceApiKey(const QString &k);
    void setUseHardwareDecode(bool v);

signals:
    void camera1UrlChanged();
    void camera2UrlChanged();
    void barrierPortChanged();
    void barrierBaudChanged();
    void ocrSpaceApiKeyChanged();
    void useHardwareDecodeChanged();

private:
    QString m_camera1Url;
    QString m_camera2Url;
    QString m_barrierPort;
    int m_barrierBaud = 9600;
    QString m_ocrApiKey;
    bool m_useHwDecode = true;
};
