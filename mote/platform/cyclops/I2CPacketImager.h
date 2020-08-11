#ifndef I2CPACKETIMAGER_H
#define I2CPACKETIMAGER_H

  enum {STOP_FLAG=0x01, /* send stop command at the end of packet? */
        ACK_FLAG =0x02, /* send ack after recv a byte (except for last byte) */
        ACK_END_FLAG=0x04, /* send ack after last byte recv'd */ 
        ADDR_8BITS_FLAG=0x80, // the address is a full 8-bits with no terminating readflag
       };

#endif
