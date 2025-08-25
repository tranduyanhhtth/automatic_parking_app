#include "tesseract_ocr.h"
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QByteArray>

TesseractOcr::TesseractOcr(QObject *parent) : QObject(parent)
{
    m_api = new tesseract::TessBaseAPI();
}

TesseractOcr::~TesseractOcr()
{
    if (m_api)
    {
        m_api->End();
        delete m_api;
        m_api = nullptr;
    }
}

bool TesseractOcr::init(const QString &tessdataParent, const QString &lang)
{
    if (!m_api)
        return false;
    const QString absParent = QDir(tessdataParent).absolutePath();
    const QString tessDir = QDir(absParent + "/tessdata").absolutePath();
    const QByteArray langUtf8 = lang.toUtf8();

    auto tryInit = [&](const QString &path, const QString &prefixHint) -> bool
    {
        // Recreate API for each attempt to avoid sticky error state across Init calls
        if (m_api)
        {
            m_api->End();
            delete m_api;
            m_api = nullptr;
        }
        m_api = new tesseract::TessBaseAPI();
        // Set TESSDATA_PREFIX so tesseract can find tessdata
        if (!prefixHint.isEmpty())
            qputenv("TESSDATA_PREFIX", QFile::encodeName(prefixHint));
        const char *datapathPtr = nullptr;
        QByteArray enc;
        if (!path.isEmpty())
        {
            enc = QFile::encodeName(path);
            datapathPtr = enc.constData();
        }
        int rc = m_api->Init(datapathPtr, langUtf8.constData());
        if (rc != 0)
        {
            qWarning() << "Tesseract init failed rc=" << rc << " at datapath=" << (path.isEmpty() ? QStringLiteral("<null>") : path)
                       << ", TESSDATA_PREFIX=" << qEnvironmentVariable("TESSDATA_PREFIX")
                       << ", lang=" << lang;
            return false;
        }
        return true;
    };

    // Try a few options in order (prefer direct tessdata first to avoid noisy failures)
    // 1) datapath = tessDir, TESSDATA_PREFIX = absParent
    // 2) datapath = <null>, TESSDATA_PREFIX = tessDir
    // 3) datapath = absParent, TESSDATA_PREFIX = absParent
    bool ok = false;
    if (QFile::exists(tessDir))
        ok = tryInit(tessDir, absParent);
    if (!ok && QFile::exists(tessDir))
        ok = tryInit(QString(), tessDir);
    if (!ok)
        ok = tryInit(absParent, absParent);
    if (!ok)
    {
        m_ready = false;
        return false;
    }
    // Tune for license plates: single line and alphanumeric whitelist
    m_api->SetPageSegMode(tesseract::PSM_SINGLE_LINE);
    m_api->SetVariable("tessedit_char_whitelist", "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    m_ready = true;
    qInfo() << "Tesseract ready. Version=" << QString::fromUtf8(m_api->Version())
            << ", datapath/TESSDATA_PREFIX=" << qEnvironmentVariable("TESSDATA_PREFIX");
    return true;
}

QString TesseractOcr::recognize(const QByteArray &imageBytes) const
{
    if (!m_ready || imageBytes.isEmpty())
        return {};
    // Read Pix from memory
    const l_uint8 *dataPtr = reinterpret_cast<const l_uint8 *>(imageBytes.constData());
    size_t dataSize = static_cast<size_t>(imageBytes.size());
    Pix *pix = pixReadMem(dataPtr, dataSize);
    if (!pix)
        return {};
    m_api->SetImage(pix);
    char *outText = m_api->GetUTF8Text();
    pixDestroy(&pix);
    if (!outText)
        return {};
    QString res = QString::fromUtf8(outText).trimmed();
    delete[] outText;
    return res;
}
