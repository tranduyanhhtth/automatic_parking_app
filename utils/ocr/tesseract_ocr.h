#pragma once
#include <QObject>
#include <QString>
#include <QByteArray>

// Guard includes to allow building without Tesseract
#ifdef HAVE_TESSERACT
#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>
#endif

// Lightweight adapter around Tesseract to OCR JPEG bytes.
class TesseractOcr : public QObject
{
    Q_OBJECT
public:
    explicit TesseractOcr(QObject *parent = nullptr);
    ~TesseractOcr() override;

    // Initialize engine. tessdataParent is the folder that contains the "tessdata" directory.
    // lang example: "eng", "vie", "eng+vie".
    bool init(const QString &tessdataParent, const QString &lang);

    // Recognize text from a JPEG/PNG buffer. Returns trimmed UTF-8 text.
    QString recognize(const QByteArray &imageBytes) const;

    bool isReady() const { return m_ready; }

private:
    bool m_ready{false};
#ifdef HAVE_TESSERACT
    tesseract::TessBaseAPI *m_api{nullptr};
#endif
};
