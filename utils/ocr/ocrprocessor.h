#ifndef OCRPROCESSOR_H
#define OCRPROCESSOR_H
#include <QObject>
#include <QVariant>
#include <QVariantMap>
#include <QByteArray>
#include "domain/ports/iocr.h"
#include "domain/ports/iparkingrepository.h"

class YoloOnnxDetectorImpl; // forward declaration to avoid leaking ONNX headers
class IParkingRepository;   // forward declaration for DI pointer

class OCRProcessor : public QObject, public IOcr
{
    Q_OBJECT

public:
    explicit OCRProcessor(IParkingRepository *repo, QObject *parent = nullptr);

public slots:
    // Thực tế sẽ xử lý bất đồng bộ; ở đây trả về giả lập để test luồng
    Q_INVOKABLE QVariantMap recognizePlates(const QByteArray &frontImage,
                                            const QByteArray &rearImage) override;

    // Quy trình tích hợp CSDL: lấy ảnh từ phiên đang mở theo RFID, chạy OCR và cập nhật bảng 'plate'.
    // Trả về biển số đã cập nhật (hoặc rỗng nếu thất bại/không xác định).
    Q_INVOKABLE QString processOpenSessionAndUpdatePlate(const QString &rfid);

private:
    YoloOnnxDetectorImpl *m_detector{nullptr};
    bool m_detectorReady{false};
    IParkingRepository *m_repo{nullptr};
};

#endif // OCRPROCESSOR_H
