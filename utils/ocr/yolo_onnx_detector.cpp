#include "yolo_onnx_detector.h"
#include <QImage>
#include <QBuffer>
#include <QDebug>
#include <algorithm>
#include <cmath>

#ifdef HAVE_ONNXRUNTIME
#include <onnxruntime_cxx_api.h>
#endif

namespace
{
    static void letterbox(const QImage &src, int dstW, int dstH, QImage &out, float &scale, int &dx, int &dy)
    {
        float r = std::min(dstW / float(src.width()), dstH / float(src.height()));
        int newW = int(std::round(src.width() * r));
        int newH = int(std::round(src.height() * r));
        QImage resized = src.scaled(newW, newH, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        out = QImage(dstW, dstH, QImage::Format_RGB888);
        out.fill(Qt::black);
        dx = (dstW - newW) / 2;
        dy = (dstH - newH) / 2;
        for (int y = 0; y < newH; ++y)
        {
            memcpy(out.scanLine(y + dy) + dx * 3, resized.scanLine(y), newW * 3);
        }
        scale = r;
    }

    static float iou(const QRectF &a, const QRectF &b)
    {
        QRectF inter = a.intersected(b);
        if (inter.isEmpty())
            return 0.f;
        float interArea = inter.width() * inter.height();
        float ua = a.width() * a.height() + b.width() * b.height() - interArea;
        return interArea / std::max(ua, 1e-6f);
    }

    static void nms(QVector<int> &indices,
                    const QVector<QRectF> &boxes,
                    const QVector<float> &scores,
                    float nmsThresh)
    {
        QVector<int> order(boxes.size());
        std::iota(order.begin(), order.end(), 0);
        std::sort(order.begin(), order.end(), [&](int i, int j)
                  { return scores[i] > scores[j]; });

        while (!order.isEmpty())
        {
            int i = order.front();
            indices.push_back(i);
            QVector<int> rest;
            for (int k = 1; k < order.size(); ++k)
            {
                int j = order[k];
                if (iou(boxes[i], boxes[j]) <= nmsThresh)
                    rest.push_back(j);
            }
            order = rest;
        }
    }
}

YoloOnnxDetectorImpl::YoloOnnxDetectorImpl(const QString &modelPath, QObject *parent)
    : QObject(parent), m_modelPath(modelPath)
{
#ifdef HAVE_ONNXRUNTIME
    // Try a light session init to verify the file is loadable and runtime is present.
    try
    {
        if (m_modelPath.isEmpty())
        {
            qWarning() << "ONNX: empty model path";
            m_ready = false;
            return;
        }
        qInfo() << "ONNX: initializing session with" << m_modelPath;
        Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "sps-init");
        Ort::SessionOptions so;
        so.SetIntraOpNumThreads(1);
        so.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_BASIC);
        Ort::Session session(env, m_modelPath.toStdWString().c_str(), so);
        m_ready = true;
        qInfo() << "ONNX: model loaded successfully";
    }
    catch (const std::exception &e)
    {
        qWarning() << "ONNX: failed to load model:" << e.what();
        m_ready = false;
    }
#else
    m_ready = false;
    Q_UNUSED(m_modelPath)
    qWarning() << "ONNX: runtime disabled at build time (HAVE_ONNXRUNTIME not defined); detector not ready";
#endif
}

bool YoloOnnxDetectorImpl::isReady() const { return m_ready; }

bool YoloOnnxDetectorImpl::detectJpeg(const QByteArray &jpeg,
                                      QVector<QRectF> &boxes,
                                      QVector<float> &scores) const
{
    boxes.clear();
    scores.clear();
    if (!m_ready)
    {
        qWarning() << "ONNX: detector not ready; ensure ENABLE_ONNXRUNTIME=ON and onnxruntime.dll is next to the exe";
        return false;
    }
    if (jpeg.isEmpty())
    {
        qWarning() << "ONNX: detectJpeg received empty input";
        return false;
    }

    QImage img;
    img.loadFromData(jpeg);
    if (img.isNull())
        return false;
    if (img.format() != QImage::Format_RGB888)
        img = img.convertToFormat(QImage::Format_RGB888);

    return detectRgb(img.bits(), img.width(), img.height(), img.bytesPerLine(), boxes, scores);
}

