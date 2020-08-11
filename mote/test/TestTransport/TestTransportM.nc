
#include "testtransporttask.h"

module TestTransportM
{
    provides {
        interface StdControl;
    }
    uses {
        interface TransportSend as PktTrSend;
        interface TransportSend as PktTrNoAckSend;
        interface PacketTransportReceive;
        interface TRD_Transport;
        interface ConnectionSend as StreamTransportSend;
        interface RcrtSend as RcrTransportSend;
        interface Timer as TaskTimer1;
        interface Timer as TaskTimer2;
        interface Timer as StateTimer;
        interface LocalTime;
        interface LocalTimeInfo;
        interface ParentControl;
        interface RoutingTable;
        interface Leds;
        interface RetransmitControl;
    }
}

implementation
{
    TOS_Msg pingMsg, retxMsg;
    uint16_t last_task_tid;
    uint16_t last_task_addr;
    uint8_t m_state;

    struct taskInfo {
        uint16_t    tid;
        uint16_t    toAddr;
        uint8_t     cid;
        uint8_t     transport_type;
        uint32_t    start_time;
        uint32_t    interval;   // let's only use 16bit of this
        uint32_t    num_packets;
        uint32_t    sentcnt;
        uint16_t    send_pending;
        bool        sendbusy;
        uint8_t     t_state;
        TOS_Msg     msgbuf; 
        uint8_t     option;
    };

    struct taskInfo t[2];

    enum {
        T_S_IDLE = 1,
        T_S_OPEN,
        T_S_OPEN_WAIT,
        T_S_TIME_WAIT,
        T_S_RUNNING,
        T_S_SEND,
        T_S_PINGACK_WAIT,
        T_S_RETXACK_WAIT,

        M_S_IDLE,
        M_S_REBOOT_WAIT,
    };

    void reset_task(int i) {
        t[i].t_state = T_S_IDLE;
        t[i].tid = 0;
        t[i].cid = 0xff;
        t[i].sentcnt = 0;
        t[i].send_pending = 0;
        t[i].sendbusy = FALSE;
    }

    /* let's do Deluge-like bootup led flashing !! (function from deluge) */
    void startupLeds() {
        uint8_t a = 0x7;
        int i, j, k;
        for (i = 3; i; i--, a >>= 1 ) {
            for (j = 1536; j > 0; j -= 4) {
                call Leds.set(a);
                for (k = j; k > 0; k--);
                call Leds.set(a >> 1);
                for (k = 1536-j; k > 0; k--);
            }
        }
    }

    command result_t StdControl.init() {
        m_state = M_S_IDLE;
        last_task_tid = 0;
        last_task_addr = 0;
        reset_task(0);
        reset_task(1);
        call Leds.init();
        startupLeds();
        return SUCCESS;
    }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    int cid2i(uint8_t cid) {
        if ((t[0].tid > 0) && (t[0].cid == cid)) return 0;
        if ((t[1].tid > 0) && (t[1].cid == cid)) return 1;
        return -1;
    }
    int tid2i(uint16_t tid) {
        if ((t[0].tid > 0) && (t[0].tid == tid)) return 0;
        if ((t[1].tid > 0) && (t[1].tid == tid)) return 1;
        return -1;
    }

    void set_start_timer(int i) {
        uint32_t time_to_start = t[i].start_time + 1024;
        if ((i != 0) && (i != 1)) return;
        t[i].t_state = T_S_TIME_WAIT;
        if (i == 0)
            call TaskTimer1.start(TIMER_ONE_SHOT, time_to_start);
        else
            call TaskTimer2.start(TIMER_ONE_SHOT, time_to_start);
    }

    task void open_connection() {
        int i;
        if (t[0].t_state == T_S_OPEN) i = 0;
        else if (t[1].t_state == T_S_OPEN) i = 1;
        else return;
        t[i].t_state = T_S_OPEN_WAIT;

        if (t[i].transport_type <= 1) { // if packet transport, do nothing
            t[i].cid = t[i].tid;
        } else if (t[i].transport_type == 2) { // if stream transport,
            t[i].cid = call StreamTransportSend.open(t[i].tid, t[i].toAddr);
        } else if (t[i].transport_type == 3) { // if rcr transport,
            t[i].cid = call RcrTransportSend.open(t[i].tid, t[i].toAddr, (uint16_t)t[i].interval);
        }
        if (t[i].cid == 0xff) {
            reset_task(i);
            call Leds.redOn();
        }
        post open_connection();
    }
    
    task void sendPingAck() {
        task_msg_t *tMsg;
        uint16_t parent = call RoutingTable.getParent();
        int i;
        if (t[0].t_state == T_S_PINGACK_WAIT) i = 0;
        else if (t[1].t_state == T_S_PINGACK_WAIT) i = 1;
        else return;

        tMsg = (task_msg_t *)pingMsg.data;

        tMsg->type = TASK_MSG_TYPE_DATA;
        tMsg->data[0] = (uint8_t)(parent&0x00ff);
        tMsg->data[1] = (uint8_t)((parent>>8)&0x00ff);
        tMsg->data[2] = call RoutingTable.getDepth();
        tMsg->data[3] = 0;

        pingMsg.length = 4 + offsetof(task_msg_t, data);
        if (call PktTrSend.send(t[i].tid, t[i].toAddr, pingMsg.length, pingMsg.data)) {
            reset_task(i);
        } else {
            post sendPingAck();
        }
    }

    task void sendRetxAck() {
        task_msg_t *tMsg;
        int8_t retx = call RetransmitControl.getNumRetransmit();
        int i;
        if (t[0].t_state == T_S_RETXACK_WAIT) i = 0;
        else if (t[1].t_state == T_S_RETXACK_WAIT) i = 1;
        else return;

        tMsg = (task_msg_t *)retxMsg.data;

        tMsg->type = TASK_MSG_TYPE_DATA;
        tMsg->data[0] = retx;
        tMsg->data[1] = 0;

        retxMsg.length = 2 + offsetof(task_msg_t, data);

        if (call PktTrSend.send(t[i].tid, t[i].toAddr, retxMsg.length, retxMsg.data)) {
            reset_task(i);
        } else {
            post sendRetxAck();
        }
    }

    void stop_task(int i) {
        if ((i != 0) && (i != 1)) return;
        if (i == 0)
            call TaskTimer1.stop();
        else
            call TaskTimer2.stop();

        if (t[i].transport_type <= 1) {
            // do nothing
        }
        else if (t[i].transport_type == 2)
            call StreamTransportSend.close(t[i].cid);// must close first,
        else if (t[i].transport_type == 3)
            call RcrTransportSend.close(t[i].cid);// must close first,
        reset_task(i);
        call Leds.redOff();
        call Leds.yellowOff();
        call Leds.greenOff();
    }

    void tasking_packet_received(uint16_t tid, uint16_t srcAddr, void *payload, uint16_t len) {
        task_msg_t *tMsg = (task_msg_t *) payload;

        if (tMsg->type == TASK_MSG_TYPE_TEST_TRANSPORT_TASK) {
            testTransportCmd *cmd = (testTransportCmd *) tMsg->data;
            int i;
            
            if (t[0].t_state == T_S_IDLE) i = 0;
            else if (t[1].t_state == T_S_IDLE) i = 1;
            else return;

            if ((tid == last_task_tid) && (srcAddr == last_task_addr)) return;
            last_task_tid = tid;
            last_task_addr = srcAddr;

            t[i].tid = tid;
            t[i].toAddr = srcAddr;
            t[i].transport_type = cmd->transport_type;
            t[i].option = cmd->option;
            t[i].start_time = cmd->start_time;
            t[i].num_packets = cmd->num_packets;
            t[i].interval = cmd->interval;
            
            if ((t[i].transport_type >= 2) && (t[i].transport_type <= 4)) { // if connection transport,
                post open_connection(); // open connection first
                t[i].t_state = T_S_OPEN;
            } else if (t[i].transport_type <= 1) { // packet transport
                t[i].cid = t[i].tid;
                set_start_timer(i);
            } else {
                call Leds.redOn();
            }
        } else if (tMsg->type == TASK_MSG_TYPE_STOP_TASK) {
            int i = tid2i(tid);
            if ((i >= 0) && (t[i].toAddr = srcAddr))
                stop_task(i);
            call Leds.redOff();
        } else if (tMsg->type == TASK_MSG_TYPE_ROUTE_CONTROL_TASK) {
            if (tMsg->param == 1)
                call ParentControl.hold();
            else
                call ParentControl.unhold();
        } else if (tMsg->type == TASK_MSG_TYPE_RETX_CONTROL_TASK) {
            int i;
            if (t[0].t_state == T_S_IDLE) i = 0;
            else if (t[1].t_state == T_S_IDLE) i = 1;
            else return;
            t[i].tid = tid;
            t[i].toAddr = srcAddr;
            t[i].t_state = T_S_RETXACK_WAIT;
            if (i == 0)
                call TaskTimer1.start(TIMER_ONE_SHOT, 2000);
            else
                call TaskTimer2.start(TIMER_ONE_SHOT, 2000);
            call RetransmitControl.setNumRetransmit((int8_t)tMsg->param);
        } else if (tMsg->type == TASK_MSG_TYPE_REBOOT_TASK) {
            if ((tMsg->param == 0) || (tMsg->param == TOS_LOCAL_ADDRESS)) {
                m_state = M_S_REBOOT_WAIT;
                call StateTimer.start(TIMER_ONE_SHOT, 5000);
                call Leds.redOn();
            }
        } else if (tMsg->type == TASK_MSG_TYPE_PING_TASK) {
            int i;
            if (t[0].t_state == T_S_IDLE) i = 0;
            else if (t[1].t_state == T_S_IDLE) i = 1;
            else return;
            t[i].tid = tid;
            t[i].toAddr = srcAddr;
            t[i].t_state = T_S_PINGACK_WAIT;
            if (i == 0)
                call TaskTimer1.start(TIMER_ONE_SHOT, 2000);
            else
                call TaskTimer2.start(TIMER_ONE_SHOT, 2000);
        }
    }

    event void PacketTransportReceive.receive(uint16_t tid, uint16_t srcAddr, void *data, uint8_t datalen) {
        tasking_packet_received(tid, srcAddr, data, datalen);
    }
    event void TRD_Transport.receive(uint16_t tid, uint16_t origin, void *data, uint16_t len) {
        tasking_packet_received(tid, origin, data, len);
    }

    task void sendDataPacket() {
        TOS_MsgPtr myMsg;
        task_msg_t *tMsg;
        int maxlen;
        uint16_t parent, sentcnt16;
        int i;
        if (t[0].t_state == T_S_SEND) i = 0;
        else if (t[1].t_state == T_S_SEND) i = 1;
        else return;
        t[i].t_state = T_S_RUNNING;
        if (t[i].sendbusy)
            return;
        if ((t[i].num_packets != 0) && (t[i].sentcnt >= t[i].num_packets)) {
            stop_task(i);
            return;
        }

        myMsg = &t[i].msgbuf;
        tMsg = (task_msg_t *)myMsg->data;

        tMsg->type = TASK_MSG_TYPE_DATA;

        // routing   header : 8 bytes
        // transport header : 6 bytes
        // rcrt      header : 12 bytes
        // rcrt feedback    : 14 + NACK bytes
        maxlen = call PktTrSend.maxPayloadLength();
        if (maxlen > 4) maxlen = 4;

        sentcnt16 = (uint16_t) t[i].sentcnt;
        parent = call RoutingTable.getParent();
        memcpy(&tMsg->data[0], &sentcnt16, sizeof(uint16_t));
        memcpy(&tMsg->data[2], &parent, sizeof(uint16_t));

        myMsg->length = maxlen + offsetof(task_msg_t, data);

        if (t[i].transport_type == 0) {
            if (call PktTrNoAckSend.send(t[i].tid, t[i].toAddr, myMsg->length, myMsg->data))
                t[i].sendbusy = TRUE;
        } else if (t[i].transport_type == 1) {
            if (call PktTrSend.send(t[i].tid, t[i].toAddr, myMsg->length, myMsg->data))
                t[i].sendbusy = TRUE;
    #ifdef INCLUDE_STR
        } else if (t[i].transport_type == 2) {
            if (call StreamTransportSend.send(t[i].cid, myMsg->length, myMsg->data))
                t[i].sendbusy = TRUE;
    #endif
    #ifdef INCLUDE_RCR
        } else if (t[i].transport_type == 3) {
            if (call RcrTransportSend.send(t[i].cid, myMsg->length, myMsg->data))
                t[i].sendbusy = TRUE;
    #endif
        }
        if (t[i].sendbusy)
            call Leds.yellowToggle();
    }

    void TaskTimer_fired(int i) {
        if (t[i].t_state == T_S_TIME_WAIT) {
            uint32_t real_interval;
            t[i].t_state = T_S_RUNNING;
            if (t[i].interval <= 10)
                t[i].interval = 10;

            real_interval = call LocalTimeInfo.msToTimerInterval(t[i].interval);
            if (i == 0)
                call TaskTimer1.start(TIMER_REPEAT, real_interval);
            else
                call TaskTimer2.start(TIMER_REPEAT, real_interval);

            t[i].t_state = T_S_SEND;
            post sendDataPacket();
        } else if (t[i].t_state == T_S_PINGACK_WAIT) {
            post sendPingAck();
        } else if (t[i].t_state == T_S_RETXACK_WAIT) {
            post sendRetxAck();
        } else if ((t[i].t_state == T_S_RUNNING) && (!t[i].sendbusy)) {
            t[i].t_state = T_S_SEND;
            post sendDataPacket();
            call Leds.greenToggle();
        } else if ((t[i].t_state == T_S_SEND) || (t[i].sendbusy)) {
            t[i].send_pending++;
            //call Leds.redToggle();
        }
    }

    event result_t TaskTimer1.fired() {
        TaskTimer_fired(0);
        return SUCCESS;
    }
    event result_t TaskTimer2.fired() {
        TaskTimer_fired(1);
        return SUCCESS;
    }

    void reboot() {
        #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
            WDTCTL = 0;
        #elif defined (PLATFORM_MICAZ)
            cli();
            wdt_enable(0);
            while(1) {
  		        __asm__ __volatile__("nop" "\n\t" ::);
            }
        #endif
    }

    event result_t StateTimer.fired() {
        if (m_state == M_S_REBOOT_WAIT)
            reboot();
        return SUCCESS;
    }

    void openDone(result_t success, uint8_t cid) {
        int i = cid2i(cid);
        if ((!success) || (i < 0)) {
            reset_task(i);
            call Leds.redOn();
        } else {
            set_start_timer(i);
        }
    }

    void sendDone(uint8_t cid) {
        int i = cid2i(cid);
        if (i < 0) return; // ping will return here
        t[i].sendbusy = FALSE;
        if ((t[i].t_state == T_S_RUNNING) || (t[i].t_state == T_S_SEND)) {
            t[i].sentcnt++;
            if (t[i].interval == 0) {
                t[i].t_state = T_S_SEND;
                post sendDataPacket(); // start of back-to-back
            }
            else if (t[i].send_pending > 0) {
                t[i].t_state = T_S_SEND;
                post sendDataPacket();
                t[i].send_pending--;
            }
        }
    }

    event void PktTrSend.sendDone(uint16_t tid, void *msg, result_t success) {
        sendDone(tid);
    }
    event void PktTrNoAckSend.sendDone(uint16_t tid, void *msg, result_t success) {
        sendDone(tid);
    }
    event void StreamTransportSend.sendDone(uint8_t cid, void *msg, result_t success) {
        sendDone(cid);
    }
    event void RcrTransportSend.sendDone(uint8_t cid, void *msg, result_t success) {
        sendDone(cid);
    }
    event void StreamTransportSend.openDone(uint8_t cid, uint16_t tid, uint16_t addr, result_t success) {
        openDone(success, cid);
    }
    event void RcrTransportSend.openDone(uint8_t cid, uint16_t tid, uint16_t addr, result_t success) {
        openDone(success, cid);
    }
}


