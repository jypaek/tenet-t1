
/*
 * Authors: Jeongyeup Paek, Sumit Rangwala 
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @author Sumit Rangwala
 * @modified 3/20/2005
 */

#ifndef MDA400
	# You should define 'MDA400' in the Makefile
	  to make sure that correct components are included
#endif

#ifndef _VBOARD_H_
#define _VBOARD_H_

#define VB_MAX_DATA_SIZE 80	// - jpaek, see the comment below
// this value must match with...
// both the mote-application and vboard code.
// And it is good to have a value which is common-multiple of 2,3,4,6

#define BUF_TEST	20

#define VB_HDR1 0xaa
#define VB_HDR2 0x55

typedef	struct _vBoardPacket{
	uint8_t h1;
	uint8_t h2;
	uint8_t cmd;
	uint8_t err;
	uint8_t nOfBytes;
	uint8_t data[VB_MAX_DATA_SIZE];
	uint8_t checksum;
}__attribute__((packed)) vBoardPacket;

// This structure must match 'runTime_cfg_sample' in 'vboard/main.h'
typedef struct runTimeSampleCfg {
		uint16_t sampling_period;
		uint8_t  nmb_channels;			// 1, 2, or 4
		uint8_t  ch_select;			   // use the lower 4bits
		uint16_t num_ksamples_per_ch;	 // limited to < 7
		uint8_t  onsetDetection;
}__attribute__((packed)) runTimeSampleCfg;

typedef struct VBTimeSyncMsg {
	uint32_t	sendingTime;
	uint32_t 	arrivalTime;	// Not sent
}__attribute__((packed)) VBTimeSyncMsg;

enum {
	HEADER_SIZE = 5,
	CHECKSUM_SIZE = 1
};

enum {
	SEND_IDLE = 0,
	SENDING = 1
};

enum {
	RECV_IDLE = 0,
	SYN1,
	RECV
};

enum {			   //enum for msg commands
	CMD_STATUS = 1,
	CMD_BOARD_CONFIG = 2,
	CMD_READ_SAMPLING_CONFIG = 3,
	CMD_WRITE_SAMPLING_CONFIG = 4,
	CMD_POWER_SET = 5,
	CMD_START_SAMPLING = 6,
	CMD_STOP_SAMPLING = 7,
	CMD_XMIT_DATA = 8,
	CMD_MEASURE_VOLTAGES = 9,
	CMD_TEST_MEM = 10,
	CMD_SAMPLING_COMPLETE = 11,

	CMD_START_SAMPLING_W_CFG = 12,  // ADDED by jpaek
	CMD_DATA_SAMPLE = 13,			// ADDED by jpaek
	CMD_SUSPEND_SENDING = 14,		// ADDED by jpaek
	CMD_RESUME_SENDING = 15,		// ADDED by jpaek

    CMD_START_CONT_SAMPLING = 16,   // ADDED by jpaek
    CMD_XMIT_NEXT_EVENT_DATA = 17,	// ADDED by jpaek
    CMD_XMIT_NEXT_AVAIL_DATA = 18,	// ADDED by jpaek

	CMD_TIMESYNC_MSG = 19 	// ADDED by jpaek

	// All other types remain unmodified.
};

enum {
	POWEROFF = 0,
	POWERON  = 1
};

#endif // _VBOARD_H_

