#ifndef CARDREADER_H
#define CARDREADER_H
#include <QObject>
#include "domain/ports/icardreader.h"

class CardReader : public ICardReader
{
    Q_OBJECT
public:
    explicit CardReader(QObject *parent = nullptr);

public slots:
    Q_INVOKABLE void simulateSwipe(const QString &rfid) { emit rfidScanned(rfid); }
};

#endif // CARDREADER_H
