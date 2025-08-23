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
#include <QSettings>
#include <QLibrary>
#include <QFileInfo>
#include <QFile>
#include "utils/ocr/tesseract_ocr.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <tlhelp32.h>
static QStringList listLoadedModulesMatching(const QStringList &patterns)
{
    QStringList result;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, GetCurrentProcessId());
    if (snap == INVALID_HANDLE_VALUE)
        return result;
    MODULEENTRY32 me;
    me.dwSize = sizeof(me);
    if (Module32First(snap, &me))
    {
        do
        {
            QString modName = QString::fromWCharArray(me.szModule);
            QString modPath = QString::fromWCharArray(me.szExePath);
            for (const QString &p : patterns)
            {
                if (modName.contains(p, Qt::CaseInsensitive))
                {
                    result << (modName + QStringLiteral(" => ") + modPath);
                    break;
                }
            }
        } while (Module32Next(snap, &me));
    }
    CloseHandle(snap);
    return result;
}
#endif

OCRProcessor::OCRProcessor(IParkingRepository *repo, QObject *parent)
    : QObject(parent)
{
    m_repo = repo;
    const QString modelPath = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("license_plate_detector.onnx"));
    m_detector = new YoloOnnxDetectorImpl(modelPath, this);
    m_detectorReady = m_detector && m_detector->isReady();
    qInfo() << "OCR: model path resolved to" << modelPath
            << ", detector ready =" << m_detectorReady;

    // Optional: initialize local Tesseract if enabled in settings
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    const bool enableTess = s.value("tesseract/enable", false).toBool();
    if (enableTess)
    {
#ifdef Q_OS_WIN
        // Ensure DLLs are discoverable on Windows
        const QString appDir = QCoreApplication::applicationDirPath();
        const QString vendorBin = QStringLiteral("d:/smart_parking_system/lib/tesseract/bin");
        const QString vendorBinDebug = QStringLiteral("d:/smart_parking_system/lib/tesseract/debug/bin");
        const QString pathNow = qEnvironmentVariable("PATH");
        QStringList prepend;
        if (!appDir.isEmpty())
            prepend << appDir;
#ifdef QT_DEBUG
        if (QDir(vendorBinDebug).exists())
            prepend << vendorBinDebug; // Prefer debug/bin in Debug builds
#else
        if (QDir(vendorBin).exists())
            prepend << vendorBin; // Use release bin in Release builds
#endif
        if (!prepend.isEmpty())
        {
            const QString newPath = prepend.join(';') + QLatin1Char(';') + pathNow;
            qputenv("PATH", newPath.toUtf8());
        }
#endif // Q_OS_WIN

        // Initialize Tesseract
        const QString tessParent = s.value("tesseract/tessdataParent", QStringLiteral("d:/smart_parking_system/lib/tesseract")).toString();
        const QString tessLang = s.value("tesseract/lang", QStringLiteral("eng")).toString();
        if (!tessParent.isEmpty())
            qputenv("TESSDATA_PREFIX", QFile::encodeName(tessParent));

        m_tess = new TesseractOcr(this);
        bool ok = m_tess->init(tessParent, tessLang);
        if (!ok && tessLang != QStringLiteral("eng"))
        {
            ok = m_tess->init(tessParent, QStringLiteral("eng"));
        }
        if (!ok)
        {
            qWarning() << "OCR backend [tesseract]: NOT READY (init failed)";
            m_tess->deleteLater();
            m_tess = nullptr;
        }
        else
        {
            qInfo() << "Tesseract initialized.";
        }
    }

    // Try auto-init from common locations if still not ready
    tryAutoInitTesseract();
    qInfo() << "OCR backend [tesseract] ready =" << (m_tess && m_tess->isReady());
}

