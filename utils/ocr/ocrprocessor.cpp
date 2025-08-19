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

    // TẠM THỜI: chưa có OCR ký tự => KHÔNG sinh placeholder; chỉ lưu 'unknown' nếu không có text
    QString plate; // remain empty if no char OCR
    if (plate.isEmpty())
        plate = QStringLiteral("unknown");

    if (!db->updatePlateForOpenSession(rfid, plate))
        return QString();
    return plate;
}
