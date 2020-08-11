#ifndef QUERYTYPES_H
#define QUERYTYPES_H

/* Cannot be greater than number of bits specified
 * in QUERY_TYPE_MASK in dse/tos/lib */
enum QueryTypes
{
  delete_query = 0,
  single_sample = 1,
  periodic_sample,
  periodic_conditional_sample,
  event_sample,
  event_aggregate_sample,
  config_command
};

typedef struct QueryHeader_s
{
  uint8_t queryID;
  uint8_t queryFlags; // Made up of type, exact match, comparison operator, and aggregation function.
  uint16_t compVal;
  uint8_t maxEpoch;
  uint8_t noiseWindow;
  uint16_t samplingPeriod;
  uint8_t mnCnt;
  uint8_t mn[0];
} __attribute__((packed)) QueryHeader_t;

// The order of this struct is very important!  To make
// sure I don't copy the query result from query state
// into a query response packet I can give a pointer
// to the curepoch and tell someone that it is a
// query response (I also need to set curEpoch to
// the query's ID.
typedef struct QueryState_s
{
  uint16_t slaveBitMask;
  uint8_t curEpoch;
  uint16_t masterBitMask;
  uint8_t samplingIDs[0];
} __attribute__((packed)) QueryState_t;

typedef struct QueryData_s
{
  int16_t data[0];
} __attribute__((packed)) QueryData_t;

// These are macros for accessing the query structure
// All these macros assume that ptr is a uint8_t*.
// It should be pointing to the query header.

typedef struct QueryResponse_s
{
  uint8_t queryID;
  uint16_t bitMask;
  int16_t data[0];
} __attribute__((packed)) QueryResponse_t;


typedef struct ConfigCommandHeader_s
{
  uint8_t queryID;
  uint8_t queryFlags;
  uint8_t nodeID;
  uint8_t cmd;
  uint8_t param[0];
} __attribute__((packed)) ConfigCommandHeader_t;

typedef struct ConfigCommandPacket_s 
{
  ConfigCommandHeader_t hdr;
  uint8_t hwaddr;
  uint8_t measurementname;
  uint8_t sensortype;
  uint8_t parameter;
} __attribute__((packed)) ConfigCommandPacket_t;

#endif
