#include "hidkeyboardcardreader_device.h"
#include "windows_rawinput_router.h"
#include <QChar>

HidKeyboardCardReaderDevice::HidKeyboardCardReaderDevice(WindowsRawInputRouter *router, QObject *parent)
    : ICardReader(parent), m_router(router)
{
#ifdef _WIN32
    if (m_router)
    {
        QObject::connect(m_router, &WindowsRawInputRouter::rawKey, this, &HidKeyboardCardReaderDevice::onRawKey);
    }
#endif
}

// Rely on AUTOMOC; no manual moc include

void HidKeyboardCardReaderDevice::setDevicePath(const QString &p)
{
    if (m_devicePath == p)
        return;
    m_devicePath = p;
    emit devicePathChanged();
}

void HidKeyboardCardReaderDevice::setEnabled(bool en)
{
    if (m_enabled == en)
        return;
    m_enabled = en;
    emit enabledChanged();
}

void HidKeyboardCardReaderDevice::setMinLength(int len)
{
    if (m_minLength == len)
        return;
    m_minLength = len;
    emit minLengthChanged();
}

void HidKeyboardCardReaderDevice::resetBuffer()
{
    m_buffer.clear();
}

void HidKeyboardCardReaderDevice::onRawKey(const QString &path, quint32 vkey, bool down)
{
    if (!m_enabled)
        return;
    if (path != m_devicePath)
        return; // Only listen to bound device
    if (!down)
        return; // only on key down

    if (vkey == VK_RETURN)
    {
        finalize();
        return;
    }
    // Allow 0-9 and A-Z via virtual-key to ASCII simplistic mapping
    if (vkey >= '0' && vkey <= '9')
        m_buffer.append(QChar(ushort(vkey)));
    else if (vkey >= 'A' && vkey <= 'Z')
        m_buffer.append(QChar(ushort(vkey)));
    // Other keys ignored
}

void HidKeyboardCardReaderDevice::finalize()
{
    const QString s = m_buffer.trimmed();
    if (s.size() >= m_minLength)
    {
        emit debugLog(QStringLiteral("[HID Raw] %1").arg(s));
        emit rfidScanned(s);
    }
    m_buffer.clear();
}
