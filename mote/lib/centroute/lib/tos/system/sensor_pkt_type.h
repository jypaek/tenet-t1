#ifndef __SENSOR_PKT_T_H
#define __SENSOR_PKT_T_H

#include "QueryTypes.h"

typedef struct {
  uint16_t SrcAddr;
  uint8_t pktType;
} __attribute ((packed)) nims_hdr;

// For type NIMS_TOS_DSE_PKT type in pkt_types.h
typedef struct {
  nims_hdr hdr;
  QueryResponse_t DseData;
} __attribute ((packed)) nims_dse_sensor_pkt;

#endif
