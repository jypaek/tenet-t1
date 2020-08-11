
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */

includes Timer;
includes VBTimeSync;

module VBTimeSyncM
{
	provides {
		interface StdControl;
	}
	uses {
		interface Timer;
#ifdef TIMESYNC_SYSTIME
		interface SysTime;
#else
		interface LocalTime;
#endif
		interface VBTimeSync;
	}
}
implementation {
	enum {
		BEACON_RATE = 30
	};

	uint8_t sendBusy;

	uint32_t getLocalTime() {
#ifdef TIMESYNC_SYSTIME
		return call SysTime.getTime32();
#else
		return call LocalTime.read();
#endif
	}

	task void sendMsg() {
		uint32_t localTime = getLocalTime();

		if (!call VBTimeSync.sendTimeSyncMsg(localTime)) {
			atomic sendBusy = FALSE;
		}
	}

	async event void VBTimeSync.sendDone(result_t success) {
		atomic sendBusy = FALSE;
	}

	event result_t Timer.fired()
	{
		atomic {
			if(!sendBusy) {
				sendBusy = TRUE;
				post sendMsg();
			}
		}
		return SUCCESS;
	}

	command result_t StdControl.init() { 
		atomic sendBusy = FALSE;
		return SUCCESS;
	}

    command result_t StdControl.start() {
		call Timer.start(TIMER_REPEAT, (uint32_t)1000 * BEACON_RATE);
        return SUCCESS; 
    }

	command result_t StdControl.stop() {
		call Timer.stop();
		return SUCCESS; 
	}

}


