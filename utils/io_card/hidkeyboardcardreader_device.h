#pragma once
#include "domain/ports/icardreader.h"
#include <QObject>
#include <QString>

class WindowsRawInputRouter;

// Windows-only: Listen to a specific keyboard-like HID device (by devicePath) and assemble RFID scans.
class HidKeyboardCardReaderDevice : public ICardReader
{
    Q_OBJECT
    Q_PROPERTY(QString devicePath READ devicePath WRITE setDevicePath NOTIFY devicePathChanged)
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int minLength READ minLength WRITE setMinLength NOTIFY minLengthChanged)
    Q_PROPERTY(int interKeyMsMax READ interKeyMsMax WRITE setInterKeyMsMax NOTIFY interKeyMsMaxChanged)
    Q_PROPERTY(QString allowedPrefix READ allowedPrefix WRITE setAllowedPrefix NOTIFY allowedPrefixChanged)
public:
    explicit HidKeyboardCardReaderDevice(WindowsRawInputRouter *router, QObject *parent = nullptr);

    QString devicePath() const { return m_devicePath; }
    void setDevicePath(const QString &p);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool en);

    int minLength() const { return m_minLength; }
    void setMinLength(int len);
    int interKeyMsMax() const { return m_interKeyMsMax; }
    void setInterKeyMsMax(int v);
    QString allowedPrefix() const { return m_allowedPrefix; }
    void setAllowedPrefix(const QString &p);

    Q_INVOKABLE void resetBuffer();
    Q_INVOKABLE void resetDebounce() { resetBuffer(); }

signals:
    void devicePathChanged();
    void enabledChanged();
    void minLengthChanged();
    void interKeyMsMaxChanged();
    void allowedPrefixChanged();
    void debugLog(const QString &msg);

private:
    void onRawKey(const QString &path, quint32 vkey, bool down);
    void finalize();

    WindowsRawInputRouter *m_router{nullptr};
    QString m_devicePath;
    QString m_buffer;
    bool m_enabled{true};
    int m_minLength{4};
    int m_interKeyMsMax{30}; // keys slower than this reset buffer (treat as human typing)
    QString m_allowedPrefix; // optional required prefix (e.g., ";" or start digits)
    qint64 m_lastTs{0};
};
