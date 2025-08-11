#ifndef OCRPROCESSOR_H
#define OCRPROCESSOR_H
#include <QObject>
#include <QVariant>
#include <QVariantMap>
#include <QByteArray>
#include "domain/ports/iocr.h"

class OCRProcessor : public QObject, public IOcr
{
    Q_OBJECT

public:
    explicit OCRProcessor(QObject *parent = nullptr);

public slots:
    // Thực tế nên xử lý bất đồng bộ; ở đây trả về giả lập để test luồng
    Q_INVOKABLE QVariantMap recognizePlates(const QByteArray &frontImage,
                                            const QByteArray &rearImage) override
    {
        Q_UNUSED(frontImage)
        Q_UNUSED(rearImage)
        // TODO: tích hợp OCR thực tế (OpenCV + Tesseract/EasyOCR/YOLO+CRNN)
        QVariantMap result;
        result.insert("front", QString());
        result.insert("rear", QString());
        return result;
    }
};

#endif // OCRPROCESSOR_H
