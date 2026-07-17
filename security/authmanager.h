#pragma once

#include <QByteArray>
#include <QObject>
#include <QString>

class AuthManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool configured READ isConfigured CONSTANT)

public:
    explicit AuthManager(QObject *parent = nullptr);

    bool isConfigured() const;
    Q_INVOKABLE bool authenticate(const QString &username, const QString &password) const;

private:
    QString m_username;
    QByteArray m_passwordHash;
};
