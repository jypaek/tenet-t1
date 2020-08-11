
#ifndef TOSH_DATA_LENGTH
#define TOSH_DATA_LENGTH 29
#endif


#ifdef LONELY_MOTE
  #define ROUTE_CHECK_PERIOD 3000L
  #define ROUTE_CHECK_PERIOD_MAX 30000L
#else
  #define ROUTE_CHECK_PERIOD 3100L
  #define ROUTE_CHECK_PERIOD_MAX 100000L
#endif


#define APPID_MSK 0x1F
#define COST_MSK 0x01
#define RELIABLE_MSK 0x01


//Reliability values
enum
  {
    RELIABLE_SERVICE,
    UNRELIABLE_SERVICE
  };

//Cost values
enum
  {
    HIGH_PRIORITY,
    LOW_PRIORITY
  };


//address definitions
enum
  {
    MY_ROOT = 0xFFF0,
    ANY_ROOT,
    ALL_ROOTS,
    LOCAL_BROADCAST,
    TREE_BROADCAST,
    NETWORK_BROADCAST
  };



//ACR=bit7-2:APPID, bit1:COST, bit0:RELIABLE
typedef struct _mdtnpkt{
  uint16_t address;
  uint8_t acr;
  uint8_t data[0];
} __attribute__ ((packed)) mDTN_pkt_t;

