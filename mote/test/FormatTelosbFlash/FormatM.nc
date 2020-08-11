

/**
 * When programmed to the telosb mote, this will format the flash and
 * re-partition it to have 12 volumes (0~11).
 *
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 **/

includes FormatTelosbFlash;

module FormatM {
	provides {
		interface StdControl;
	}
	uses {
		interface Leds;
		interface FormatStorage;
	}
}

implementation {

	void rcheck(result_t ok) {
		if (ok == FAIL)
			call Leds.redOn();
	}

	command result_t StdControl.init() {
		call Leds.init();
		return SUCCESS;
	}

	command result_t StdControl.start() {
	    call Leds.yellowOn();

	#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
	    rcheck(call FormatStorage.init());
		rcheck(call FormatStorage.allocate(VOL_ID0, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID1, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID2, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID3, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID4, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID5, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID6, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID7, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID8, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID9, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID10, VOL_SIZE));
		rcheck(call FormatStorage.allocate(VOL_ID11, VOL_SIZE));
		//call FormatStorage.allocateFixed(0xDF, 0xF0000, VOL_SIZE);
		rcheck(call FormatStorage.commit());
	#endif
		return SUCCESS;
	}

	command result_t StdControl.stop() {
		return SUCCESS;
	}

	event void FormatStorage.commitDone(storage_result_t result) {
		if (result == STORAGE_OK) {
			call Leds.greenOn();
		} else
			call Leds.redOn();
	}

}

