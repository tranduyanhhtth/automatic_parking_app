#pragma once

#if defined(_WIN32) || defined(WIN32)

#include <QObject>
#include <QHash>
#include <QByteArray>
#include <QVector>
#include <QWindow>
#include <QPointer>
#include <QAbstractNativeEventFilter>
#include <QSet>
#include <windows.h>

class WindowsRawInputRouter : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
public:
    struct DeviceInfo
    {
        HANDLE handle{nullptr};
        QString devicePath; // e.g. "\\\\?\\HID#VID_XXXX&PID_YYYY..."
    };

    explicit WindowsRawInputRouter(QObject *parent = nullptr);
    ~WindowsRawInputRouter() override;

    // Register a window to receive WM_INPUT even when unfocused (RIDEV_INPUTSINK)
    bool registerWindow(QWindow *win);

    // Enumerate currently known keyboard devices (RIM_TYPEKEYBOARD)
    QList<DeviceInfo> enumerateKeyboards();

    // QAbstractNativeEventFilter
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

signals:
    void rawKey(const QString &devicePath, quint32 vkey, bool isDown);

private:
    QString devicePathForHandle(HANDLE h);
    bool ensureRegisteredFor(HWND hwnd);

    QHash<HANDLE, QString> m_handleToPath;
    QSet<HWND> m_registered;
};

#endif // _WIN32 || WIN32