QVariantMap OCRProcessor::recognizePlates(const QByteArray &frontImage,
                                          const QByteArray &rearImage)
{
    QVariantMap result;
    result.insert("front", QString());
    result.insert("rear", QString());
    result.insert("backend", QString());
    result.insert("detectorReady", m_detectorReady);
    result.insert("frontBoxCount", 0);
    result.insert("rearBoxCount", 0);

    const bool canTess = (m_tess && m_tess->isReady());
    const QString usedBackend = canTess ? QStringLiteral("tesseract") : QStringLiteral("none");
    result.insert("backend", usedBackend);

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
        result.insert("frontBoxCount", fBoxes.size());
        result.insert("rearBoxCount", rBoxes.size());
        qInfo() << "OCR: detector ready; frontBoxes=" << fBoxes.size() << "rearBoxes=" << rBoxes.size() << ", backend=" << usedBackend;
        QVariantList fsc, rsc;
        for (float s : fScores)
            fsc.push_back(s);
        for (float s : rScores)
            rsc.push_back(s);
        result.insert("frontScores", fsc);
        result.insert("rearScores", rsc);
        // Chọn hộp lớn nhất để nhận diện biển số
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

        if (canTess)
        {
            int fi = pickLargest(fBoxes);
            if (fi >= 0)
            {
                QByteArray cj = cropJpeg(frontImage, fBoxes[fi]);
                QString txt = tesseractRecognize(cj);
                if (!txt.trimmed().isEmpty())
                {
                    qInfo() << "OCR: front plate=" << txt.trimmed();
                    result.insert("front", txt.trimmed());
                }
            }
            int ri = pickLargest(rBoxes);
            if (ri >= 0)
            {
                QByteArray cj = cropJpeg(rearImage, rBoxes[ri]);
                QString txt = tesseractRecognize(cj);
                if (!txt.trimmed().isEmpty())
                {
                    qInfo() << "OCR: rear plate=" << txt.trimmed();
                    result.insert("rear", txt.trimmed());
                }
            }
        }
    }
    else
    {
        qWarning() << "OCR: detector not ready; skipping detection and trying direct OCR";
    }

    // Fallback: if no plate text found yet, try OCR on whole images
    if ((result.value("front").toString().isEmpty() || result.value("rear").toString().isEmpty()) && canTess)
    {
        if (result.value("front").toString().isEmpty() && !frontImage.isEmpty())
        {
            QString txt = tesseractRecognize(frontImage);
            if (!txt.trimmed().isEmpty())
            {
                qInfo() << "OCR: fallback whole front image =>" << txt.trimmed();
                result.insert("front", txt.trimmed());
            }
        }
        if (result.value("rear").toString().isEmpty() && !rearImage.isEmpty())
        {
            QString txt = tesseractRecognize(rearImage);
            if (!txt.trimmed().isEmpty())
            {
                qInfo() << "OCR: fallback whole rear image =>" << txt.trimmed();
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

QString OCRProcessor::tesseractRecognize(const QByteArray &jpegBytes) const
{
    if (!m_tess || !m_tess->isReady())
        return {};
    return m_tess->recognize(jpegBytes);
}

void OCRProcessor::tryAutoInitTesseract()
{
#ifdef HAVE_TESSERACT
    if (m_tess && m_tess->isReady())
        return;
    // Chỉ thử các đường dẫn vendor-relative
    const QString appDir = QCoreApplication::applicationDirPath();
    // Nếu chạy từ build dir, vendor ở d:/smart_parking_system/lib/tesseract
    const QString vendorAbs = QStringLiteral("d:/smart_parking_system/lib/tesseract");
    const QStringList candidates = {vendorAbs, QDir(appDir).absolutePath()};
    for (const QString &parent : candidates)
    {
        if (!QDir(parent).exists())
            continue;
        TesseractOcr *t = new TesseractOcr(this);
        if (t->init(parent, QStringLiteral("eng")))
        {
            m_tess = t;
            qInfo() << "Tesseract auto-initialized at" << parent;
            return;
        }
        t->deleteLater();
    }
#endif
}
