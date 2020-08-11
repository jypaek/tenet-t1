#ifndef QUERYCONSTANTS_H
#define QUERYCONSTANTS_H

#define QH_MAX_RESPONSE_SIZE 64

#define MAX_MNS 16
#define NOISE_WINDOW_SAMPLES 15
#define NOISE_WINDOW_PERIOD 10 /* Units of .1 seconds */
#define NUMBER_SAMPLES_PER_NOISE_WINDOW 30


// This are &'ed against the queryFlags to cull the correct value.
// Query type is the low 4 bits of the queryFlags.
#define QUERY_TYPE_MASK 0xf
// Exact match is required if the high bit is 1.
#define EXACT_MATCH 0x80
// The comparison operator is Less-Than if the 7th bit is 1.
#define COMP_OPER 0x40
// The aggregation function is average if the 6th bit is 1.
#define AGG_FUNC 0x20
// Ion-selective electrodes require averaging over multiple readings to remove noise
// So DSE controls the sampling: every period, DSE takes a sample every 1 second
// and sends all the data to the user (will take NOISE_WINDOW_SAMPLES)
#define NOISE_WINDOW_SAMPLING 0x10

#define QUERY_STATE(HDR) ((QueryState_t*)((uint8_t*)(HDR)+sizeof(QueryHeader_t)+(HDR)->mnCnt))
#define QUERY_TYPE(HDR) ((HDR)->queryFlags & QUERY_TYPE_MASK)
#define IS_EXACT_MATCH(HDR) ((HDR)->queryFlags & EXACT_MATCH)
#define IS_COMP_OPER(HDR) ((HDR)->queryFlags & COMP_OPER)
#define IS_NOISE_WINDOW_SAMPLING(HDR) ((HDR)->queryFlags & NOISE_WINDOW_SAMPLING)
#define IS_MIN_AGG_FUNC(HDR) ((HDR)->queryFlags & AGG_FUNC)

#endif
