#ifndef MULTIHOPTYPES_H
#define MULTIHOPTYPES_H

typedef uint16_t mote_id_t;
#ifndef ULTRATYPES_H
#ifndef _TRD_SEQNO_H_
typedef uint16_t seqno_t;
#endif
#endif
typedef uint8_t quality_t;

typedef enum {
  DISPATCH_TO_ROOT,
  DISPATCH_TO_ANY_ROOT,
  DISPATCH_TO_TREE,
  DISPATCH_TO_ANY_TREE
} dispatch_t;

typedef struct {
  mote_id_t src;
  mote_id_t dst;
  seqno_t seqno;
  uint8_t type;
  // for platform difference, we make this field to one byte
  // note that dispatch_t is 4 bytes on PC, while it is 2 bytes on stargate
  dispatch_t dispatch:8;
  char data[0];
} __attribute__ ((packed)) multihop_hdr_t;

typedef struct {
  mote_id_t addr;
  quality_t quality;
} __attribute__ ((packed)) link_quality_t;

typedef struct {
  mote_id_t sink;
  quality_t quality;
  uint8_t round;
} __attribute__ ((packed)) path_advert_t;

typedef enum {
  LINK_REMOVE,
  LINK_ADD,
  LINK_CHANGE
} link_update_t;

enum
{
  MULTIHOP_MAX_MSG_LEN = 20
};

#endif
