
Packet Transport ---> Simple end-to-end ACK based transport protocol
                      + Best-effort transport protocol

StreamTransport  ---> Connection oriented reliable stream transport
                      (use end-to-end NACK, no rate control)

RcrTransport     ---> RCRT (Rate-controlled reliable transport)
                      (centralized rate control, use end-to-end NACK)


RtrLogger ---> RCRT logger

