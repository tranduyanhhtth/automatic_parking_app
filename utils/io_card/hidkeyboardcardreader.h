#pragma once
#include "domain/ports/icardreader.h"
#include <QElapsedTimer>

// Đầu đọc ở chế độ HID Keyboard: gom phím đến khi gặp Enter, phát rfidScanned
class HidKeyboardCardReader : public ICardReader
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int minLength READ minLength WRITE setMinLength NOTIFY minLengthChanged)
    Q_PROPERTY(int debounceMs READ debounceMs WRITE setDebounceMs NOTIFY debounceMsChanged)
public:
    explicit HidKeyboardCardReader(QObject *parent = nullptr);
    ~HidKeyboardCardReader() override;

    Q_INVOKABLE void resetDebounce();

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool en);

    int minLength() const { return m_minLength; }
    void setMinLength(int v)
    {
        if (m_minLength != v)
        {
            m_minLength = v;
            emit minLengthChanged();
        }
    }

    int debounceMs() const { return m_debounceMs; }
    void setDebounceMs(int v)
    {
        if (m_debounceMs != v)
        {
            m_debounceMs = v;
            emit debounceMsChanged();
        }
    }

signals:
    void enabledChanged();
    void minLengthChanged();
    void debounceMsChanged();
    void debugLog(const QString &msg);

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private:
    void processKey(int key, const QString &text);
    void finalize();

    QString m_buffer;
    bool m_enabled = true;
    int m_minLength = 4;
    int m_debounceMs = 800;
    qint64 m_lastEmitMs = 0;
    QString m_lastValue;
};
