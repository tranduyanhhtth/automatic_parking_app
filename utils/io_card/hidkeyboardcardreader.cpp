#include "hidkeyboardcardreader.h"
#include <QEvent>
#include <QKeyEvent>
#include <QDateTime>

HidKeyboardCardReader::HidKeyboardCardReader(QObject *parent) : ICardReader(parent) {}
HidKeyboardCardReader::~HidKeyboardCardReader() = default;

void HidKeyboardCardReader::setEnabled(bool en)
{
    if (m_enabled == en)
        return;
    m_enabled = en;
    emit enabledChanged();
}

void HidKeyboardCardReader::resetDebounce()
{
    m_lastEmitMs = 0;
    m_lastValue.clear();
}

bool HidKeyboardCardReader::eventFilter(QObject *obj, QEvent *event)
{
    if (!m_enabled)
        return ICardReader::eventFilter(obj, event);
    if (event->type() == QEvent::KeyPress)
    {
        auto *ke = static_cast<QKeyEvent *>(event);
        processKey(ke->key(), ke->text());
    }
    return ICardReader::eventFilter(obj, event);
}

void HidKeyboardCardReader::processKey(int key, const QString &text)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    // Nếu khoảng cách giữa 2 phím quá dài > 2s thì reset buffer
    if (m_lastEmitMs > 0 && (now - m_lastEmitMs) > 2000 && m_buffer.size() > 0)
    {
        m_buffer.clear();
        emit debugLog(QStringLiteral("[HID] Buffer timeout reset"));
    }
    if (key == Qt::Key_Return || key == Qt::Key_Enter)
    {
        finalize();
        return;
    }
    if (!text.isEmpty())
    {
        // CR10E gửi ký tự ASCII số/ chữ in HOA
        // Lọc bỏ ký tự điều khiển
        for (QChar c : text)
        {
            if (c.isPrint())
                m_buffer.append(c);
        }
        emit debugLog(QStringLiteral("[HID] Key '%1' buffer='%2'").arg(text, m_buffer));
    }
}

void HidKeyboardCardReader::finalize()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (m_buffer.size() >= m_minLength)
    {
        const QString current = m_buffer.trimmed();
        const bool sameAsLast = (current == m_lastValue);
        if (!sameAsLast || (now - m_lastEmitMs) >= m_debounceMs)
        {
            emit debugLog(QStringLiteral("[HID] RFID complete '%1'").arg(current));
            emit rfidScanned(current);
            m_lastEmitMs = now;
            m_lastValue = current;
        }
        else
        {
            emit debugLog(QStringLiteral("[HID] Debounced duplicate ignored '%1' (%2ms < %3ms)")
                              .arg(current)
                              .arg(now - m_lastEmitMs)
                              .arg(m_debounceMs));
        }
    }
    m_buffer.clear();
}
