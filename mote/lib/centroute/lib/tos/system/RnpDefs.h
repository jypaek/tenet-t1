#ifndef _RNP_DEFS_H_
#define _RNP_DEFS_H_

#define RNP_NEIGH_DEV_NAME ("/dev/link/mh/neigh_rnp")

#ifndef MAX_RNP_NEIGHBORS
#define MAX_RNP_NEIGHBORS   30
#endif

#ifndef RAMPUP_PACKETS
#define RAMPUP_PACKETS      3
#endif

#ifndef DEFAULT_ALPHA
#define DEFAULT_ALPHA       0.10
#endif

#ifndef DEFAULT_INIT_RNP    
#define DEFAULT_INIT_RNP    1.25
#endif


#define N_UNKNOWN               0
#define N_ACTIVE                1
#define N_ASYMMETRIC_INBOUND    2
#define N_ASYMMETRIC_OUTBOUND   3   
#define N_DEAD                  4
#define N_DOWN_USR              5


#endif
