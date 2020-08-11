
/*
 * VBoard Controller module for Crossbow's MDA400
 *
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified July/19/2005
 */

includes VBSRControl;

module MDA400ControlM {  
    provides {
        interface StdControl;
        interface MDA400I as MDA400Control;
        interface VBSRControl[uint8_t id];
        interface VBLock;
        interface VBTimeSync;
    }
    uses {
        interface StdControl as VBStdControl;
        interface MDA400I as MDA400Real;
        interface VBSRControl as MDA400SRControl;

        interface StdControl as VBTSStdControl;
        interface VBTimeSync as MDA400TimeSync;
        interface Leds;
    }
}
implementation { 

    enum {
        VB_S_IDLE = 0x01,
        
        VB_S_BUSY = 0x02, // Busy means that we have sent a command to the mda400,
                          // and has not received 'done' event yet.

        VB_S_SAMPLING = 0x04,
        VB_S_CONT_SAMPLING = 0x08,

        VB_S_LOCK = 0x10,

        VB_S_SUSPEND_WAIT = 0x20,
        VB_S_SUSPENDED = 0x40,
        VB_S_RESUME_WAIT = 0x80,
    };

    norace uint8_t VBState;
    enum {
        //SR_REQ_MAX_TYPES = uniqueCount("VB_SR_REQ")
        SR_REQ_MAX_TYPES = 2
    };
    norace uint8_t SR_ReqState[SR_REQ_MAX_TYPES];
    norace uint8_t lock_pending;

    command result_t StdControl.init() {
        int i;
        for (i = 0; i < SR_REQ_MAX_TYPES; i++)
            SR_ReqState[i] = VB_SR_S_NORMAL;
        atomic VBState = VB_S_IDLE;
        call VBStdControl.init();
        call VBTSStdControl.init();
        call MDA400Real.init();  
        call Leds.init();
        lock_pending = 0;
        return SUCCESS;
    }
    
    command result_t StdControl.start() {
        call VBStdControl.start();
        return SUCCESS;
    }
    
    command result_t StdControl.stop() {
        call MDA400Real.stopSampling();
        atomic VBState = VB_S_IDLE;     // do we need to poweroff?
        call VBStdControl.stop(); 
        return SUCCESS;
    }

    command result_t MDA400Control.init() {
        atomic VBState = VB_S_IDLE;
        return call MDA400Real.init();  
    }

    task void signal_lock_done() {
        lock_pending = 0;
        signal VBLock.lockDone();
    }
    
    void set_busy() {
        atomic VBState |= VB_S_BUSY;
    }

    void unset_busy() {
        if (lock_pending == 1) {
            VBState |= VB_S_LOCK;
            lock_pending = 2;
            post signal_lock_done();
        }
        atomic VBState &= ~VB_S_BUSY;
    }

    command result_t MDA400Control.powerOn() {
        if ((VBState != VB_S_IDLE) &&
            (call MDA400Real.powerOn())) {
            set_busy();
            return SUCCESS;
        }
        return FAIL;
    }

    event void MDA400Real.powerOnDone(result_t success) {
        unset_busy();
        signal MDA400Control.powerOnDone(success);
    }

    command result_t MDA400Control.powerOff() {
        if ((VBState != VB_S_IDLE) &&
            (call MDA400Real.powerOff())) {
            set_busy();
            return SUCCESS;
        }
        return FAIL;
    }

    event void MDA400Real.powerOffDone(result_t success) {
        unset_busy();
        signal MDA400Control.powerOffDone(success);
    }

    /* VB must be in IDLE state to start sampling.
         - init() and powerOn() must be called before calling startSampling.
         - stopSamping() might be needed if it had started before. */

    command result_t MDA400Control.startSampling(uint16_t s_period, 
                                                 uint8_t ch_sel, 
                                                 uint16_t num_ks_per_ch, 
                                                 uint8_t onset_det) {
        if (VBState != VB_S_IDLE)
            return FAIL;
        if (call MDA400Real.startSampling(s_period, ch_sel, num_ks_per_ch, onset_det)) {
            atomic VBState = VB_S_SAMPLING;
            set_busy();
            return SUCCESS;
        }
        return FAIL;
    }

    command result_t MDA400Control.startContinuousSampling(uint16_t s_period,
                                                           uint8_t ch_sel,
                                                           uint8_t onset_det) {
        if (VBState != VB_S_IDLE)
            return FAIL;
        if (call MDA400Real.startContinuousSampling(s_period, ch_sel, onset_det)) {
            atomic VBState = VB_S_CONT_SAMPLING;
            set_busy();
            if (onset_det)
                call VBTSStdControl.start();
            return SUCCESS;
        }
        return FAIL;
    }

    event void MDA400Real.startSamplingDone(result_t success) {
        unset_busy();
        if (!success) {
            if (VBState & VB_S_CONT_SAMPLING)
                call VBTSStdControl.stop();
            atomic VBState = VB_S_IDLE;
        }
        signal MDA400Control.startSamplingDone(success);
    }

    command result_t MDA400Control.stopSampling() {     
        if ((VBState == VB_S_SAMPLING) || 
            (VBState == VB_S_CONT_SAMPLING) ||
            (VBState == VB_S_IDLE)) {
            // no BUSY, no LOCK
            if (call MDA400Real.stopSampling()) {
                set_busy();
                return SUCCESS;
            }
        }
        return FAIL;
    }

    event void MDA400Real.stopSamplingDone(result_t success) {
        unset_busy();
        if (success) {
            atomic {
                if (VBState & VB_S_CONT_SAMPLING) {
                    call VBTSStdControl.stop();
                }
                VBState = VB_S_IDLE;
            }
        }
        signal MDA400Control.stopSamplingDone(success);
    }

    task void sig_suspendDone_now() {
        int id;
        for (id = 0; id < SR_REQ_MAX_TYPES; id++) {
            if (SR_ReqState[id] == VB_SR_S_SUSDONE_NOW) {
                signal VBSRControl.suspendSendingDone[id](SUCCESS);
                atomic SR_ReqState[id] = VB_SR_S_SUSPENDED;
            }
        }
    }

    command result_t VBLock.lock() {
        result_t ok = SUCCESS;
        atomic {
            if (lock_pending != 0) {
                ok = FAIL;
            } else if (!(VBState & VB_S_BUSY)) {
                VBState |= VB_S_LOCK;
                lock_pending = 2;
                post signal_lock_done();
            } else {
                lock_pending = 1;
            }
        }
        return ok;
    }

    command void VBLock.unlock() {
        atomic VBState &= ~VB_S_LOCK;
    }

    /* suspendSending
        - Caller request for suspendSending.
        - Caller wants to hear suspendSendingDone so that it can do it's work.
        - If VB is already suspended, we immediately signal back.
    */
    command result_t VBSRControl.suspendSending[uint8_t id]() {

        if (VBState & VB_S_RESUME_WAIT) { // Must process resume command first!!
            return FAIL;
        } else if (VBState & VB_S_SUSPEND_WAIT) {
            atomic SR_ReqState[id] = VB_SR_S_SUSDONE_WAIT;
        } else if (VBState & VB_S_SUSPENDED) { 
            atomic SR_ReqState[id] = VB_SR_S_SUSDONE_NOW;
            post sig_suspendDone_now();
        } else if (VBState & VB_S_BUSY) { // busy but not already suspended nor susdone wait
            return FAIL;
        } else if (VBState & VB_S_LOCK) { // cannot send command
            return FAIL;
        } else {    // VBState == (IDLE || CONT_SAMPLING || SAMPLING)
            if (call MDA400SRControl.suspendSending()) {
                set_busy();
                atomic {
                    VBState |= VB_S_SUSPEND_WAIT;    // 'OR' the SUS_WAIT state
                    SR_ReqState[id] = VB_SR_S_SUSDONE_WAIT;
                }
            } else
                return FAIL;
        }
        return SUCCESS;
    } 

    async event void MDA400SRControl.suspendSendingDone(result_t success) {
        int id;
        unset_busy();
        atomic {
            VBState &= ~VB_S_SUSPEND_WAIT;
            if (success) {
                VBState |= VB_S_SUSPENDED;
            }
        }
        for (id = 0; id < SR_REQ_MAX_TYPES; id++) {
            if ((SR_ReqState[id] == VB_SR_S_SUSDONE_WAIT) ||
                    (SR_ReqState[id] == VB_SR_S_SUSDONE_NOW)) {
                signal VBSRControl.suspendSendingDone[id](success);
                if (success)
                    SR_ReqState[id] = VB_SR_S_SUSPENDED;
                else
                    SR_ReqState[id] = VB_SR_S_NORMAL;
            }
        }
    }

    task void sig_resumeDone_now() {
        int id;
        for (id = 0; id < SR_REQ_MAX_TYPES; id++) {
            if (SR_ReqState[id] == VB_SR_S_RESDONE_WAIT) {
                signal VBSRControl.resumeSendingDone[id](SUCCESS);
                atomic SR_ReqState[id] = VB_SR_S_NORMAL;
            }
        }
    }

    /* resumeSending
        - Caller requests for resumeSending.
        - Actually, caller does not care whether VB is resumed.
        - Caller only cares about whether VB is really suspended or not.
        - Being in suspend state is fine for the caller.
    */
    command result_t VBSRControl.resumeSending[uint8_t id]() {
        bool proceedResume1 = TRUE, proceedResume2 = FALSE;
        
        if (VBState & VB_S_SUSPEND_WAIT) { // going to be suspended soon.
            // so, failed in resuming, but caller does not really care.
            return FAIL;
        } else if (VBState & VB_S_RESUME_WAIT) {// VB is going to be resumed soon.
            atomic SR_ReqState[id] = VB_SR_S_RESDONE_WAIT;
        } else if (VBState & VB_S_SUSPENDED) {    // VB suspended,
            if (VBState & VB_S_BUSY) { // busy but not already suspended nor susdone wait
                return FAIL;
            } else if (VBState & VB_S_LOCK) { // cannot send command
                return FAIL;
            }
            atomic SR_ReqState[id] = VB_SR_S_RESDONE_WAIT;
            for (id = 0; id < SR_REQ_MAX_TYPES; id++) {
                if (SR_ReqState[id] == VB_SR_S_RESDONE_WAIT)
                    proceedResume2 = TRUE;
                else if (SR_ReqState[id] != VB_SR_S_NORMAL)
                    proceedResume1 = FALSE;
            }
            if (proceedResume1 && proceedResume2) { // let's resume if nobody wants suspend
                if (call MDA400SRControl.resumeSending()) {
                    set_busy();
                    atomic {
                        VBState &= ~VB_S_SUSPENDED;
                        VBState |= VB_S_RESUME_WAIT;
                    }
                } else 
                    return FAIL;    // still in suspend state...
            }
        } else { // IDLE || CONT_SAMPLING
            atomic SR_ReqState[id] = VB_SR_S_RESDONE_WAIT;
            post sig_resumeDone_now();
        }
        return SUCCESS;     
    } 

    async event void MDA400SRControl.resumeSendingDone(result_t success) {
        uint8_t id;
        unset_busy();
        atomic {
            VBState &= ~VB_S_RESUME_WAIT;
            if (!success)
                VBState |= VB_S_SUSPENDED;  // suspended if resume fail??
        }
        for (id = 0; id < SR_REQ_MAX_TYPES; id++) {
            if (SR_ReqState[id] == VB_SR_S_RESDONE_WAIT) {
                signal VBSRControl.resumeSendingDone[id](success);
                if (success)
                    SR_ReqState[id] = VB_SR_S_NORMAL;
                else
                    SR_ReqState[id] = VB_SR_S_SUSPENDED;
            }
        }
    }

    command result_t MDA400Control.getData(uint8_t ch_num, uint8_t num_samples, uint16_t sample_offset) {
        if ((VBState == VB_S_IDLE) || (VBState == VB_S_CONT_SAMPLING)) {
            if (call MDA400Real.getData(ch_num, num_samples, sample_offset)) {
                set_busy();
                return SUCCESS;
            }
        }
        return FAIL;
    }
                                                                                    
    command result_t MDA400Control.getNextEventData(uint8_t ch_num, uint8_t num_samples) {
        if ((VBState == VB_S_IDLE) || (VBState == VB_S_CONT_SAMPLING)) {
            if (call MDA400Real.getNextEventData(ch_num, num_samples)) {
                set_busy();
                return SUCCESS;
            }
        }
        return FAIL;
    }

    command result_t MDA400Control.getNextAvailData(uint8_t ch_num, uint8_t num_samples) {
        if ((VBState == VB_S_IDLE) || (VBState == VB_S_CONT_SAMPLING)) {
            if (call MDA400Real.getNextAvailData(ch_num, num_samples)) {
                set_busy();
                return SUCCESS;
            }
        }
        return FAIL;
    }

    event void MDA400Real.dataReady(uint8_t num_bytes, uint8_t *data) {
        unset_busy();
        signal MDA400Control.dataReady(num_bytes, data);
    }

    event void MDA400Real.nextEventDataReady(uint8_t num_bytes, uint8_t *data, uint32_t timestamp) {
        unset_busy();
        signal MDA400Control.nextEventDataReady(num_bytes, data, timestamp);
    }

    event void MDA400Real.nextAvailDataReady(uint8_t num_bytes, uint8_t *data) {
        unset_busy();
        signal MDA400Control.nextAvailDataReady(num_bytes, data);
    }

    /* VB must have been in 'SAMPLING' state.
       No other state is possible
       So, we go back to 'IDLE' state. */
    event void MDA400Real.samplingComplete() {
        atomic VBState &= ~VB_S_SAMPLING;
        atomic VBState |= VB_S_IDLE;
        signal MDA400Control.samplingComplete();
    }
 
    command result_t VBTimeSync.sendTimeSyncMsg(uint32_t currentTime) {
        if ((VBState == VB_S_IDLE) || (VBState == VB_S_CONT_SAMPLING)) {
            if (call MDA400TimeSync.sendTimeSyncMsg(currentTime)) {
                set_busy();
                return SUCCESS;
            }
        }
        return FAIL;
    }

    async event void MDA400TimeSync.sendDone(result_t success) {
        unset_busy();
        signal VBTimeSync.sendDone(success);
    }       

    default event void MDA400Control.startSamplingDone(result_t success){}
    default event void MDA400Control.stopSamplingDone(result_t success){}
    default async event void VBSRControl.suspendSendingDone[uint8_t id](result_t success){}
    default async event void VBSRControl.resumeSendingDone[uint8_t id](result_t success){}
    default event void MDA400Control.powerOnDone(result_t success){}
    default event void MDA400Control.powerOffDone(result_t success){}
    default event void MDA400Control.dataReady(uint8_t num_bytes, uint8_t *data) {}
    default event void MDA400Control.nextEventDataReady(uint8_t num_bytes, 
                                            uint8_t *data, uint32_t timestamp){}
    default event void MDA400Control.nextAvailDataReady(uint8_t num_bytes, uint8_t *data){}
    default event void MDA400Control.samplingComplete() {}
    default async event void VBTimeSync.sendDone(result_t success) {}

}

