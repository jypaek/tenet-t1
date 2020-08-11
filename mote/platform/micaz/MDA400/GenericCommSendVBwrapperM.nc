

module GenericCommSendVBwrapperM
{
    provides {
        interface StdControl as Control;
        interface SendMsg[uint8_t id];
    }
    uses {
        interface StdControl as VBStdControl;
        interface VBLock;

        interface StdControl as GC_StdControl;
        interface SendMsg as GC_SendMsg[uint8_t id];
    }
}
implementation
{

    enum {
        VB_UNLOCKED = 1,
        VB_LOCKED,
    };

    uint8_t VB_lock_state;
    bool send_busy = TRUE;   // We want to make sure that "init()" is called.
    TOS_MsgPtr buffer;

    command result_t Control.init() {
        VB_lock_state = VB_UNLOCKED;       // Don't know about VB state
        send_busy = FALSE;
        call VBStdControl.init();
        return call GC_StdControl.init();
    }
    
    command result_t Control.start() {
        call VBStdControl.start();
        return call GC_StdControl.start();
    }

    command result_t Control.stop() {
        call VBStdControl.stop();
        return call GC_StdControl.stop();
    }

    result_t reportSendDone(TOS_MsgPtr msg, result_t success) {
        signal SendMsg.sendDone[msg->type](msg, success);
        atomic send_busy = FALSE;
        if (VB_lock_state == VB_LOCKED) {
            call VBLock.unlock(); 
            VB_lock_state = VB_UNLOCKED;
        }
        return SUCCESS;
    }

/* 
    task void lockAndSendTask() {
        if (!send_busy)
            return;
        if (call VBLock.lock()) {
            VB_lock_state = VB_LOCKED;
            if (!call GC_SendMsg.send[buffer->type](buffer->addr, buffer->length, buffer))
                reportSendDone(buffer, FAIL);
        } else {
            post lockAndSendTask();
        }
    }
*/
    event void VBLock.lockDone() {
        VB_lock_state = VB_LOCKED;
        if (!call GC_SendMsg.send[buffer->type](buffer->addr, buffer->length, buffer))
            reportSendDone(buffer, FAIL);
    }
    
    command result_t SendMsg.send[uint8_t id](uint16_t addr, uint8_t length, TOS_MsgPtr data) {
        if (send_busy)
            return FAIL;
        buffer = data;
        data->length = length;
        data->addr = addr;
        data->type = id;
        /*
        if (call VBLock.lock()) {
            VB_lock_state = VB_LOCKED;
            if (call GC_SendMsg.send[id](addr, length, data)) {
                send_busy = TRUE;
                return SUCCESS;
            }
        } else {
            if (post lockAndSendTask()) {
                send_busy = TRUE;
                return SUCCESS;
            }
        }
        return FAIL;
        */
        call VBLock.lock();
        send_busy = TRUE;
        return SUCCESS;
    }

    event result_t GC_SendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return reportSendDone(msg, success);
    }

    default event result_t SendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }

}

