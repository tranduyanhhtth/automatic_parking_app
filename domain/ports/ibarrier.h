#ifndef IBARRIER_H
#define IBARRIER_H

class IBarrier
{
public:
    virtual ~IBarrier() = default;
    virtual void open() = 0;
    virtual void close() = 0;
};

#endif // IBARRIER_H
