/*									tab:4
 * Copyright (c) 2003 by Sensicast, Inc.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the (updated) modification history and the author appear in
 * all copies of this source code.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 * 
 * All rights reserved.
 */
#define PhotoTempMedit 3
/*
 * Modification History:
 *  11Nov03 MJNewman 3: TinyOS 1.1 atomic updates.
 *  20Oct03 MJNewman 2:	Redo copyright and initial comments.
 *   7May03 MJNewman 1:	Add proper delays when sensor is switched.
 *			It is important to wait about 10ms from
 *			starting a sensor to reading data from the
 *			sensor.
 *   7May03 MJNewman 1:	Created.
 *
 * This module is a rewrite of the PhotoTempM.nc module written by
 * Jason Hill, David Gay and Philip Levis. This module solves
 * fundamental sampling problems in their module having to do with
 * waiting for logic to settle when changing between the photo and
 * temperature sensors.
 * 
 * ISSUE: Continuous data in ADCC is supposed to sample at some rate
 * controlled by ADCControl.setSamplingRate. The original PhotoTemp
 * example does not appear to do this. No support has been added. The
 * implementation of getContinuousData in the current code will sample
 * as fast as it can. When both Photo and Temp samples are requested
 * they will alternate producing one sample every 10 ms.
 */

// OS component abstraction of the analog photo sensor and temperature
// sensor with associated A/D support. This code provides an
// asynchronous interface to the photo and temperature sensors. One
// TimerC timer is used, certain forms of clock use are not compatible
// with using a timer. (i.e. the ClockC component)
//
// It is important to note that the temperature and photo sensors share
// hardware and can not be used at the same time. Proper delays are
// implemented here. Using ExternalXxxADC.getData will initiate the
// appropriate delays prior to sampling data. getData for temperature
// and light may both be invoked in any order and at any time. A
// correct sample will be signalled by the corresponding dataReady.
//
// Photo and Temp provide the same interfaces. Exposed interfaces are
// ExternalPhotoADC and ExternalTempADC as well as TempStdControl and
// PhotoStdControl. The following routines are the public interface:
//
// xxxStdControl.init	initializes the device
// xxxADC.start		starts a particular sensor
// xxxADC.stop		stops a particular sensor, this will also stop
//			any getContinuousData on that sensor.
// xxxADC.getData	reads data from a sensor. This may be called in
//			any order. A dataReady event is signalled
//			when the data is ready. Temperature and Photo
//			will wait for each other as needed.
// xxxADC.getContinuousData	reads data from a sensor and when the
//			read completes triggers an additional getData.
//			Continuous data from both sensors will work but
//			a 10 ms delay will occur between each sample.
//			Continuous data from a single sensor will run
//			at a higher sampling rate.
//
// A timer from TimerC is used to manage the delays required between
// setting up the hardware and reading the data.

includes sensorboard;

module PhotoTempM {
    provides interface StdControl as TempStdControl;
    provides interface StdControl as PhotoStdControl;
    provides interface ADC as ExternalPhotoADC;
    provides interface ADC as ExternalTempADC;
    uses {
	interface ADCControl;
	interface ADC as InternalPhotoADC;
	interface ADC as InternalTempADC;
	interface StdControl as TimerControl;
	interface Timer as PhotoTempTimer;
    }
}

