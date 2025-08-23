#pragma once
#include <QObject>
#include <QSerialPort>
#include <QString>
#include <QTimer>
#include <QByteArray>
#include "domain/ports/ibarrier.h"

// USB Relay barrier controller sử dụng cổng COM ảo
// ON command: A0 01 01 A2
// OFF command: A0 01 00 A1
class UsbRelayBarrier : public QObject, public IBarrier
{
    Q_OBJECT
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
public:
    explicit UsbRelayBarrier(QObject *parent = nullptr);
    ~UsbRelayBarrier() override;

    QString portName() const { return m_port.portName(); }
    void setPortName(const QString &name);
    bool isConnected() const { return m_port.isOpen(); }
    QString lastError() const { return m_lastError; }
    int baudRate() const { return m_port.baudRate(); }

public slots:
    Q_INVOKABLE void open() override;
    Q_INVOKABLE void close() override;
    // Generate a momentary pulse: turn relay ON, then OFF after ms milliseconds (default 300ms)
    Q_INVOKABLE void pulse(int ms = 300);
    Q_INVOKABLE bool connectPort();
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE void setBaudRate(int baud);

signals:
    void portNameChanged();
    void connectedChanged();
    void lastErrorChanged();
    void barrierOpened();
    void barrierClosed();
    void baudRateChanged();

private:
    bool sendCommand(const QByteArray &bytes);
    void setError(const QString &err);

    QSerialPort m_port;
    QString m_lastError;
};
