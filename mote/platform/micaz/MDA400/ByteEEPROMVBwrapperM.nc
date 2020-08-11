
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */

includes VBSRControl;

module ByteEEPROMVBwrapperM
{
	provides {
		interface StdControl;
		interface WriteData[uint8_t id];
		interface ReadData[uint8_t id];
	}
	uses {
		interface StdControl as VBStdControl;
		interface VBSRControl;

		interface StdControl as ByteEEPROMStdControl;
		interface WriteData as WriteDataReal[uint8_t id];
		interface ReadData as ReadDataReal[uint8_t id];

		interface Leds;
	}
}
implementation
{
	task void suspendVBTask();

	enum {
		LOGGER_IDLE,
		LOGGER_READ,
		LOGGER_WRITE
	};

	norace uint8_t VB_state;
	norace uint8_t Logger_state;

	uint8_t *data_buffer;// pointer of the buffer that we are going to write-from/read-to.
	uint32_t data_offset;
	uint32_t data_size;
	uint8_t data_id;
	result_t reportResult_afterResume;	

	command result_t StdControl.init() {
		VB_state = VB_SR_S_NORMAL;
		Logger_state = LOGGER_IDLE;
		data_size = 0;
		reportResult_afterResume = SUCCESS;
		call Leds.init();
		call VBStdControl.init();
		return call ByteEEPROMStdControl.init();
	}

	command result_t StdControl.start() {
		call VBStdControl.start();
		return call ByteEEPROMStdControl.start();
	}

	command result_t StdControl.stop() {
		call VBStdControl.start();
		return call ByteEEPROMStdControl.stop();
	}

    task void resumeVBTask() {
		if (!call VBSRControl.resumeSending()) {
			post resumeVBTask();
		} else
			atomic VB_state = VB_SR_S_RESDONE_WAIT;
    }

/////////////////////////////////////////////////////////////////////
// BulkLogger WRITE
/////////////////////////////////////////////////////////////////////

	result_t reportWriteDone(result_t success) {
		if (VB_state == VB_SR_S_SUSPENDED) {
			reportResult_afterResume = success;
		    if (!call VBSRControl.resumeSending()) {
    			post resumeVBTask();
	    	} else
		    	atomic VB_state = VB_SR_S_RESDONE_WAIT;
		} else {
			signal WriteData.writeDone[data_id](data_buffer, data_size, success);
			atomic Logger_state = LOGGER_IDLE;
		}
		return SUCCESS;
	}

	task void _reportWriteDone_FAIL() {
		reportWriteDone(FAIL);
	}

	task void writeLoggerTask() {	// Logger state MUST be LOGGER_WRITE.
		if (!call WriteDataReal.write[data_id](data_offset, data_buffer, data_size))
			reportWriteDone(FAIL);
	}

	command result_t WriteData.write[uint8_t id](uint32_t offset, uint8_t *buffer, uint32_t size) {
		if ((size == 0) || (size > 160))	// For now, let's limit the size to 160 Bytes.
			return FAIL;
		if (Logger_state != LOGGER_IDLE)
			return FAIL;
		atomic Logger_state = LOGGER_WRITE;	// Logger in "WRITE" mode.
		data_offset = offset;
		data_size = size;
		data_buffer = buffer;
		data_id = id;
		if (!call VBSRControl.suspendSending()) {
			post suspendVBTask();
		} else
			atomic VB_state = VB_SR_S_SUSDONE_WAIT;
		return SUCCESS;
	}

	event result_t WriteDataReal.writeDone[uint8_t id](uint8_t* data, uint32_t nbytes, result_t success) {
		return reportWriteDone(success);
	}


/////////////////////////////////////////////////////////////////////
// Logger READ
/////////////////////////////////////////////////////////////////////

	result_t reportReadDone(result_t success) {
		//if (Logger_state != LOGGER_READ)
		//	INTERNAL_ERROR();
		data_size = 0;
		if (VB_state == VB_SR_S_SUSPENDED) {
			reportResult_afterResume = success;
		    if (!call VBSRControl.resumeSending()) {
    			post resumeVBTask();
	    	} else
		    	atomic VB_state = VB_SR_S_RESDONE_WAIT;
		} else {
			signal ReadData.readDone[data_id](data_buffer, data_size, success);
			atomic Logger_state = LOGGER_IDLE;
		}
		return SUCCESS;
	}

	task void _reportReadDone_FAIL() {
		reportReadDone(FAIL);
	}

	task void readLoggerTask() {
		if (!call ReadDataReal.read[data_id](data_offset, data_buffer, data_size)) {
			reportReadDone(FAIL);
		}
	}

	command result_t ReadData.read[uint8_t id](uint32_t offset, uint8_t *buffer, uint32_t size) {

		if ((size == 0) || (size > 160))	// For now, let's limit the size to 160 Bytes.
			return FAIL;
		if (Logger_state != LOGGER_IDLE)
			return FAIL;
		atomic Logger_state = LOGGER_READ;	// Logger in "READ" mode.

		data_offset = offset;
		data_size = size;
		data_buffer = buffer;

		if (!call VBSRControl.suspendSending()) {
			post suspendVBTask();
		} else
			atomic VB_state = VB_SR_S_SUSDONE_WAIT;
		return SUCCESS;
	}

	event result_t ReadDataReal.readDone[uint8_t id](uint8_t* buffer, uint32_t numBytes, result_t success) {
		return reportReadDone(success);
	}


/////////////////////////////////////////////////////////////////////
// Suspend & Resume
/////////////////////////////////////////////////////////////////////

	task void suspendVBTask() {
		if (call VBSRControl.suspendSending() == FAIL) {
			post suspendVBTask();
		} else
			atomic VB_state = VB_SR_S_SUSDONE_WAIT;
	}

	async event void VBSRControl.suspendSendingDone(result_t success) {
		if (success)
			atomic VB_state = VB_SR_S_SUSPENDED;// if SUCCESS, assume that VB is suspended
		else 
			atomic VB_state = VB_SR_S_NORMAL;	// else, we don't know about VB state

		if (Logger_state == LOGGER_WRITE) {
			if (success) {
				post writeLoggerTask();
			} else {
				post _reportWriteDone_FAIL();
			}
		} else if (Logger_state == LOGGER_READ) {
			if (success) {
				post readLoggerTask();
			} else {
				post _reportReadDone_FAIL();
			}
		}
	}

	task void reportWriteDoneAfterResume() {
		atomic Logger_state = LOGGER_IDLE;
		signal WriteData.writeDone[data_id](data_buffer, data_size, reportResult_afterResume);
	}

	task void reportReadDoneAfterResume() {
		atomic Logger_state = LOGGER_IDLE;
		signal ReadData.readDone[data_id](data_buffer, data_size, reportResult_afterResume);
	}

	async event void VBSRControl.resumeSendingDone(result_t success) {
        if (success) {
    		atomic VB_state = VB_SR_S_NORMAL;
            if (Logger_state == LOGGER_WRITE) {
                post reportWriteDoneAfterResume();
            } else if (Logger_state == LOGGER_READ) {
                post reportReadDoneAfterResume();
            }
        } else {
		    atomic VB_state = VB_SR_S_SUSPENDED;
            post resumeVBTask();
        }
	}

	default event result_t WriteData.writeDone[uint8_t id](uint8_t* data, uint32_t nbytes, result_t success) {
		return SUCCESS;
	}
	default event result_t ReadData.readDone[uint8_t id](uint8_t* buffer, uint32_t nbytes, result_t success) {
		return SUCCESS;
	}
}

