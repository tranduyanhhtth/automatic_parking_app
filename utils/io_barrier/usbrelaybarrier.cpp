#include "usbrelaybarrier.h"
#include <QSerialPortInfo>
#include <QTimer>

UsbRelayBarrier::UsbRelayBarrier(QObject *parent) : QObject(parent)
{
    m_port.setBaudRate(QSerialPort::Baud9600);
    m_port.setDataBits(QSerialPort::Data8);
    m_port.setParity(QSerialPort::NoParity);
    m_port.setStopBits(QSerialPort::OneStop);
    m_port.setFlowControl(QSerialPort::NoFlowControl);
}

UsbRelayBarrier::~UsbRelayBarrier()
{
    if (m_port.isOpen())
        m_port.close();
}

void UsbRelayBarrier::setPortName(const QString &name)
{
    if (m_port.isOpen())
        m_port.close();
    m_port.setPortName(name);
    emit portNameChanged();
}

bool UsbRelayBarrier::connectPort()
{
    if (m_port.portName().isEmpty())
    {
        setError("Port name is empty");
        return false;
    }
    if (m_port.isOpen())
        return true;
    if (!m_port.open(QIODevice::ReadWrite))
    {
        setError(QStringLiteral("Open port failed: %1").arg(m_port.errorString()));
    }
    emit connectedChanged();
    return true;
}

void UsbRelayBarrier::disconnectPort()
{
    if (m_port.isOpen())
    {
        m_port.close();
        emit connectedChanged();
    }
}

void UsbRelayBarrier::setBaudRate(int baud)
{
    bool wasOpen = m_port.isOpen();
    if (wasOpen)
        m_port.close();
    m_port.setBaudRate(baud);
    emit baudRateChanged();
    if (wasOpen)
        connectPort();
}

bool UsbRelayBarrier::sendCommand(const QByteArray &bytes)
{
    if (!m_port.isOpen())
    {
        if (!connectPort())
            return false;
    }
    qint64 n = m_port.write(bytes);
    if (n != bytes.size())
    {
        setError(QStringLiteral("Write failed: %1").arg(m_port.errorString()));
        return false;
    }
    if (!m_port.waitForBytesWritten(500))
    {
        setError(QStringLiteral("Timeout writing command"));
        return false;
    }
    return true;
}

void UsbRelayBarrier::open()
{
    static const QByteArray onCmd = QByteArray::fromHex("A00101A2");
    if (sendCommand(onCmd))
        emit barrierOpened();
}

void UsbRelayBarrier::close()
{
    static const QByteArray offCmd = QByteArray::fromHex("A00100A1");
    if (sendCommand(offCmd))
        emit barrierClosed();
}

void UsbRelayBarrier::pulse(int ms)
{
    // Ensure port is connected first to avoid delays inside timer
    if (!m_port.isOpen())
        connectPort();
    open();
    // Use singleShot tied to this QObject to guarantee delivery on the right thread
    int delay = (ms < 10) ? 10 : ms;
    QTimer::singleShot(delay, this, [this]
                       { close(); });
}

void UsbRelayBarrier::setError(const QString &err)
{
    if (m_lastError == err)
        return;
    m_lastError = err;
    emit lastErrorChanged();
}
