#include "security/authmanager.h"

#include <QCryptographicHash>
#include <QRegularExpression>

namespace
{
constexpr auto kUsernameEnvironmentVariable = "SMART_PARKING_ADMIN_USERNAME";
constexpr auto kPasswordHashEnvironmentVariable = "SMART_PARKING_ADMIN_PASSWORD_SHA256";
}

AuthManager::AuthManager(QObject *parent)
    : QObject(parent),
      m_username(qEnvironmentVariable(kUsernameEnvironmentVariable, QStringLiteral("admin"))),
      m_passwordHash(qEnvironmentVariable(kPasswordHashEnvironmentVariable).trimmed().toLatin1().toLower())
{
}

bool AuthManager::isConfigured() const
{
    static const QRegularExpression sha256Pattern(QStringLiteral("^[0-9a-f]{64}$"));
    return !m_username.isEmpty()
        && sha256Pattern.match(QString::fromLatin1(m_passwordHash)).hasMatch();
}

bool AuthManager::authenticate(const QString &username, const QString &password) const
{
    if (!isConfigured() || username != m_username)
        return false;

    const QByteArray candidateHash =
        QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256).toHex();
    return candidateHash == m_passwordHash;
}
