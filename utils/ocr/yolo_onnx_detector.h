#pragma once
#include <QObject>
#include <QRectF>
#include <QByteArray>
#include <QVector>
#include <QString>

// Lightweight ONNX-YOLO detector for license plates.
// Requires HAVE_ONNXRUNTIME at build-time, otherwise this header can still be included but impl won't be compiled.
class YoloOnnxDetectorImpl : public QObject
{
    Q_OBJECT
public:
    explicit YoloOnnxDetectorImpl(const QString &modelPath, QObject *parent = nullptr);
    bool isReady() const;
    // Convenience for JPEG input to avoid forcing QImage dependency on callers.
    bool detectJpeg(const QByteArray &jpeg,
                    QVector<QRectF> &boxes,
                    QVector<float> &scores) const;

private:
    bool detectRgb(const uchar *data, int width, int height, int bytesPerLine,
                   QVector<QRectF> &boxes,
                   QVector<float> &scores) const;

private:
    QString m_modelPath;
    bool m_ready{false};

    // Inference parameters (adapt to your model export)
    int m_inputW{640};
    int m_inputH{640};
    float m_confThreshold{0.25f};
    float m_nmsThreshold{0.45f};
};