implementation {

    // Logs what the hardware is set up to do.
    enum {
	sensorIdle = 0,
	sensorPhotoStarting,
	sensorPhotoReady,
	sensorTempStarting,
	sensorTempReady,
    } hardwareStatus;

    // Logs what a particular sensor is trying to do. When a single
    // read completes the value reverts to idle.
    typedef enum {
	stateIdle = 0,
	stateReadOnce,
	stateContinuous,
    } SensorState_t;
    SensorState_t photoSensor;
    SensorState_t tempSensor;

    // TRUE when waiting for a sample to be read and another sample can
    // not start. getSample will always be triggered again when this is
    // true.
    bool waitingForSample;
	//port settings
	uint8_t gDDRE, gPORTE;

    command result_t PhotoStdControl.init() {
	call ADCControl.bindPort(TOS_ADC_PHOTO_PORT, TOSH_ACTUAL_PHOTO_PORT);
	call TimerControl.init();
	atomic {
	    photoSensor = stateIdle;
	};
	dbg(DBG_BOOT, "PHOTO initialized.\n");    
	return call ADCControl.init();
    }

    command result_t PhotoStdControl.start() {
	atomic {
	    photoSensor = stateIdle;
		//save PORTE settings - and restore on exit
		gDDRE = inp(DDRE);
		gPORTE = inp(PORTE);
	};
	return SUCCESS;
    }

    command result_t PhotoStdControl.stop() {
	atomic {
	    photoSensor = stateIdle;
		// and restore on exit
		outp(gDDRE,DDRE);
		outp(gPORTE,PORTE);
	};
	return SUCCESS;
    }

    command result_t TempStdControl.init() {
	call ADCControl.bindPort(TOS_ADC_TEMP_PORT, TOSH_ACTUAL_TEMP_PORT);
	call TimerControl.init();
	atomic {
	    tempSensor = stateIdle;
	};
	dbg(DBG_BOOT, "TEMP initialized.\n");    
	return call ADCControl.init();
    }

    command result_t TempStdControl.start() {
	atomic {
	    tempSensor = stateIdle;
		//save PORTE settings - and restore on exit
		gDDRE = inp(DDRE);
		gPORTE = inp(PORTE);

	};
	return SUCCESS;
    }

    command result_t TempStdControl.stop() {
	atomic {
	    tempSensor = stateIdle;
		// and restore on exit
		outp(gDDRE,DDRE);
		outp(gPORTE,PORTE);
	};
	return SUCCESS;
    }

    // Gets the next sample. Deals with which sample to get now
    task void getSample() {
	static bool photoIsNext;	// which sample to take next
	bool isDone;
	isDone = FALSE;
	atomic {
	    if (waitingForSample){
		// already doing something just wait for the timer to
		// complete
		isDone = TRUE;
	    };
	    if ((photoSensor == stateIdle) && (tempSensor == stateIdle)) {
		// Nothing to do.
		isDone = TRUE;
	    };
	    // When a sensor is idle the other sensor can start without
	    // waiting.
	    if (photoSensor == stateIdle) photoIsNext = FALSE;
	    if (tempSensor == stateIdle) photoIsNext = TRUE;
	};
	if (isDone) {
	    return;
	};
	if (photoIsNext) {
	    // Time to take a light sample.
	    switch (hardwareStatus) {
		case sensorIdle:
		case sensorTempReady:
		    hardwareStatus = sensorPhotoStarting;
		    TOSH_SET_PHOTO_CTL_PIN();
		    TOSH_MAKE_PHOTO_CTL_OUTPUT();
		    TOSH_CLR_TEMP_CTL_PIN();
		    TOSH_MAKE_TEMP_CTL_INPUT();
		    call PhotoTempTimer.stop(); // just in case
		    atomic {
			waitingForSample = TRUE;
		    };
		    photoIsNext = FALSE;
		    if (call PhotoTempTimer.start(TIMER_ONE_SHOT, 10) != SUCCESS) {
			hardwareStatus = sensorIdle;
			post getSample();
		    };
		    return;
		case sensorPhotoReady:
		    atomic {
			waitingForSample = TRUE;
		    };
		    if (call InternalPhotoADC.getData() == SUCCESS) {
			photoIsNext = FALSE;
		    } else {
			post getSample();
		    };
		    return;
		case sensorPhotoStarting:
		    // This case is a bug in the calling application, it
		    // has asked for another photo sample without waiting
		    // for the results of the previous sample.
		case sensorTempStarting:
		    // These are responsible for sampling again when
		    // the timer ticks
		    return;
	    };
	};
	if (!photoIsNext) {
	    // Time to take a temperature sample.
	    switch (hardwareStatus) {
		case sensorIdle:
		case sensorPhotoReady:
		    hardwareStatus = sensorTempStarting;
		    TOSH_CLR_PHOTO_CTL_PIN();
		    TOSH_MAKE_PHOTO_CTL_INPUT();
		    TOSH_SET_TEMP_CTL_PIN();
		    TOSH_MAKE_TEMP_CTL_OUTPUT();
		    call PhotoTempTimer.stop(); // just in case
		    atomic {
			waitingForSample = TRUE;
		    };
		    photoIsNext = TRUE;
		    if (call PhotoTempTimer.start(TIMER_ONE_SHOT, 10) != SUCCESS) {
			hardwareStatus = sensorIdle;
			post getSample();
		    };
		    return;
		case sensorTempReady:
		    atomic {
			waitingForSample = TRUE;
		    };
		    if (call InternalTempADC.getData() == SUCCESS) {
			photoIsNext = TRUE;
		    } else {
			post getSample();
		    };
		    return;
		case sensorTempStarting:
		    // This case is a bug in the calling application, it
		    // has asked for another photo sample without waiting
		    // for the results of the previous sample.
		case sensorPhotoStarting:
		    // These are responsible for sampling again when
		    // the timer ticks
		    return;
	    };
	};
	photoIsNext = (!photoIsNext);
	return;
    }


    // After waiting a little we can take a reading
    event result_t PhotoTempTimer.fired() {
	switch (hardwareStatus) {
	    case sensorIdle:
	    case sensorTempReady:
	    case sensorPhotoReady:
		// Getting here is probably a bug
		break;
	    case sensorPhotoStarting:
		hardwareStatus = sensorPhotoReady;
		if (call InternalPhotoADC.getData() == SUCCESS) {
		    // Trigger the read which will post a new sample
		    return SUCCESS;
		};
		break;
	    case sensorTempStarting:
		hardwareStatus = sensorTempReady;
		if (call InternalTempADC.getData() == SUCCESS) {
		    // Trigger the read which will post a new sample
		    return SUCCESS;
		};
		break;
	};
	// Failure of some sort try to sample again
	atomic {
	    waitingForSample = FALSE;
	};
	post getSample();
	return SUCCESS;
    }

    async command result_t ExternalPhotoADC.getContinuousData(){
	atomic {
	    photoSensor = stateContinuous;
	};
	post getSample();
	return SUCCESS;
    }

    async command result_t ExternalPhotoADC.getData(){
	atomic {
	    photoSensor = stateReadOnce;
	};
	post getSample();
	return SUCCESS;
    }

    async command result_t ExternalTempADC.getData(){
	atomic {
	    tempSensor = stateReadOnce;
	};
	post getSample();
	return SUCCESS;
    }

    async command result_t ExternalTempADC.getContinuousData(){
	atomic {
	    tempSensor = stateContinuous;
	};
	post getSample();
	return SUCCESS;
    }

    default async event result_t ExternalPhotoADC.dataReady(uint16_t data) {
	return SUCCESS;
    }

    async event result_t InternalPhotoADC.dataReady(uint16_t data){
	atomic {
	    waitingForSample = FALSE;
	    switch (photoSensor) {
		default:
		case stateIdle:
		// Getting here with the sensor idle is probably a bug
		case stateReadOnce:
		    photoSensor = stateIdle;
		    break;
		case stateContinuous:
		    break;
	    };
	};
	post getSample();
	return signal ExternalPhotoADC.dataReady(data);
    }

    default async event result_t ExternalTempADC.dataReady(uint16_t data) {
	return SUCCESS;
    }

    async event result_t InternalTempADC.dataReady(uint16_t data){
	atomic {
	    waitingForSample = FALSE;
	    switch (tempSensor) {
		default:
		case stateIdle:
		// Getting here with the sensor idle is probably a bug
		case stateReadOnce:
		    tempSensor = stateIdle;
		    break;
		case stateContinuous:
		    break;
	    };
	};
	post getSample();
	return signal ExternalTempADC.dataReady(data);
    }

}
