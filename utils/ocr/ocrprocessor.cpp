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
#include <QFile>
#include <QPainter>
#include "utils/ocr/tesseract_ocr.h"
#include <algorithm>
#include <QPair>
#include <QTransform>
#include <QRegularExpression>

namespace
{
    // Map letters that often get misread as digits in the tail to digits
    static QChar letterToDigitLike(QChar c)
    {
        switch (c.unicode())
        {
        case 'O':
            return '0';
        case 'I':
            return '1';
        case 'L':
            return '1';
        case 'Z':
            return '2';
        case 'S':
            return '5';
        case 'G':
            return '6';
        case 'C':
            return '0'; // or '6', pick '0' as more common visually
        case 'B':
            return '8';
        case 'Q':
            return '0';
        default:
            return c;
        }
    }

    // Map digits that often get misread as the series letter to letters
    static QChar digitToLetterLike(QChar c)
    {
        switch (c.unicode())
        {
        case '0':
            return 'O';
        case '1':
            return 'I';
        case '2':
            return 'Z';
        case '5':
            return 'S';
        case '8':
            return 'B';
        case '6':
            return 'G';
        default:
            return c;
        }
    }

    // Normalize Vietnamese license plate into canonical form: "XXY-12345" or "XX-12345"
    // Returns empty string if cannot validate.
    static QString normalizePlateVN(const QString &raw)
    {
        if (raw.trimmed().isEmpty())
            return {};
        QString s = raw.toUpper();
        s.replace(QChar(0x2013), '-').replace(QChar(0x2014), '-'); // en/em dash to '-'
        s.remove(' ');
        // Remove all chars except A-Z, 0-9, '-', '.'
        QString filtered;
        filtered.reserve(s.size());
        for (QChar ch : s)
        {
            if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '.')
                filtered.append(ch);
        }
        // Try pattern with letter series first: XXY-ZZZZZ (dots optional inside Z)
        QRegularExpression reWithLetter("^([0-9A-Z]{2})([A-Z0-9])[-]?([0-9A-Z\\.]{3,6})$");
        QRegularExpressionMatch m = reWithLetter.match(filtered);
        bool hasLetter = m.hasMatch();
        QString prov, series, tail;
        if (hasLetter)
        {
            prov = m.captured(1);
            series = m.captured(2);
            tail = m.captured(3);
            // Province: force digits (correct confusables)
            for (QChar &c : prov)
                c = letterToDigitLike(c);
            // Nếu XX có chữ, thử loại bỏ hoặc sửa bằng mapping, nếu vẫn không hợp lệ thì loại
            if (!prov[0].isDigit())
                prov[0] = letterToDigitLike(prov[0]);
            if (!prov[1].isDigit())
                prov[1] = letterToDigitLike(prov[1]);
            if (!prov[0].isDigit() || !prov[1].isDigit())
                return {};
            // Province must be 11..99
            bool okNum = false;
            int provNum = prov.toInt(&okNum);
            if (!okNum || provNum < 11 || provNum > 99)
                return {};
            // Series: force to letter (correct confusables)
            series = QString(digitToLetterLike(series[0]));
            if (series.isEmpty() || series[0] < 'A' || series[0] > 'Z')
                return {};
            // Exclude I, O, Q per VN rules
            if (series[0] == 'I' || series[0] == 'O' || series[0] == 'Q')
                return {};
            // Tail: digits only (remove dots, correct confusables)
            QString tmp;
            tmp.reserve(tail.size());
            for (QChar c : tail)
            {
                if (c == '.')
                    continue;
                c = letterToDigitLike(c);
                if (c.isDigit())
                    tmp.append(c);
            }
            tail = tmp;
            // Prefer 5 digits, allow legacy 4 digits
            if (tail.length() != 5 && tail.length() != 4)
                return {};
            if (tail.length() == 5 && tail == QStringLiteral("00000"))
                return {};
            // Đảm bảo tổng độ dài đúng 8 ký tự cho XXY-ZZZZZ
            QString result = prov + series + '-' + tail;
            if (result.length() != 8)
                return {};
            return result;
        }
        // Pattern without letter: XX-ZZZZZ
        static const QRegularExpression reNoLetter(R"(^([0-9A-Z]{2})[-]?([0-9A-Z\\.]{3,6})$)");
        m = reNoLetter.match(filtered);
        if (!m.hasMatch())
            return {};
        prov = m.captured(1);
        tail = m.captured(2);
        for (QChar &c : prov)
            c = letterToDigitLike(c);
        if (!prov[0].isDigit())
            prov[0] = letterToDigitLike(prov[0]);
        if (!prov[1].isDigit())
            prov[1] = letterToDigitLike(prov[1]);
        if (prov.length() != 2 || !prov[0].isDigit() || !prov[1].isDigit())
            return {};
        {
            bool okNum = false;
            int provNum = prov.toInt(&okNum);
            if (!okNum || provNum < 11 || provNum > 99)
                return {};
        }
        {
            QString tmp;
            tmp.reserve(tail.size());
            for (QChar c : tail)
            {
                if (c == '.')
                    continue;
                c = letterToDigitLike(c);
                if (c.isDigit())
                    tmp.append(c);
            }
            tail = tmp;
        }
        if (tail.length() != 5 && tail.length() != 4)
            return {};
        if (tail.length() == 5 && tail == QStringLiteral("00000"))
            return {};
        QString result = prov + '-' + tail;
        if (result.length() != 7 && result.length() != 8)
            return {};
        return result;
    }
}

