
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */

includes VBSRControl;

module BulkLoggerVBwrapperM
{
	provides {
		interface StdControl;
		interface BulkLoggerWrite;
		interface BulkLoggerRead;
	}
	uses {
		interface StdControl as VBStdControl;
		interface VBSRControl;

		interface StdControl as B_LoggerControl;
		interface BulkLoggerWrite as B_LoggerWrite;
		interface BulkLoggerRead as B_LoggerRead;

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

	uint8_t *buffer_ptr;// pointer of the buffer that we are going to write-from/read-to.
	uint16_t line_num;
	uint16_t data_size;
	result_t writeResult_afterResume;	
	result_t readResult_afterResume;	
	uint8_t *readDoneBuffer;

	command result_t StdControl.init() {
		VB_state = VB_SR_S_NORMAL;
		Logger_state = LOGGER_IDLE;
		data_size = 0;
		writeResult_afterResume = SUCCESS;
		readResult_afterResume = SUCCESS;
		call Leds.init();
		call VBStdControl.init();
		return call B_LoggerControl.init();
	}

	command result_t StdControl.start() {
		call VBStdControl.start();
		return call B_LoggerControl.start();
	}

	command result_t StdControl.stop() {
		call VBStdControl.start();
		return call B_LoggerControl.stop();
	}


/////////////////////////////////////////////////////////////////////
// BulkLogger WRITE
/////////////////////////////////////////////////////////////////////

	result_t reportWriteDone(result_t success) {
		if (VB_state == VB_SR_S_SUSPENDED) {
			writeResult_afterResume = success;
			call VBSRControl.resumeSending();
		} else {
			signal BulkLoggerWrite.writeDone(success);
			atomic Logger_state = LOGGER_IDLE;
		}
		return SUCCESS;
	}

	task void _reportWriteDone_FAIL() {
		reportWriteDone(FAIL);
	}

	task void writeLoggerTask() {	// Logger state MUST be LOGGER_WRITE.
		if (call B_LoggerWrite.write(line_num, data_size, buffer_ptr) == FAIL)
			reportWriteDone(FAIL);
	}

	command result_t BulkLoggerWrite.write(uint16_t line, uint8_t size, uint8_t *buffer) {
		if (Logger_state != LOGGER_IDLE)
			return FAIL;
		atomic Logger_state = LOGGER_WRITE;	// Logger in "WRITE" mode.

		line_num = line;
		data_size = size;
		buffer_ptr = buffer;

		if (call VBSRControl.suspendSending() == FAIL) {
			post suspendVBTask();
		} else
			atomic VB_state = VB_SR_S_SUSDONE_WAIT;
		return SUCCESS;
	}

	command result_t BulkLoggerWrite.write_lines(uint16_t line, uint8_t num_lines, uint8_t *buffer) {
		return call BulkLoggerWrite.write(line, 16*num_lines, buffer);
	}

	event result_t B_LoggerWrite.writeDone(result_t success) {
		return 	reportWriteDone(success);
	}

/////////////////////////////////////////////////////////////////////
// Logger READ
/////////////////////////////////////////////////////////////////////

	result_t reportReadDone(uint8_t *buffer, result_t success) {
		data_size = 0;
		if (VB_state == VB_SR_S_SUSPENDED) {
			readResult_afterResume = success;
			readDoneBuffer = buffer;
			call VBSRControl.resumeSending();
		} else {
			signal BulkLoggerRead.readDone(buffer, success);
			atomic Logger_state = LOGGER_IDLE;
		}
		return SUCCESS;
	}

	task void _reportReadDone_FAIL() {
		reportReadDone(buffer_ptr, FAIL);
	}

	task void readLoggerTask() {
		if (call B_LoggerRead.read(line_num, data_size, buffer_ptr) == FAIL)
			reportReadDone(buffer_ptr, FAIL);
	}

	command result_t BulkLoggerRead.read(uint16_t line, uint8_t size, uint8_t *buffer) {
		if (Logger_state != LOGGER_IDLE)
			return FAIL;
		atomic Logger_state = LOGGER_READ;	// Logger in "READ" mode.

		line_num = line;
		data_size = size;
		buffer_ptr = buffer;

		if (call VBSRControl.suspendSending() == FAIL) {
			post suspendVBTask();
		} else
			atomic VB_state = VB_SR_S_SUSDONE_WAIT;
		return SUCCESS;
	}

	command result_t BulkLoggerRead.read_lines(uint16_t line, uint8_t num_lines, uint8_t *buffer) {
		return call BulkLoggerRead.read(line, 16*num_lines, buffer);
	}

	event result_t B_LoggerRead.readDone(uint8_t *buffer, result_t success) {
		return reportReadDone(buffer, success);
	}


/////////////////////////////////////////////////////////////////////
// Suspend & Resume
/////////////////////////////////////////////////////////////////////

	task void suspendVBTask() {
		if (call VBSRControl.suspendSending() == FAIL) {
			post suspendVBTask();
		} else
			VB_state = VB_SR_S_SUSDONE_WAIT;
	}

	async event void VBSRControl.suspendSendingDone(result_t success) {
		if (success)
			atomic VB_state = VB_SR_S_SUSPENDED;	// if SUCCESS, we assume that VB is suspended
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
		signal BulkLoggerWrite.writeDone(writeResult_afterResume);
	}

	task void reportReadDoneAfterResume() {
		atomic Logger_state = LOGGER_IDLE;
		signal BulkLoggerRead.readDone(readDoneBuffer, readResult_afterResume);
	}

	async event void VBSRControl.resumeSendingDone(result_t success) {
		if (success)
			atomic VB_state = VB_SR_S_NORMAL;
		if (Logger_state == LOGGER_WRITE) {
			post reportWriteDoneAfterResume();
		} else if (Logger_state == LOGGER_READ) {
			post reportReadDoneAfterResume();
		}
	}

}

