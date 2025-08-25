#include "windows_rawinput_router.h"
#include <QDebug>
#include <QCoreApplication>

static QString fromWide(const wchar_t *ws)
{
    return QString::fromWCharArray(ws);
}

WindowsRawInputRouter::WindowsRawInputRouter(QObject *parent)
    : QObject(parent)
{
    if (auto app = QCoreApplication::instance())
        app->installNativeEventFilter(this);
}

WindowsRawInputRouter::~WindowsRawInputRouter()
{
    if (auto app = QCoreApplication::instance())
        app->removeNativeEventFilter(this);
}

bool WindowsRawInputRouter::registerWindow(QWindow *win)
{
    if (!win)
        return false;
    HWND hwnd = reinterpret_cast<HWND>(win->winId());
    return ensureRegisteredFor(hwnd);
}

QList<WindowsRawInputRouter::DeviceInfo> WindowsRawInputRouter::enumerateKeyboards()
{
    QList<DeviceInfo> list;
    UINT num = 0;
    if (GetRawInputDeviceList(nullptr, &num, sizeof(RAWINPUTDEVICELIST)) != 0)
        return list;
    QVector<RAWINPUTDEVICELIST> devs(num);
    if (GetRawInputDeviceList(devs.data(), &num, sizeof(RAWINPUTDEVICELIST)) == UINT(-1))
        return list;
    for (UINT i = 0; i < num; ++i)
    {
        if (devs[i].dwType != RIM_TYPEKEYBOARD)
            continue;
        HANDLE h = devs[i].hDevice;
        DeviceInfo info;
        info.handle = h;
        info.devicePath = devicePathForHandle(h);
        if (!info.devicePath.isEmpty())
            list.push_back(info);
    }
    return list;
}

QStringList WindowsRawInputRouter::keyboardDevicePaths() const
{
    QStringList out;
    UINT num = 0;
    if (GetRawInputDeviceList(nullptr, &num, sizeof(RAWINPUTDEVICELIST)) != 0)
        return out;
    QVector<RAWINPUTDEVICELIST> devs(num);
    if (GetRawInputDeviceList(devs.data(), &num, sizeof(RAWINPUTDEVICELIST)) == UINT(-1))
        return out;
    for (UINT i = 0; i < num; ++i)
    {
        if (devs[i].dwType != RIM_TYPEKEYBOARD)
            continue;
        HANDLE h = devs[i].hDevice;
        UINT size = 0;
        GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, nullptr, &size);
        if (size == 0)
            continue;
        std::wstring buf;
        buf.resize(size);
        if (GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, buf.data(), &size) == UINT(-1))
            continue;
        out << QString::fromWCharArray(buf.c_str());
    }
    return out;
}

QString WindowsRawInputRouter::devicePathForHandle(HANDLE h)
{
    if (m_handleToPath.contains(h))
        return m_handleToPath.value(h);
    UINT size = 0;
    GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, nullptr, &size);
    if (size == 0)
        return {};
    std::wstring buf;
    buf.resize(size);
    if (GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, buf.data(), &size) == UINT(-1))
        return {};
    QString path = QString::fromWCharArray(buf.c_str());
    m_handleToPath.insert(h, path);
    return path;
}

bool WindowsRawInputRouter::ensureRegisteredFor(HWND hwnd)
{
    if (m_registered.contains(hwnd))
        return true;
    RAWINPUTDEVICE rid;
    rid.usUsagePage = 0x01;        // Generic Desktop Controls
    rid.usUsage = 0x06;            // Keyboard
    rid.dwFlags = RIDEV_INPUTSINK; // receive even when not focused
    rid.hwndTarget = hwnd;
    if (!RegisterRawInputDevices(&rid, 1, sizeof(rid)))
        return false;
    m_registered.insert(hwnd);
    return true;
}

bool WindowsRawInputRouter::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result)
{
    Q_UNUSED(result)
    if (eventType != "windows_generic_MSG")
        return false;
    MSG *msg = static_cast<MSG *>(message);
    if (msg->message != WM_INPUT)
        return false;
    HRAWINPUT hRaw = reinterpret_cast<HRAWINPUT>(msg->lParam);
    UINT size = 0;
    GetRawInputData(hRaw, RID_INPUT, nullptr, &size, sizeof(RAWINPUTHEADER));
    if (size == 0)
        return false;
    QByteArray data;
    data.resize(int(size));
    if (GetRawInputData(hRaw, RID_INPUT, data.data(), &size, sizeof(RAWINPUTHEADER)) == UINT(-1))
        return false;
    RAWINPUT *ri = reinterpret_cast<RAWINPUT *>(data.data());
    if (ri->header.dwType != RIM_TYPEKEYBOARD)
        return false;
    const RAWKEYBOARD &kb = ri->data.keyboard;
    const bool isBreak = (kb.Flags & RI_KEY_BREAK) == RI_KEY_BREAK;
    const quint32 vkey = kb.VKey;
    const QString path = devicePathForHandle(ri->header.hDevice);
    if (!path.isEmpty())
        emit rawKey(path, vkey, !isBreak);
    return false; // let Qt handle as well
}
