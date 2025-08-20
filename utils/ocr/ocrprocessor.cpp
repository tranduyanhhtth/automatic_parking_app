#include "ocrprocessor.h"
#include "domain/ports/iparkingrepository.h"
#include "utils/ocr/yolo_onnx_detector.h"
#include <QImage>
#include <QBuffer>
#include <QDebug>
#include <QVariant>
#include <QVariantMap>
#include <QVariantList>
#include <QRectF>
#include <QVector>
#include <QCoreApplication>
#include <QDir>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>

OCRProcessor::OCRProcessor(IParkingRepository *repo, QObject *parent)
    : QObject(parent)
{
    m_repo = repo;
    const QString modelPath = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("license_plate_detector.onnx"));
    m_detector = new YoloOnnxDetectorImpl(modelPath, this);
    m_detectorReady = m_detector && m_detector->isReady();
    qInfo() << "OCR: model path resolved to" << modelPath
            << ", detector ready =" << m_detectorReady;
}

QVariantMap OCRProcessor::recognizePlates(const QByteArray &frontImage,
                                          const QByteArray &rearImage)
{
    QVariantMap result;
    result.insert("front", QString());
    result.insert("rear", QString());

    if (m_detectorReady && m_detector)
    {
        auto mkBoxes = [](const QVector<QRectF> &boxes)
        {
            QVariantList out;
            out.reserve(boxes.size());
            for (const auto &rc : boxes)
            {
                QVariantMap m;
                m.insert("x", rc.x());
                m.insert("y", rc.y());
                m.insert("w", rc.width());
                m.insert("h", rc.height());
                out.push_back(m);
            }
            return out;
        };

        QVector<QRectF> fBoxes, rBoxes;
        QVector<float> fScores, rScores;
        m_detector->detectJpeg(frontImage, fBoxes, fScores);
        m_detector->detectJpeg(rearImage, rBoxes, rScores);

        result.insert("frontBoxes", mkBoxes(fBoxes));
        result.insert("rearBoxes", mkBoxes(rBoxes));
        QVariantList fsc, rsc;
        for (float s : fScores)
            fsc.push_back(s);
        for (float s : rScores)
            rsc.push_back(s);
        result.insert("frontScores", fsc);
        result.insert("rearScores", rsc);
        // Gắn OCR.Space vào các hộp lớn nhất để nhận diện biển số
        auto pickLargest = [](const QVector<QRectF> &boxes) -> int
        {
            if (boxes.isEmpty())
                return -1;
            qreal bestA = -1;
            int best = -1;
            for (int i = 0; i < boxes.size(); ++i)
            {
                qreal a = boxes[i].width() * boxes[i].height();
                if (a > bestA)
                {
                    bestA = a;
                    best = i;
                }
            }
            return best;
        };

        auto cropJpeg = [](const QByteArray &jpeg, const QRectF &rect) -> QByteArray
        {
            if (jpeg.isEmpty() || rect.isEmpty())
                return {};
            QImage img;
            img.loadFromData(jpeg, "JPG");
            if (img.isNull())
                return {};
            QRect r = rect.toAlignedRect().intersected(img.rect());
            if (r.isEmpty())
                return {};
            QImage cropped = img.copy(r);
            QByteArray out;
            QBuffer buf(&out);
            buf.open(QIODevice::WriteOnly);
            cropped.save(&buf, "JPG", 92);
            return out;
        };

        const QString apiKey = ocrSpaceApiKeyFromSettings();
        if (!apiKey.isEmpty())
        {
            int fi = pickLargest(fBoxes);
            if (fi >= 0)
            {
                QByteArray cj = cropJpeg(frontImage, fBoxes[fi]);
                QString txt = ocrSpaceRecognize(cj);
                if (!txt.trimmed().isEmpty())
                    result.insert("front", txt.trimmed());
            }
            int ri = pickLargest(rBoxes);
            if (ri >= 0)
            {
                QByteArray cj = cropJpeg(rearImage, rBoxes[ri]);
                QString txt = ocrSpaceRecognize(cj);
                if (!txt.trimmed().isEmpty())
                    result.insert("rear", txt.trimmed());
            }
        }
    }

    return result;
}

QString OCRProcessor::processOpenSessionAndUpdatePlate(const QString &rfid)
{
    IParkingRepository *db = m_repo;
    if (!db)
    {
        qWarning() << "OCRProcessor: cannot locate DB repository instance";
        return QString();
    }

    QVariantMap m = db->fetchFullOpenSession(rfid);
    if (m.isEmpty())
        return QString();

    QByteArray img1 = m.value("image1").toByteArray();
    QByteArray img2 = m.value("image2").toByteArray();

    // Thử cho cả hai ảnh
    QString plate;
    QVariantMap tmp = recognizePlates(img1, img2);
    QString f = tmp.value("front").toString();
    QString r = tmp.value("rear").toString();
    if (!f.trimmed().isEmpty())
        plate = f.trimmed();
    else if (!r.trimmed().isEmpty())
        plate = r.trimmed();
    if (plate.isEmpty())
        plate = QStringLiteral("unknown");

    if (!db->updatePlateForOpenSession(rfid, plate))
        return QString();
    return plate;
}

QString OCRProcessor::ocrSpaceApiKeyFromSettings() const
{
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    return s.value("ocrSpaceApiKey").toString();
}

QString OCRProcessor::ocrSpaceRecognize(const QByteArray &jpegBytes, int timeoutMs) const
{
    if (jpegBytes.isEmpty())
        return {};
    const QString apiKey = ocrSpaceApiKeyFromSettings();
    if (apiKey.isEmpty())
        return {};

    QNetworkAccessManager nam;
    QHttpMultiPart *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    QHttpPart keyPart;
    keyPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=apikey"));
    keyPart.setBody(apiKey.toUtf8());
    QHttpPart languagePart;
    languagePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=language"));
    languagePart.setBody("eng");
    QHttpPart isOverlayPart;
    isOverlayPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=isOverlayRequired"));
    isOverlayPart.setBody("false");
    QHttpPart scalePart;
    scalePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=scale"));
    scalePart.setBody("true");
    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=image"));
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    filePart.setBody(jpegBytes);

    multi->append(keyPart);
    multi->append(languagePart);
    multi->append(isOverlayPart);
    multi->append(scalePart);
    multi->append(filePart);

    QNetworkRequest req(QUrl("https://api.ocr.space/parse/image"));
    auto reply = nam.post(req, multi);
    multi->setParent(reply);

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();
    if (timer.isActive() == false)
    {
        reply->abort();
        reply->deleteLater();
        return {};
    }
    if (reply->error() != QNetworkReply::NoError)
    {
        reply->deleteLater();
        return {};
    }
    const QByteArray resp = reply->readAll();
    reply->deleteLater();

    QJsonParseError jerr{};
    const QJsonDocument doc = QJsonDocument::fromJson(resp, &jerr);
    if (jerr.error != QJsonParseError::NoError || !doc.isObject())
        return {};
    const QJsonObject root = doc.object();
    const QJsonArray parsed = root.value("ParsedResults").toArray();
    if (parsed.isEmpty())
        return {};
    const QJsonObject first = parsed.first().toObject();
    const QString text = first.value("ParsedText").toString();
    return text;
}
