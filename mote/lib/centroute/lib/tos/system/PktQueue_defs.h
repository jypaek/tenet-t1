#ifndef _PKT_QUEUE_DEFS_H_
#define _PKT_QUEUE_DEFS_H_

// some of those defs are in host_mote_macros, so we need to protect
// ourselves
// TODO: fix the def collision
#ifndef __HOST_MOTE_MACROS_H__
#define INVALID             -1
#define SEND_FAILED         -2
#define EMPTY               0
#define CLEAR               1
#define SEND_PENDING        2
#define SEND_INPROGRESS     3
#define SEND_DONE_ACK       4
#define SEND_DONE_RETX_FAIL 5
#define SEND_DONE_NOACK     6
#define SEND_DONE_NO_RETX   7
#endif


#define RETRANSMIT          1
#define DONT_RETRANSMIT     2


#endif