OCRProcessor::OCRProcessor(IParkingRepository *repo, QObject *parent)
    : QObject(parent)
{
    m_repo = repo;
    const QString modelPath = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("license_plate_detector.onnx"));
    m_detector = new YoloOnnxDetectorImpl(modelPath, this);
    m_detectorReady = m_detector && m_detector->isReady();
    qInfo() << "OCR: model path resolved to" << modelPath
            << ", detector ready =" << m_detectorReady;

    // Initialize Tesseract since ENABLE_TESSERACT is ON in CMake
    // Đảm bảo các DLLs có thể được phát hiện
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString vendorBin = QStringLiteral("d:/smart_parking_system/lib/tesseract/bin");
    const QString vendorBinDebug = QStringLiteral("d:/smart_parking_system/lib/tesseract/debug/bin");
    const QString pathNow = qEnvironmentVariable("PATH");
    QStringList prepend;
    if (!appDir.isEmpty())
        prepend << appDir;
    if (QDir(vendorBinDebug).exists())
        prepend << vendorBinDebug;
    if (QDir(vendorBin).exists())
        prepend << vendorBin;
    if (!prepend.isEmpty())
    {
        const QString newPath = prepend.join(';') + QLatin1Char(';') + pathNow;
        qputenv("PATH", newPath.toUtf8());
    }

    // Initialize Tesseract with vendor defaults; settings can still override
    QSettings s("Multimodel-AIThings", "smart_parking_system");
    const QString tessParent = s.value("tesseract/tessdataParent", QStringLiteral("d:/smart_parking_system/lib/tesseract")).toString();
    const QString tessLang = s.value("tesseract/lang", QStringLiteral("eng")).toString();
    if (!tessParent.isEmpty())
        qputenv("TESSDATA_PREFIX", QFile::encodeName(tessParent));

    m_tess = new TesseractOcr(this);
    bool ok = m_tess->init(tessParent, tessLang);
    if (!ok && tessLang != QStringLiteral("eng"))
        ok = m_tess->init(tessParent, QStringLiteral("eng"));
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
    result.insert("frontAnnotated", QByteArray());
    result.insert("rearAnnotated", QByteArray());

    const bool canTess = (m_tess && m_tess->isReady());
    const QString usedBackend = canTess ? QStringLiteral("tesseract") : QStringLiteral("none");
    result.insert("backend", usedBackend);

    bool detectionAttempted = false;
    if (m_detectorReady && m_detector)
    {
        detectionAttempted = true;
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
        // Log bounding box coordinates for diagnostics
        for (int i = 0; i < fBoxes.size(); ++i)
        {
            const QRectF &b = fBoxes[i];
            const float sc = (i < fScores.size() ? fScores[i] : 0.0f);
            qInfo() << "OCR: front box" << i << "x=" << b.x() << "y=" << b.y() << "w=" << b.width() << "h=" << b.height() << "score=" << sc;
        }
        for (int i = 0; i < rBoxes.size(); ++i)
        {
            const QRectF &b = rBoxes[i];
            const float sc = (i < rScores.size() ? rScores[i] : 0.0f);
            qInfo() << "OCR: rear  box" << i << "x=" << b.x() << "y=" << b.y() << "w=" << b.width() << "h=" << b.height() << "score=" << sc;
        }
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
            if (!img.loadFromData(jpeg))
                return {};
            if (img.isNull())
                return {};
            QRect r = rect.toAlignedRect();
            // Add padding around detected plate to avoid cutting characters
            const int padX = std::max(2, r.width() / 10); // 10%
            const int padY = std::max(2, r.height() / 6); // ~16%
            r.adjust(-padX, -padY, padX, padY);
            r = r.intersected(img.rect());
            if (r.isEmpty())
                return {};
            QImage cropped = img.copy(r);
            // Xoay nếu tỉ lệ khung hình nghiêng (biển dọc hoặc lệch nhiều)
            if (cropped.height() > cropped.width() * 1.2)
            {
                QTransform tr;
                tr.rotate(90);
                cropped = cropped.transformed(tr, Qt::SmoothTransformation);
            }
            // Upscale small crops to help OCR read multiple characters
            const int minH = 64;
            const int minW = 160;
            if (cropped.height() < minH || cropped.width() < minW)
            {
                const qreal sx = std::max(1.0, minW / qreal(cropped.width()));
                const qreal sy = std::max(1.0, minH / qreal(cropped.height()));
                const qreal s = std::max(sx, sy);
                cropped = cropped.scaled(cropped.width() * s, cropped.height() * s, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
            // Convert to grayscale and normalize contrast
            QImage gray = cropped.convertToFormat(QImage::Format_Grayscale8);
            // Simple contrast stretch
            int minV = 255, maxV = 0;
            for (int y = 0; y < gray.height(); ++y)
            {
                const uchar *line = gray.constScanLine(y);
                for (int x = 0; x < gray.width(); ++x)
                {
                    int v = line[x];
                    if (v < minV)
                        minV = v;
                    if (v > maxV)
                        maxV = v;
                }
            }
            QImage norm(gray.size(), QImage::Format_Grayscale8);
            if (maxV > minV)
            {
                const float scale = 255.f / float(maxV - minV);
                for (int y = 0; y < gray.height(); ++y)
                {
                    const uchar *src = gray.constScanLine(y);
                    uchar *dst = norm.scanLine(y);
                    for (int x = 0; x < gray.width(); ++x)
                    {
                        int v = int((src[x] - minV) * scale + 0.5f);
                        dst[x] = static_cast<uchar>(std::clamp(v, 0, 255));
                    }
                }
            }
            else
            {
                norm = gray;
            }
            QByteArray out;
            QBuffer buf(&out);
            buf.open(QIODevice::WriteOnly);
            // Use PNG to avoid JPEG artifacts in OCR input
            norm.save(&buf, "PNG");
            return out;
        };
        auto rotatePng90 = [](const QByteArray &png) -> QByteArray
        {
            if (png.isEmpty())
                return {};
            QImage img;
            if (!img.loadFromData(png))
                return {};
            QTransform tr;
            tr.rotate(90);
            QImage r = img.transformed(tr, Qt::SmoothTransformation);
            QByteArray out;
            QBuffer b(&out);
            b.open(QIODevice::WriteOnly);
            r.save(&b, "PNG");
            return out;
        };
        auto splitTwoLine = [](const QByteArray &png) -> QPair<QByteArray, QByteArray>
        {
            QPair<QByteArray, QByteArray> res;
            if (png.isEmpty())
                return res;
            QImage img;
            if (!img.loadFromData(png))
                return res;
            if (img.isNull())
                return res;
            const int mid = img.height() / 2;
            QImage top = img.copy(0, 0, img.width(), mid);
            QImage bot = img.copy(0, mid, img.width(), img.height() - mid);
            QByteArray tOut, bOut;
            QBuffer tb(&tOut), bb(&bOut);
            tb.open(QIODevice::WriteOnly);
            top.save(&tb, "PNG");
            bb.open(QIODevice::WriteOnly);
            bot.save(&bb, "PNG");
            res.first = tOut;
            res.second = bOut;
            return res;
        };
        auto drawBoxesJpeg = [](const QByteArray &jpeg, const QVector<QRectF> &boxes) -> QByteArray
        {
            if (jpeg.isEmpty())
                return {};
            QImage img;
            if (!img.loadFromData(jpeg))
                return {};
            if (img.isNull())
                return {};
            QPainter p(&img);
            p.setRenderHint(QPainter::Antialiasing, true);
            QPen pen(Qt::red);
            pen.setWidth(3);
            p.setPen(pen);
            for (const QRectF &rc : boxes)
                p.drawRect(rc);
            p.end();
            QByteArray out;
            QBuffer buf(&out);
            buf.open(QIODevice::WriteOnly);
            img.save(&buf, "JPG", 90);
            return out;
        };

        if (canTess)
        {
            int fi = pickLargest(fBoxes);
            if (fi >= 0)
            {
                QByteArray cj = cropJpeg(frontImage, fBoxes[fi]);
                // Multi-pass: 2-line vs 1-line vs vertical
                QString best;
                int bestScore = -1;
                auto consider = [&](const QString &cand)
                {
                    const QString s = cand.simplified();
                    if (s.isEmpty())
                        return;
                    // simple score: length and A-Z0-9 ratio
                    int az = 0;
                    for (const QChar &ch : s)
                        if (ch.isLetterOrNumber())
                            ++az;
                    int score = az * 2 + s.length();
                    if (score > bestScore)
                    {
                        bestScore = score;
                        best = s;
                    }
                };
                // Two-line split
                auto lines = splitTwoLine(cj);
                if (!lines.first.isEmpty() && !lines.second.isEmpty())
                {
                    const QString top = m_tess->recognizeWithPSM(lines.first, tesseract::PSM_SINGLE_LINE).simplified();
                    const QString bot = m_tess->recognizeWithPSM(lines.second, tesseract::PSM_SINGLE_LINE).simplified();
                    // Extract XXY from top, ZZZZZ from bottom
                    QString xxY, zzzzz;
                    // Province/series: must be exactly 3 chars, first 2 digits, last 1 letter (not I/O/Q)
                    QRegularExpression reTop("^([0-9]{2})([A-HJ-NPR-Z])$");
                    QRegularExpressionMatch mTop = reTop.match(top);
                    if (mTop.hasMatch())
                    {
                        QString prov = mTop.captured(1);
                        QString series = mTop.captured(2);
                        bool okNum = false;
                        int provNum = prov.toInt(&okNum);
                        if (okNum && provNum >= 11 && provNum <= 99)
                            xxY = prov + series;
                    }
                    // Number: must be 4 or 5 digits, not all zero
                    QRegularExpression reBot("^([0-9]{4,5})$");
                    QRegularExpressionMatch mBot = reBot.match(bot);
                    if (mBot.hasMatch())
                    {
                        zzzzz = mBot.captured(1);
                        if (zzzzz == QStringLiteral("00000"))
                            zzzzz.clear();
                    }
                    // Only merge if both are valid
                    if (!xxY.isEmpty() && !zzzzz.isEmpty())
                    {
                        consider(xxY + "-" + zzzzz);
                    }
                }
                // Single line
                consider(m_tess->recognizeWithPSM(cj, tesseract::PSM_SINGLE_LINE));
                // Block (two-line)
                consider(m_tess->recognizeWithPSM(cj, tesseract::PSM_SINGLE_BLOCK));
                // Vertical: rotate 90 degrees and try single-line again
                QByteArray r90 = rotatePng90(cj);
                if (!r90.isEmpty())
                {
                    consider(m_tess->recognizeWithPSM(r90, tesseract::PSM_SINGLE_LINE));
                    consider(m_tess->recognizeWithPSM(r90, tesseract::PSM_SINGLE_BLOCK));
                }
                if (!best.trimmed().isEmpty())
                {
                    QString norm = normalizePlateVN(best);
                    const QString chosen = norm.isEmpty() ? best.trimmed() : norm;
                    qInfo() << "OCR: front plate=" << chosen;
                    result.insert("front", chosen);
                }
            }
            else
            {
                // Không có box => không OCR whole image; đặt unknown
                result.insert("front", QStringLiteral("unknown"));
            }
            int ri = pickLargest(rBoxes);
            if (ri >= 0)
            {
                QByteArray cj = cropJpeg(rearImage, rBoxes[ri]);
                QString best;
                int bestScore = -1;
                auto consider = [&](const QString &cand)
                {
                    const QString s = cand.simplified(); if (s.isEmpty()) return; int az = 0; for (const QChar &ch: s) if (ch.isLetterOrNumber()) ++az; int score = az*2 + s.length(); if (score > bestScore) { bestScore = score; best = s; } };
                auto lines = splitTwoLine(cj);
                if (!lines.first.isEmpty() && !lines.second.isEmpty())
                {
                    const QString top = m_tess->recognizeWithPSM(lines.first, tesseract::PSM_SINGLE_LINE).simplified();
                    const QString bot = m_tess->recognizeWithPSM(lines.second, tesseract::PSM_SINGLE_LINE).simplified();
                    QString xxY, zzzzz;
                    QRegularExpression reTop("([0-9A-Z]{3})");
                    QRegularExpressionMatch mTop = reTop.match(top);
                    if (mTop.hasMatch())
                    {
                        xxY = mTop.captured(1);
                        QString prov = xxY.left(2);
                        QString series = xxY.right(1);
                        bool okNum = false;
                        int provNum = prov.toInt(&okNum);
                        if (!okNum || provNum < 11 || provNum > 99)
                            xxY.clear();
                        if (series < "A" || series > "Z" || series == "I" || series == "O" || series == "Q")
                            xxY.clear();
                    }
                    QRegularExpression reBot("([0-9]{4,5})");
                    QRegularExpressionMatch mBot = reBot.match(bot);
                    if (mBot.hasMatch())
                    {
                        zzzzz = mBot.captured(1);
                        if (zzzzz.length() != 4 && zzzzz.length() != 5)
                            zzzzz.clear();
                        if (zzzzz == QStringLiteral("00000"))
                            zzzzz.clear();
                    }
                    if (!xxY.isEmpty() && !zzzzz.isEmpty())
                    {
                        consider(xxY + "-" + zzzzz);
                    }
                    else
                    {
                        consider(top);
                        consider(bot);
                        if (!top.isEmpty() || !bot.isEmpty())
                            consider((top + "-" + bot).trimmed());
                    }
                }
                consider(m_tess->recognizeWithPSM(cj, tesseract::PSM_SINGLE_LINE));
                consider(m_tess->recognizeWithPSM(cj, tesseract::PSM_SINGLE_BLOCK));
                QByteArray r90 = rotatePng90(cj);
                if (!r90.isEmpty())
                {
                    consider(m_tess->recognizeWithPSM(r90, tesseract::PSM_SINGLE_LINE));
                    consider(m_tess->recognizeWithPSM(r90, tesseract::PSM_SINGLE_BLOCK));
                }
                if (!best.trimmed().isEmpty())
                {
                    QString norm = normalizePlateVN(best);
                    const QString chosen = norm.isEmpty() ? best.trimmed() : norm;
                    qInfo() << "OCR: rear plate=" << chosen;
                    result.insert("rear", chosen);
                }
            }
            else
            {
                result.insert("rear", QStringLiteral("unknown"));
            }
        }

        // Produce annotated images regardless of OCR success and log byte sizes
        if (!frontImage.isEmpty())
        {
            QByteArray fa = drawBoxesJpeg(frontImage, fBoxes);
            result.insert("frontAnnotated", fa);
            qInfo() << "OCR: frontAnnotated bytes=" << fa.size();
        }
        if (!rearImage.isEmpty())
        {
            QByteArray ra = drawBoxesJpeg(rearImage, rBoxes);
            result.insert("rearAnnotated", ra);
            qInfo() << "OCR: rearAnnotated  bytes=" << ra.size();
        }
    }
    else
    {
        qWarning() << "OCR: detector not ready; skipping detection and trying direct OCR";
    }

    // Fallback OCR toàn ảnh chỉ khi detector không sẵn sàng (không attempt detect)
    if (!detectionAttempted && canTess)
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
    const auto norm = [](const QString &s)
    { return s.trimmed(); };
    const QString fu = norm(f);
    const QString ru = norm(r);
    const QString fuNorm = normalizePlateVN(fu);
    const QString ruNorm = normalizePlateVN(ru);

    if (!fuNorm.isEmpty())
        plate = fuNorm;
    else if (!ruNorm.isEmpty())
        plate = ruNorm;
    else
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
