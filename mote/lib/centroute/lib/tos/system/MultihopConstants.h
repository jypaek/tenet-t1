#ifndef MULTIHOPCONSTANTS_H
#define MULTIHOPCONSTANTS_H

/* Had to move these here from EmStar_Srings */
#define MULTIHOP_ROUTES     "/dev/link/mh/routes"
#define MULTIHOP_DATA       "mh"
#define MULTIHOP_NEIGHBORS  "/dev/link/mh/neighbors"
#define MULTIHOP_ROUTES     "/dev/link/mh/routes"

#define LNKEST_INITIAL_QUALITY (128)
#ifndef LNKEST_MAX_NEIGHBORS
# define LNKEST_MAX_NEIGHBORS (10)
#endif
#define LNKEST_ENTRY_REPLACEMENT_AGE (4)
#define LNKEST_MAX_TIMEOUTS (4)
#define LNKEST_EWMA_ALPHA (32)
#define LNKEST_STARTUP_EWMA_ALPHA (192)
#ifndef LNKEST_BEACON_PER 
# define LNKEST_BEACON_PER (10000)
#endif
#define LNKEST_BEACON_ADVERT_RATIO (8)
#define LNKEST_ADVERT_PER ((uint32_t)LNKEST_BEACON_PER * LNKEST_BEACON_ADVERT_RATIO)

#define BEACON_JITTER (1000)

#ifndef PTHEST_MAX_SINKS
# define PTHEST_MAX_SINKS (5)
#endif
#define PTHEST_ADVERT_PER (LNKEST_ADVERT_PER)
#define PTHEST_DAMPENING (18)
// should be 1/2 the alpha, so long as linkest advert period >= pathest advert.
// this is because of maximum inconsistency between neighbor's view of their
// link quality
#define PTHEST_HOP_PENALTY (12)
#define PTHEST_MAX_TIMEOUTS (5)
#define PTHEST_GRACE_PERIOD (1000)

#define PTHVECT_MAX_HOPS (7)
#define PTHVECT_MAX_SINKS (4)
#define PTHVECT_ADVERT_PER (LNKEST_ADVERT_PER)
#define PTHVECT_DAMPENING (10)
#define PTHVECT_HOP_PENALTY (10)
#define PTHVECT_MAX_TIMEOUTS (4)
#define ACCEPTABLE_PATH_QUALITY (20)

#define TREE_MAX_SINKS (PTHEST_MAX_SINKS + 1)
#define TREE_MAX_PAYLOAD_SZ (TOSH_DATA_LENGTH - sizeof(multihop_hdr_t) -sizeof(mote_id_t))

#define TAG_LNKEST_BEACON (1)
#define TAG_LNKEST_ADVERT (2)
#define TAG_PTHEST_ADVERT (3)
#define TAG_PTHVECT_ADVERT (3)
#define TAG_TREE_DISPATCH (4)

// run modes
//#define PTH_USE_SINK_AS_ROUTER

#define BEACON_RECV_BUF_LEN (1)
#define TREE_SEND_BUF_LEN (5)
#define DP_SUP_DEPTH (10)

#endif