bool YoloOnnxDetectorImpl::detectRgb(const uchar *data, int width, int height, int bytesPerLine,
                                     QVector<QRectF> &boxes,
                                     QVector<float> &scores) const
{
#ifndef HAVE_ONNXRUNTIME
    Q_UNUSED(data)
    Q_UNUSED(width)
    Q_UNUSED(height)
    Q_UNUSED(bytesPerLine)
    Q_UNUSED(boxes)
    Q_UNUSED(scores)
    qWarning() << "ONNX: runtime disabled at build time; skipping inference";
    return false;
#else
    try
    {
        QImage src((uchar *)data, width, height, bytesPerLine, QImage::Format_RGB888);
        QImage input;
        float scale = 1.f;
        int dx = 0;
        int dy = 0;
        letterbox(src, m_inputW, m_inputH, input, scale, dx, dy);

        const int C = 3, H = m_inputH, W = m_inputW;
        std::vector<float> blob(C * H * W);
        for (int y = 0; y < H; ++y)
        {
            const uchar *row = input.constScanLine(y);
            for (int x = 0; x < W; ++x)
            {
                const uchar *p = row + x * 3;
                float r = p[0] / 255.f;
                float g = p[1] / 255.f;
                float b = p[2] / 255.f;
                blob[0 * H * W + y * W + x] = r;
                blob[1 * H * W + y * W + x] = g;
                blob[2 * H * W + y * W + x] = b;
            }
        }

        // ONNX Runtime session (create per-call to avoid global state deps; could be cached)
        Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "sps");
        Ort::SessionOptions so;
        so.SetIntraOpNumThreads(1);
        so.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_EXTENDED);
        Ort::Session session(env, m_modelPath.toStdWString().c_str(), so);
        Ort::MemoryInfo memInfo = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

        // Input tensor
        std::array<int64_t, 4> dims = {1, C, H, W};
        Ort::Value inputTensor = Ort::Value::CreateTensor<float>(memInfo, blob.data(), blob.size(), dims.data(), dims.size());

        // IO names (assumes common export names; adjust as necessary)
        const char *inputNames[] = {"images"};
        const char *outputNames[] = {"output0"};

        auto outputs = session.Run(Ort::RunOptions{nullptr}, inputNames, &inputTensor, 1, outputNames, 1);
        if (outputs.empty() || !outputs[0].IsTensor())
            return false;

        // Parse output: assume [1, num, 6] where [x1,y1,x2,y2,score,class]
        float *outData = outputs[0].GetTensorMutableData<float>();
        auto typeInfo = outputs[0].GetTensorTypeAndShapeInfo();
        auto outShape = typeInfo.GetShape();
        if (outShape.size() != 3 || outShape[2] < 6)
            return false;
        const int num = static_cast<int>(outShape[1]);

        QVector<QRectF> b;
        b.reserve(num);
        QVector<float> sc;
        sc.reserve(num);
        for (int i = 0; i < num; ++i)
        {
            const float x1 = outData[i * outShape[2] + 0];
            const float y1 = outData[i * outShape[2] + 1];
            const float x2 = outData[i * outShape[2] + 2];
            const float y2 = outData[i * outShape[2] + 3];
            const float s = outData[i * outShape[2] + 4];
            // const float cls = outData[i * outShape[2] + 5];
            if (s < m_confThreshold)
                continue;
            QRectF rb(x1, y1, std::max(0.f, x2 - x1), std::max(0.f, y2 - y1));
            // map back from letterboxed to original image size
            float invScale = 1.f / scale;
            QRectF mapped((rb.x() - dx) * invScale,
                          (rb.y() - dy) * invScale,
                          rb.width() * invScale,
                          rb.height() * invScale);
            b.push_back(mapped);
            sc.push_back(s);
        }

        QVector<int> keep;
        nms(keep, b, sc, m_nmsThreshold);

        boxes.clear();
        scores.clear();
        boxes.reserve(keep.size());
        scores.reserve(keep.size());
        for (int idx : keep)
        {
            boxes.push_back(b[idx]);
            scores.push_back(sc[idx]);
        }
        return true;
    }
    catch (const std::exception &e)
    {
        qWarning() << "ONNX detect error:" << e.what();
        return false;
    }
#endif
}
