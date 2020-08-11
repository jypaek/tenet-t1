/*
 * Copyright (c) 2003, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Miklos Maroti
 * Date last modified: 12/05/03
 */

/*
 * @author: Brano Kusy, kusy@isis.vanderbilt.edu
 * Date last modified: jan05
 *
 * provides timestamping on transmitting/receiving SFD interrupt in CC2420.
 * uses LocalTime interface provided by TimerC: 4 byte local time from TimerB.
 *
 */

/**
 * slightly modified
 *
 * @date Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

configuration TimeStampingC
{
    provides
    {
        interface TimeStamping;
    #if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    #ifdef TIMESTAMPING_CALIBRATE
        command uint8_t getBitOffset();
    #endif
    #endif
    }
}

implementation
{
    components
        #if defined(PLATFORM_MICAZ) || defined(PLATFORM_TELOS) \
            || defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2)
            CC2420TimeStampingM as TimeStampingM
        #else
            CC1000TimeStampingM as TimeStampingM
        #endif
        #if defined(PLATFORM_MICAZ) || defined(PLATFORM_TELOS) \
            || defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2)
            , CC2420RadioC as Radio, HPLCC2420M
        #elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
            , CC1000RadioC as Radio
        #elif defined(PLATFORM_MICA) || defined(PLATFORM_PC)
            , MicaHighSpeedRadioM as Radio
        #endif
            , LocalTimeC
            ;

    TimeStamping = TimeStampingM;
#if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
#ifdef TIMESTAMPING_CALIBRATE
    getBitOffset = TimeStampingM;
#endif
#endif

    TimeStampingM.RadioSendCoordinator    -> Radio.RadioSendCoordinator;
    TimeStampingM.RadioReceiveCoordinator -> Radio.RadioReceiveCoordinator;
    
    TimeStampingM.LocalTime    -> LocalTimeC;
    
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_TELOS) \
    || defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2)
    TimeStampingM.HPLCC2420RAM -> HPLCC2420M;
#endif
}

