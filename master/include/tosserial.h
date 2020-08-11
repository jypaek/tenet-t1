
#ifndef _TOS_SERIAL_H_
#define _TOS_SERIAL_H_

/* for directly connecting to serial port instead of going through serial forwarder */
#include "serialsource.h"

void stderr_serial_msg(serial_source_msg problem);
void send_TOS_Msg_serial(serial_source src, const void *data, int len, uint8_t type, uint16_t addr, uint8_t group);

#endif

