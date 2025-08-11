#ifndef BARRIERCONTROLLER_H
#define BARRIERCONTROLLER_H
#include <QObject>
#include "domain/ports/ibarrier.h"

class BarrierController : public QObject, public IBarrier
{
    Q_OBJECT

public:
    explicit BarrierController(QObject *parent = nullptr);

public slots:
    // Mở/đóng barrier (TODO: điều khiển relay/PLC thực tế)
    Q_INVOKABLE void open() override { /* TODO: relay */ emit barrierOpened(); }
    Q_INVOKABLE void close() override { /* TODO: relay */ emit barrierClosed(); }

signals:
    void barrierOpened();
    void barrierClosed();
};

#endif // BARRIERCONTROLLER_H
