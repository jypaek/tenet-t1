/*
* "Copyright (c) 2006~2008 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * Configuration file of tasklet 'Sample'.
 * Sample is a tasklet that reads the sensors (ADCs).
 * It does the wiring for different platforms.
 *
 * @author Jeongyeup Paek
 * @modified Jan/15/2008
 **/

configuration SampleC {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface TenetTask;
        interface List;
        interface Schedule;
        interface Memory;
        interface TaskError;
        interface LocalTime;
        interface LocalTimeInfo;
    }
}
implementation {
  components Sample
           , Main
           , TimerC
        #ifdef PLATFORM_TELOSB
           , MSP430ADC12C
           , HamamatsuC
           , HumidityC
           , InternalTempC
        #elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
           , Photo
           , Temp
           , Accel
        #elif defined(PLATFORM_MICA2DOT)
           , Photo
           , Temp
        #endif
           , SamplePlatform
           ;

    /* provided interfaces */
    StdControl    = Sample;
    Element       = Sample;

    /* used interfaces */
    TenetTask     = Sample;
    List          = Sample;
    Schedule      = Sample;
    Memory        = Sample;
    TaskError     = Sample;
    LocalTime     = Sample;
    LocalTimeInfo = Sample;

    /* internal wirings */

    Sample.ADC      -> SamplePlatform;
    Sample.Timer    -> TimerC.Timer[unique("Timer")];
    Main.StdControl -> TimerC;

#ifdef PLATFORM_TELOSB
    SamplePlatform.ADCControl       -> MSP430ADC12C;
    SamplePlatform.ADCControl       -> InternalTempC; // StdControl
    SamplePlatform.ADCControl       -> HamamatsuC;    // StdControl
    SamplePlatform.HumidityControl  -> HumidityC;// SplitControl
    SamplePlatform.Humidity         -> HumidityC.Humidity;
    SamplePlatform.Temperature      -> HumidityC.Temperature;
    SamplePlatform.TSR              -> HamamatsuC.TSR;
    SamplePlatform.PAR              -> HamamatsuC.PAR;
    SamplePlatform.InternalTemperature -> InternalTempC;
    SamplePlatform.HumidityError    -> HumidityC.HumidityError;
    SamplePlatform.TemperatureError -> HumidityC.TemperatureError;
#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
    SamplePlatform.Photo            -> Photo;
    SamplePlatform.Temperature      -> Temp;
    SamplePlatform.AccelX           -> Accel.AccelX;
    SamplePlatform.AccelY           -> Accel.AccelY;
    SamplePlatform.ADCControl       -> Photo;
    SamplePlatform.ADCControl       -> Temp;
    SamplePlatform.ADCControl       -> Accel;
    SamplePlatform.Timer            -> TimerC.Timer[unique("Timer")];
#elif defined(PLATFORM_MICA2DOT) 
    SamplePlatform.Photo            -> Photo;
    SamplePlatform.Temperature      -> Temp;
    SamplePlatform.ADCControl       -> Photo;
    SamplePlatform.ADCControl       -> Temp;
    SamplePlatform.Timer            -> TimerC.Timer[unique("Timer")];
#else
//#elif PLATFORM_PC
//#elif PLATFORM_IMOTE2
// - no sensors implemented for PC or IMOTE2 platforms
    SamplePlatform.Timer -> TimerC.Timer[unique("Timer")];
#endif

}

