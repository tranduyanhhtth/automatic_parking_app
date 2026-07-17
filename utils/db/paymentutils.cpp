#include "utils/db/paymentutils.h"

namespace PaymentUtils
{
QString normalizePaymentType(const QString &paymentMethod)
{
    const QString value = paymentMethod.trimmed().toLower();

    if (value == QLatin1String("cash") || value.contains(QStringLiteral("tiền mặt")))
        return QStringLiteral("cash");
    if (value == QLatin1String("card") || value.contains(QStringLiteral("thẻ")))
        return QStringLiteral("card");
    if (value == QLatin1String("transfer") || value.contains(QStringLiteral("chuyển khoản"))
        || value.contains(QLatin1String("bank")))
        return QStringLiteral("transfer");
    if (value == QLatin1String("prepaid"))
        return QStringLiteral("prepaid");
    if (value == QLatin1String("postpaid"))
        return QStringLiteral("postpaid");

    return {};
}
}
