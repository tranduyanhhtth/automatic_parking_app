#ifndef ICAMERASNAPSHOTPROVIDER_H
#define ICAMERASNAPSHOTPROVIDER_H
#include <QByteArray>
#include <QVideoSink>

class ICameraSnapshotProvider
{
public:
    virtual ~ICameraSnapshotProvider() = default;
    virtual void setInputVideoSink(QVideoSink *sink) = 0;
    virtual void setOutputVideoSink(QVideoSink *sink) = 0;
    virtual QByteArray captureInputSnapshot(int quality = 85) = 0;
    virtual QByteArray captureOutputSnapshot(int quality = 85) = 0;
    // Xóa dữ liệu xem trước ngay lập tức
    virtual void clearSnapshots() = 0;
};

#endif // ICAMERASNAPSHOTPROVIDER_H
