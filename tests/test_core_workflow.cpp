#include <QtTest>

#include <QCryptographicHash>
#include <QSignalSpy>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QVideoSink>

#include "controller/parkingcontroller.h"
#include "security/authmanager.h"
#include "utils/db/databasemanager.h"
#include "utils/db/paymentutils.h"

class FakeCamera final : public ICameraSnapshotProvider
{
public:
    void setInputVideoSink(QVideoSink *) override {}
    void setOutputVideoSink(QVideoSink *) override {}
    QByteArray captureInputSnapshot(int) override { return QByteArrayLiteral("front-image"); }
    QByteArray captureOutputSnapshot(int) override { return QByteArrayLiteral("rear-image"); }
    void clearSnapshots() override {}
};

class FakeBarrier final : public IBarrier
{
public:
    void open() override { ++openCount; }
    void close() override { ++closeCount; }

    int openCount = 0;
    int closeCount = 0;
};

class FakeCardReader final : public ICardReader
{
    Q_OBJECT
public:
    using ICardReader::ICardReader;
    void scan(const QString &rfid) { emit rfidScanned(rfid); }
};

class CoreWorkflowTest final : public QObject
{
    Q_OBJECT

private slots:
    void authFailsClosedWithoutConfiguration();
    void authAcceptsConfiguredPasswordHash();
    void paymentMethodsAreNormalized();
    void checkoutPreservesDisplayDataAndOpensBarrier();
};

void CoreWorkflowTest::authFailsClosedWithoutConfiguration()
{
    qunsetenv("SMART_PARKING_ADMIN_PASSWORD_SHA256");
    AuthManager auth;
    QVERIFY(!auth.isConfigured());
    QVERIFY(!auth.authenticate(QStringLiteral("admin"), QStringLiteral("123")));
}

void CoreWorkflowTest::authAcceptsConfiguredPasswordHash()
{
    const QByteArray password = QByteArrayLiteral("correct horse battery staple");
    const QByteArray hash = QCryptographicHash::hash(password, QCryptographicHash::Sha256).toHex();
    qputenv("SMART_PARKING_ADMIN_USERNAME", QByteArrayLiteral("operator"));
    qputenv("SMART_PARKING_ADMIN_PASSWORD_SHA256", hash);

    AuthManager auth;
    QVERIFY(auth.isConfigured());
    QVERIFY(auth.authenticate(QStringLiteral("operator"), QString::fromUtf8(password)));
    QVERIFY(!auth.authenticate(QStringLiteral("operator"), QStringLiteral("wrong")));
    QVERIFY(!auth.authenticate(QStringLiteral("admin"), QString::fromUtf8(password)));
}

void CoreWorkflowTest::paymentMethodsAreNormalized()
{
    QCOMPARE(PaymentUtils::normalizePaymentType(QStringLiteral("Tiền mặt")), QStringLiteral("cash"));
    QCOMPARE(PaymentUtils::normalizePaymentType(QStringLiteral("Chuyển khoản")), QStringLiteral("transfer"));
    QCOMPARE(PaymentUtils::normalizePaymentType(QStringLiteral("card")), QStringLiteral("card"));
    QVERIFY(PaymentUtils::normalizePaymentType(QStringLiteral("unknown method")).isEmpty());
}

void CoreWorkflowTest::checkoutPreservesDisplayDataAndOpensBarrier()
{
    QTemporaryDir temporaryDirectory;
    QVERIFY(temporaryDirectory.isValid());

    DatabaseManager database(temporaryDirectory.filePath(QStringLiteral("parking.db")));
    QVERIFY(database.initialize());
    QVERIFY(database.upsertPricingRow(QStringLiteral("car"), QStringLiteral("hourly"),
                                      10000, 60, 5000, 0, 0.0, 0,
                                      QStringLiteral("test pricing"), QString(), QString()));
    QVERIFY(database.upsertRfidCard(QStringLiteral("RFID000001"), QStringLiteral("car"),
                                    QStringLiteral("hourly"), QStringLiteral("available")) > 0);
    QCOMPARE(static_cast<int>(database.checkIn(QStringLiteral("RFID000001"), QStringLiteral("51A-12345"),
                                               QByteArrayLiteral("checkin-front"), QByteArrayLiteral("checkin-rear"))),
             static_cast<int>(CheckInResult::Ok));

    const QVariantMap openSession = database.fetchFullOpenSession(QStringLiteral("RFID000001"));
    QVERIFY(!openSession.isEmpty());
    const QString checkinTime = openSession.value(QStringLiteral("checkin_time")).toString();
    QVERIFY(!checkinTime.isEmpty());

    FakeCamera entranceCamera;
    FakeCamera exitCamera;
    FakeBarrier entranceBarrier;
    FakeBarrier exitBarrier;
    FakeCardReader entranceReader;
    FakeCardReader exitReader;
    ParkingController controller(&entranceCamera, &exitCamera, &database,
                                 &entranceBarrier, &exitBarrier, nullptr,
                                 &entranceReader, &exitReader);

    QSignalSpy paymentRequired(&controller, &ParkingController::checkoutRequiresPayment);
    exitReader.scan(QStringLiteral("RFID000001"));
    QCOMPARE(paymentRequired.count(), 1);
    const int fee = paymentRequired.first().at(2).toInt();
    QVERIFY(fee > 0);

    controller.completeCheckout(QStringLiteral("RFID000001"), QStringLiteral("51A-12345"),
                                QStringLiteral("Chuyển khoản"), fee);

    QCOMPARE(exitBarrier.openCount, 1);
    QCOMPARE(controller.exitTimeIn(), checkinTime);
    QVERIFY(!controller.exitTimeOut().isEmpty());
    QVERIFY(!database.hasOpenSession(QStringLiteral("RFID000001")));

    const QList<QVariantMap> sessions = database.searchSessions(
        QString(), QStringLiteral("RFID000001"), QString(), QString(),
        QStringLiteral("checked_out"), 10, 0);
    QCOMPARE(sessions.size(), 1);
    QCOMPARE(sessions.first().value(QStringLiteral("payment_check")).toString(),
             QStringLiteral("Chuyển khoản"));

    QSqlQuery revenueQuery;
    QVERIFY(revenueQuery.exec(QStringLiteral("SELECT payment_type FROM revenues ORDER BY id DESC LIMIT 1")));
    QVERIFY(revenueQuery.next());
    QCOMPARE(revenueQuery.value(0).toString(), QStringLiteral("transfer"));

    // Unsupported paid methods must roll the checkout back atomically.
    QVERIFY(database.upsertRfidCard(QStringLiteral("RFID000002"), QStringLiteral("car"),
                                    QStringLiteral("hourly"), QStringLiteral("available")) > 0);
    QCOMPARE(static_cast<int>(database.checkIn(QStringLiteral("RFID000002"), QStringLiteral("51A-54321"), {}, {})),
             static_cast<int>(CheckInResult::Ok));
    QString rejectedCheckoutTime;
    QCOMPARE(static_cast<int>(database.checkOutRfidWithImages(QStringLiteral("RFID000002"), &rejectedCheckoutTime,
                                                              {}, {}, QStringLiteral("unsupported"))),
             static_cast<int>(CheckOutResult::Error));
    QVERIFY(database.hasOpenSession(QStringLiteral("RFID000002")));
    QVERIFY(rejectedCheckoutTime.isEmpty());

    QTRY_COMPARE_WITH_TIMEOUT(exitBarrier.closeCount, 1, 1000);
}

QTEST_MAIN(CoreWorkflowTest)
#include "test_core_workflow.moc"
