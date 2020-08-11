#ifndef _CENTTREE_DEFS_H_
#define _CENTTREE_DEFS_H_

#define CENTROUTE_PD_NAME ("/dev/herd/tree_pd")

#define PD_BEACON       20


#define UP_TREE         1
#define DOWN_TREE       2

// type is a 6-bit field so max types is 32
#define JOIN_REQUEST        1
#define JOIN_FORWARD        2
#define JOIN_REPLY          3
#define DATA                4
#define DST_UNREACHABLE     5
#define NOT_ASSOCIATED      6
#define DISSOCIATE          7


#define RACK            1
#define RNACK           2

#define SINK_REACHED    10
#define ENOBUFFERS      -1
#define ENONEIGHBOR     -2
#define ENOSPACE        -3
#define ENOENTRIES      -4
#define EBADDIRECTION   -5
#define ENOTASSOCIATED  -6
#define ENOPARENT       -7
#define EISSINK         -8
#define EINVALIDENTRY   -9
#define EINVALIDSINK    -10
#define ELENGTH         -11
#define EENTRYERR       -12
#define EINVALIDLENGTH  -13
#define ETXERROR        -14
#define EISNOTSINK      -15


#define DATA_ACK_REQUEST    0
#define DATA_ACK_REPLY      1      


#define REG_PKT_TYPE        1


#endif
