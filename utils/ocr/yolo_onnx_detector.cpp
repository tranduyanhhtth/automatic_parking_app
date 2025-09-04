#include "yolo_onnx_detector.h"
#include <QImage>
#include <QDebug>
#include <algorithm>
#include <cmath>
#include <numeric> // std::iota
#include <cstring> // std::memcpy
#include <onnxruntime_cxx_api.h>

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
        qWarning() << "ONNX: detector not ready; ensure onnxruntime.dll is next to the exe";
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
    try
    {
        QImage src((uchar *)data, width, height, bytesPerLine, QImage::Format_RGB888);
        QImage input;
        float scale = 1.f;
        int dx = 0;
        int dy = 0;
        letterbox(src, m_inputW, m_inputH, input, scale, dx, dy);
        qInfo() << "YOLO letterbox:" << "orig=" << width << "x" << height
                << ", input=" << m_inputW << "x" << m_inputH
                << ", scale=" << scale << ", dx=" << dx << ", dy=" << dy;

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

        // IO names (query from model to avoid hardcoding)
        Ort::AllocatorWithDefaultOptions allocator;
        auto inputNameAlloc = session.GetInputNameAllocated(0, allocator);
        auto outputNameAlloc = session.GetOutputNameAllocated(0, allocator);
        const char *inputNames[] = {inputNameAlloc.get()};
        const char *outputNames[] = {outputNameAlloc.get()};

        auto outputs = session.Run(Ort::RunOptions{nullptr}, inputNames, &inputTensor, 1, outputNames, 1);
        if (outputs.empty() || !outputs[0].IsTensor())
            return false;

        // Parse output with heuristics: model may output [cx,cy,w,h,score,class] (normalized or pixels)
        float *outData = outputs[0].GetTensorMutableData<float>();
        auto typeInfo = outputs[0].GetTensorTypeAndShapeInfo();
        auto outShape = typeInfo.GetShape();
        if (outShape.size() != 3)
            return false;

        // Support both layouts: [1, N, D] and [1, D, N]
        int dim1 = static_cast<int>(outShape[1]);
        int dim2 = static_cast<int>(outShape[2]);
        bool dFirst = false; // true when shape is [1, D, N]
        int D = 0, N = 0;
        // Heuristic: if dim1 looks like feature size (6, 7, 84, 85, <= 128), treat as D
        if (dim1 <= 128 || dim1 < dim2)
        {
            dFirst = true;
            D = dim1;
            N = dim2;
        }
        else
        {
            dFirst = false;
            D = dim2;
            N = dim1;
        }
        if (D < 5 || N <= 0)
            return false;

        // Log output shape and parsing decision
        qInfo() << "YOLO outShape=" << outShape[0] << outShape[1] << outShape[2]
                << ", layout=" << (dFirst ? "[1,D,N]" : "[1,N,D]")
                << ", N=" << N << ", D=" << D
                << ", conf>=" << m_confThreshold;

        QVector<QRectF> b;
        b.reserve(N);
        QVector<float> sc;
        sc.reserve(N);

        auto get = [&](int n, int d) -> float
        {
            // Access as [1, D, N] or [1, N, D]
            if (dFirst)
                return outData[d * N + n];
            else
                return outData[n * D + d];
        };

        for (int i = 0; i < N; ++i)
        {
            // YOLO common: [cx,cy,w,h,obj,(classes...)]
            const float cx_v = get(i, 0);
            const float cy_v = get(i, 1);
            const float w_v = get(i, 2);
            const float h_v = get(i, 3);
            const float obj = get(i, 4);

            // Combine with class confidence when available
            float clsConf = 1.f;
            int bestClass = 0;
            if (D > 6)
            {
                float maxProb = 0.f;
                for (int d = 5; d < D; ++d)
                {
                    float p = get(i, d);
                    if (p > maxProb)
                    {
                        maxProb = p;
                        bestClass = d - 5;
                    }
                }
                clsConf = maxProb; // assume already softmax/sigmoid
            }
            float s = obj * clsConf;
            // Normalize scores if model outputs 0..100
            if (s > 1.f && s <= 100.f)
                s = s / 100.f;
            if (s < m_confThreshold)
                continue;

            // Determine format: normalized center or absolute center (pixels)
            float x1, y1, x2, y2;
            const bool looksNormalized = (std::abs(cx_v) <= 2.f && std::abs(cy_v) <= 2.f && std::abs(w_v) <= 2.f && std::abs(h_v) <= 2.f);
            if (looksNormalized && w_v <= 1.5f && h_v <= 1.5f)
            {
                // [cx,cy,w,h] normalized 0..1
                const float cx = cx_v * W;
                const float cy = cy_v * H;
                const float ww = w_v * W;
                const float hh = h_v * H;
                x1 = cx - ww * 0.5f;
                y1 = cy - hh * 0.5f;
                x2 = cx + ww * 0.5f;
                y2 = cy + hh * 0.5f;
            }
            else
            {
                // Assume absolute pixels [cx,cy,w,h]
                const float cx = cx_v, cy = cy_v, ww = w_v, hh = h_v;
                x1 = cx - ww * 0.5f;
                y1 = cy - hh * 0.5f;
                x2 = cx + ww * 0.5f;
                y2 = cy + hh * 0.5f;
            }
            // Ensure positive width/height in letterboxed space
            float lbX = std::min(x1, x2);
            float lbY = std::min(y1, y2);
            float lbW = std::abs(x2 - x1);
            float lbH = std::abs(y2 - y1);
            if (lbW <= 1.f || lbH <= 1.f)
                continue;

            // Map back from letterboxed to original image size
            float invScale = 1.f / scale;
            float ox = (lbX - dx) * invScale;
            float oy = (lbY - dy) * invScale;
            float ow = lbW * invScale;
            float oh = lbH * invScale;
            // Clamp to original image bounds
            if (ox + ow <= 1.f || oy + oh <= 1.f)
                continue;
            QRectF mapped(std::max(0.f, ox), std::max(0.f, oy), std::max(0.f, ow), std::max(0.f, oh));
            b.push_back(mapped);
            sc.push_back(s);

            // Detailed per-candidate log (original image space)
            qInfo() << "YOLO candidate" << i
                    << ": x=" << mapped.x() << " y=" << mapped.y()
                    << " w=" << mapped.width() << " h=" << mapped.height()
                    << " conf=" << s;
        }

        QVector<int> keep;
        nms(keep, b, sc, m_nmsThreshold);

        boxes.clear();
        scores.clear();
        if (keep.isEmpty())
            return true; // no detections

        // Enforce at most m_maxDetections (single-car scenario)
        int maxKeep = std::max(1, m_maxDetections);
        int outCount = fmin(maxKeep, keep.size());
        boxes.reserve(outCount);
        scores.reserve(outCount);

        for (int k = 0; k < outCount; ++k)
        {
            int idx = keep[k];
            boxes.push_back(b[idx]);
            scores.push_back(sc[idx]);
            qInfo() << "YOLO kept" << k
                    << ": x=" << boxes.back().x() << " y=" << boxes.back().y()
                    << " w=" << boxes.back().width() << " h=" << boxes.back().height()
                    << " conf=" << scores.back();
        }
        return true;
    }
    catch (const std::exception &e)
    {
        qWarning() << "ONNX detect error:" << e.what();
        return false;
    }
}
