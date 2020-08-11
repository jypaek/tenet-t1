
/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 **/

#ifndef _TR_LOGGER_TELOSB_FLASH_
#define _TR_LOGGER_TELOSB_FLASH_

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)

enum {
    //VOL_ID0 = 0,    // used by TRD
    //VOL_ID1 = 1,    // used by TRD
    VOL_ID2 = 2,    // used by StreamTransport
    VOL_ID3 = 3,    // used by StreamTransport
    VOL_ID4 = 4,    // used by StreamTransport
    VOL_ID5 = 5,    // used by StreamTransport
    VOL_ID6 = 6,    // used by RcrTransport
    VOL_ID7 = 7,    // used by RcrTransport
    VOL_ID8 = 8,    // used by RcrTransport
    VOL_ID9 = 9,    // used by RcrTransport
    //VOL_ID10 = 10,  // used by FlashStorage tasklet
    //VOL_ID11 = 11,  // used by 
};

#endif

#endif

