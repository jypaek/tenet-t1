
/*
 * MDA400 driver module for Crossbow's MDA400
 *
 * Authors: Jeongyeup Paek, Sumit Rangwala 
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @author Sumit Rangwala
 * @modified 7/19/2005
 */

// this changes the command from mote to the vboard command packet

/* Notes:
    1. First Mica2 Application MUST call init(); 
    2. You must call PowerON before calling startSampling();
    3. You will be notified with samplingComplete() event when done();
    4. Do not send any packets to Vboard while sampling (this will cause jitter);
    5. It takes about a minute for the Vboard to stablize.

*/
/* Message Defined till now 

    - Start and Stop sampling:
    
    Application --startSampling()---> VBOARD --START_SAMPLING---> Board
    Board --ACK--> VBOARD --startSamplingdone()--> Application

    Application --stopSampling()---> VBOARD --STOP_SAMPLING---> Board
    Board --ACK--> VBOARD --stopSamplingdone()--> Application

    - Same for PowerOn and PowerOff. 

    - Sampling complete:

    Board --samplingComplete--> VBOARD --samplingComplete()--> Application

    - GetData and dataReady:

    Application --getData()---> VBOARD --XMIT_DATA---> Board
    Board --DATA_SAMPLE--> VBOARD --dataReady()--> Application
*/

includes MDA400H;
includes VBTimeSync;

module MDA400M {     
    provides {
        interface StdControl;
        interface MDA400I;
        interface VBSRControl;
        interface VBTimeSync;
    }
    uses {
        interface HPLUART as HPLVBOARD;
    }
}

implementation { 
    
    norace vBoardPacket sendPkt;
    norace uint8_t  *sendBuff;  // sendBuff = (uint8_t *) &sendPkt;
    norace uint8_t  uartSendState;   
    norace uint8_t  sendTotalBytes; // Total bytes to send
    norace uint8_t  byteToSend; // index of the byte to send next 
    
    norace vBoardPacket recvPkt;     
    norace uint8_t  *recvBuff;  // recvBuff = (uint8_t *) &recvPkt;
    norace uint8_t  uartRecvState;
    norace uint8_t  recvTotalBytes; // Total bytes to receive 
    norace uint8_t  byteRecv;   // index for the next received byte 

    norace runTimeSampleCfg *rSampleCfg;

    norace uint8_t  recvByte[BUF_TEST];
    norace uint8_t  head;
    norace uint8_t  tail;
    norace bool full;


    result_t powerSet(uint8_t onOff);
    uint8_t calculateCheckSum(vBoardPacket *pkt);
    bool checksumCheck(vBoardPacket *pkt);
    void sendPacket();  
    task void processData();
     
    command result_t StdControl.init() {
        sendBuff = (uint8_t *) &sendPkt;
        recvBuff = (uint8_t *) &recvPkt;
            
        call MDA400I.init();

        return SUCCESS;
    }
    
    command result_t StdControl.start() {
        return SUCCESS;
    }
    
    command result_t StdControl.stop() {
        call HPLVBOARD.stop(); 
        return SUCCESS; 
    } 

    command result_t MDA400I.init() {
        atomic {
            head = 0;
            tail = 0;
            full = FALSE;

            uartSendState = SEND_IDLE;
            sendTotalBytes = 0; 
            byteToSend = 0;
            
            uartRecvState = RECV_IDLE;
            byteRecv = 2; 
        }
        return call HPLVBOARD.init();
    }

    result_t init_sendPkt() {
        uint8_t goAhead;
        atomic {
            goAhead = FALSE;
            if (uartSendState == SEND_IDLE) {
                uartSendState = SENDING;
                goAhead = TRUE;
            }
        }
        if (!goAhead) return FAIL;
        
        sendPkt.checksum = 0;
        sendPkt.h1 = 0xaa;
        sendPkt.h2 = 0x55;
        sendPkt.cmd = 0;
        sendPkt.err = 0x00;
        sendPkt.nOfBytes = 0x00;
        return SUCCESS;
    }

    uint8_t calculate_num_channels(uint8_t ch_sel) {
        uint8_t num_ch = 0;
        uint8_t k = 1;
        while (k < 16) {
            if (ch_sel & k)
                num_ch++;
            k = k<<1;
        }
        if (num_ch >= 4) num_ch = 4;;
        return num_ch;
    }

    command result_t MDA400I.startSampling(uint16_t s_period, uint8_t ch_sel, 
                                           uint16_t num_ks_per_ch, uint8_t onset_det) {
        // s_period in us
        if (!init_sendPkt())
            return FAIL;

        sendPkt.cmd = CMD_START_SAMPLING_W_CFG;
        sendPkt.nOfBytes = sizeof(runTimeSampleCfg);

        rSampleCfg = (runTimeSampleCfg *) sendPkt.data;
        rSampleCfg->sampling_period = s_period;
        ch_sel = ch_sel & 0x0f;
        rSampleCfg->nmb_channels = calculate_num_channels(ch_sel);
        rSampleCfg->ch_select = ch_sel;
        rSampleCfg->onsetDetection = onset_det;
        if ((rSampleCfg->nmb_channels * num_ks_per_ch) > 30) {
            num_ks_per_ch = 7;  // -jpaek, later..
        }
        rSampleCfg->num_ksamples_per_ch = num_ks_per_ch;

        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();       
        return SUCCESS;
    }

    // continuouse sampling must use onset-detection if frequency is greater than 50Hz  
    command result_t MDA400I.startContinuousSampling(uint16_t s_period,
                                                     uint8_t ch_sel, 
                                                     uint8_t onset_det) {
        // s_period in us
        if (!init_sendPkt())
            return FAIL;

        sendPkt.cmd = CMD_START_CONT_SAMPLING;
        sendPkt.nOfBytes = sizeof(runTimeSampleCfg);

        rSampleCfg = (runTimeSampleCfg *) sendPkt.data;
        rSampleCfg->sampling_period = s_period;
        ch_sel = ch_sel & 0x0f;
        rSampleCfg->nmb_channels = calculate_num_channels(ch_sel);
        rSampleCfg->ch_select = ch_sel;
        rSampleCfg->num_ksamples_per_ch = 7; // use max possible...
        rSampleCfg->onsetDetection = onset_det;

        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();       
        return SUCCESS;
    }

    command result_t MDA400I.stopSampling() {       
        if (!init_sendPkt())
            return FAIL;
        sendPkt.cmd = CMD_STOP_SAMPLING;
        sendPkt.nOfBytes = 0x00;
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();       
        return SUCCESS;     
    }
    
    result_t powerSet(uint8_t onOff) {
        if (!init_sendPkt())
            return FAIL;
        sendPkt.cmd = CMD_POWER_SET;
        sendPkt.nOfBytes = 0x01;
        if(onOff == POWERON)
            sendPkt.data[0] = POWERON;
        else
            sendPkt.data[0] = POWEROFF;
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();       
        return SUCCESS;     
    }

    command result_t MDA400I.powerOn() {
        return powerSet(POWERON);
    }
    
    command result_t MDA400I.powerOff() {
        return powerSet(POWEROFF);
    }

    command result_t VBSRControl.suspendSending() {
        if (!init_sendPkt())
            return FAIL;
        sendPkt.cmd = CMD_SUSPEND_SENDING;
        sendPkt.nOfBytes = 0x00;
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
    }

    command result_t VBSRControl.resumeSending() {
        if (!init_sendPkt())
            return FAIL;
        call HPLVBOARD.init();
        call HPLVBOARD.init();
        call HPLVBOARD.init();
        sendPkt.cmd = CMD_RESUME_SENDING;
        sendPkt.nOfBytes = 0x00;
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
     }
    
    command result_t MDA400I.getData(uint8_t ch_num, uint8_t num_samples, uint16_t sample_offset) {
        // This follows the "RdData" format in MDA400I.specification,
        // although it is wasting 3bytes... :-)
        if (!init_sendPkt())
            return FAIL;

        sendPkt.cmd = CMD_XMIT_DATA;
        sendPkt.nOfBytes = 0x07; // jpaek, following the spec.
    
        sendPkt.data[0] = ch_num;
        sendPkt.data[1] = (uint8_t)(sample_offset & 0x00ff);
        sendPkt.data[2] = (uint8_t)((sample_offset >> 8) & 0x00ff);
        sendPkt.data[3] = 0;    // not used
        sendPkt.data[4] = 0;    // not used
        sendPkt.data[5] = num_samples;
        sendPkt.data[6] = 0;    // not used
        
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
    } 
     
    command result_t MDA400I.getNextEventData(uint8_t ch_num, uint8_t num_samples) {
        if (!init_sendPkt())
            return FAIL;

        sendPkt.cmd = CMD_XMIT_NEXT_EVENT_DATA;
        sendPkt.nOfBytes = 0x02;
    
        sendPkt.data[0] = ch_num;
        sendPkt.data[1] = num_samples;
        
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
    }

    command result_t MDA400I.getNextAvailData(uint8_t ch_num, uint8_t num_samples) {
        if (!init_sendPkt())
            return FAIL;

        sendPkt.cmd = CMD_XMIT_NEXT_AVAIL_DATA;
        sendPkt.nOfBytes = 0x02;
    
        sendPkt.data[0] = ch_num;
        sendPkt.data[1] = num_samples;
        
        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
    }

    command result_t VBTimeSync.sendTimeSyncMsg(uint32_t currentTime) {
        VBTimeSyncMsg *tsmsg;

        if (!init_sendPkt())
            return FAIL;
        sendPkt.cmd = CMD_TIMESYNC_MSG;
        sendPkt.nOfBytes = 0x04;

        tsmsg = (VBTimeSyncMsg *) sendPkt.data;
        tsmsg->sendingTime = currentTime;

        sendPkt.checksum = calculateCheckSum(&sendPkt);
        sendPacket();
        return SUCCESS;
    }


    void sendPacket() {
        sendTotalBytes = HEADER_SIZE + sendPkt.nOfBytes + CHECKSUM_SIZE;
        // Header + data + checksum
        byteToSend = 0;
        call HPLVBOARD.put(sendBuff[byteToSend++]); // this should never fail.
        // if this fails... we need to rethink the design
    }

    async event result_t HPLVBOARD.putDone() { 
        vBoardPacket *pkt;
        pkt = (vBoardPacket *) sendBuff;

        if (byteToSend == HEADER_SIZE + VB_MAX_DATA_SIZE + CHECKSUM_SIZE) {
            // Last byte send was checksum
            if (pkt->cmd == CMD_SUSPEND_SENDING)   {
                call HPLVBOARD.stop();
                // Wait for some time for the vibe card to cut off.
                TOSH_uwait(400);
                signal VBSRControl.suspendSendingDone(SUCCESS);
                // reset the recv state .. may lead to packet loss
                if (uartRecvState != RECV_IDLE) {
                    atomic { uartRecvState = RECV_IDLE; }
                }
            } else if (pkt->cmd == CMD_RESUME_SENDING) {
                atomic { uartRecvState = RECV_IDLE; }

            } else if (pkt->cmd == CMD_TIMESYNC_MSG) {
                signal VBTimeSync.sendDone(SUCCESS);// signal immeidately, don't wait for ack
            }

            // We signal 'done' event when we get ACK from Vboard.
            atomic { uartSendState = SEND_IDLE; }
            sendTotalBytes = 0;
            return SUCCESS;
        }
        
        if (byteToSend < sendTotalBytes - CHECKSUM_SIZE) {
            call HPLVBOARD.put(sendBuff[byteToSend++]);
        }
        else {   // If we have send all the data, jump to checksum
            byteToSend = HEADER_SIZE + VB_MAX_DATA_SIZE;
            call HPLVBOARD.put(sendBuff[byteToSend++]);
        }
        return SUCCESS; 
    }
 
    async event result_t HPLVBOARD.get(uint8_t data) {
        post processData();
        if (full == TRUE) {
            // should NEVER be full.
            // must increase buffer size
        }
        recvByte[head] = data;
        head = (head + 1) % BUF_TEST;
        atomic {
            if (head == tail)
                full = TRUE;
        }
        return SUCCESS;
    }


    task void processData() {   
        uint8_t type;
        uint8_t goAhead = TRUE; 
        uint8_t data = 0;
    
        atomic {    
            if ((tail != head) || (full == TRUE)) {
                data = recvByte[tail];
                tail = (tail + 1) % BUF_TEST;
                full = FALSE;
            } else { 
                goAhead = FALSE;
            }
        }
        if (!goAhead)   return;
         
        post processData();

        goAhead = FALSE;
        atomic {
            if (uartRecvState == RECV) {
                goAhead = TRUE;
            } else {
                if (uartRecvState == RECV_IDLE && data == 0xaa) {
                    uartRecvState = SYN1;
                } else if (uartRecvState == SYN1 && data == 0x55) {
                    uartRecvState = RECV ;
                    byteRecv = 2;
                } else if (uartRecvState == SYN1 && data == 0xaa) {
                    uartRecvState = SYN1;
                } else  {
                    uartRecvState = RECV_IDLE;       
                }
            }
        }
        if (!goAhead)   return;
        
        if (byteRecv < HEADER_SIZE - 1 ) { // Num data bytes (NDB) not yet received
            recvBuff[byteRecv++] = data;
        } else if (byteRecv == HEADER_SIZE - 1 ) { // We received the NDB byte
            recvBuff[byteRecv++] = data; 
            if (data <= VB_MAX_DATA_SIZE) {
                recvTotalBytes = HEADER_SIZE + data + CHECKSUM_SIZE;
            } else { // Error condition! Start recovering as soon as possible 
                atomic { 
                    byteRecv = 2; // For h1 and h2 
                    uartRecvState = RECV_IDLE; 
                }
            }
         
        } else if ((byteRecv > HEADER_SIZE - 1) 
            && (byteRecv < (recvTotalBytes - CHECKSUM_SIZE))) {
            // Receiving the data field.
            recvBuff[byteRecv++] = data;
        } else if (byteRecv == (recvTotalBytes - CHECKSUM_SIZE)) {
            // Checksum byte reception
            recvBuff[HEADER_SIZE + VB_MAX_DATA_SIZE] = data; 
            if (checksumCheck(&recvPkt)) {
                type = recvPkt.cmd;

                if (type == CMD_DATA_SAMPLE)    {
                    signal MDA400I.dataReady(recvPkt.nOfBytes, recvPkt.data);

                } else if (type == CMD_SAMPLING_COMPLETE) {
                    signal MDA400I.samplingComplete();

                } else if (type == CMD_START_SAMPLING_W_CFG) { // -jpaek, CFG
                    signal MDA400I.startSamplingDone(!recvPkt.err);

                } else if (type == CMD_START_CONT_SAMPLING) { // -jpaek, CFG
                    signal MDA400I.startSamplingDone(!recvPkt.err);

                } else if (type == CMD_STOP_SAMPLING) {
                    signal MDA400I.stopSamplingDone(SUCCESS);

                } else if (type == CMD_XMIT_DATA) {
                    // CMD_DATA_SAMPLE will come instead of XMIT_DATA
                    signal MDA400I.dataReady(recvPkt.nOfBytes, recvPkt.data);

                } else if (type == CMD_XMIT_NEXT_EVENT_DATA) {
                    uint32_t timestamp;
                    memcpy(&timestamp, recvPkt.data, sizeof(uint32_t));
                    signal MDA400I.nextEventDataReady(recvPkt.nOfBytes - sizeof(uint32_t), 
                            recvPkt.data + sizeof(uint32_t), timestamp);

                } else if (type == CMD_XMIT_NEXT_AVAIL_DATA) {
                    signal MDA400I.nextAvailDataReady(recvPkt.nOfBytes, recvPkt.data);

                } else if (type == CMD_POWER_SET) {
                    if (recvPkt.data[0] == POWERON) 
                        signal MDA400I.powerOnDone(SUCCESS);
                    else    
                        signal MDA400I.powerOffDone(SUCCESS);

                } else if (type == CMD_RESUME_SENDING) {
                    TOSH_uwait(200);
                    signal VBSRControl.resumeSendingDone(SUCCESS);

                } else if (type == CMD_TIMESYNC_MSG) {
                    signal VBTimeSync.sendDone(SUCCESS);
                }
            }

            atomic {
                byteRecv = 2; // For h1 and h2 
                uartRecvState = RECV_IDLE; 
            }
        }
        return;
    }
    
    uint8_t calculateCheckSum(vBoardPacket *pkt) {
        uint8_t i;
        uint8_t checksum = 0;
        checksum += pkt->cmd;
        checksum += pkt->err;
        checksum += pkt->nOfBytes;
        for(i = 0; i < pkt->nOfBytes; i++)
            checksum += pkt->data[i];
        return checksum;
    }

    bool checksumCheck(vBoardPacket *pkt) {
        if (calculateCheckSum(pkt) == pkt->checksum)
            return SUCCESS;
        return FAIL;        
    }
    
    default event void MDA400I.startSamplingDone(result_t success) {return;}
    default event void MDA400I.stopSamplingDone(result_t success) {return;}
    default event void MDA400I.powerOnDone(result_t success) {return;}
    default event void MDA400I.powerOffDone(result_t success) {return;}
    default async event void VBSRControl.suspendSendingDone(result_t success) {return;}
    default async event void VBSRControl.resumeSendingDone(result_t success) {return;}
    default event void MDA400I.samplingComplete() {return;}
    default event void MDA400I.dataReady(uint8_t num_bytes, uint8_t *data) {return;}
    default event void MDA400I.nextEventDataReady(uint8_t num_bytes, uint8_t *data, uint32_t timestamp) {return;}
    default event void MDA400I.nextAvailDataReady(uint8_t num_bytes, uint8_t *data) {return;}
    default async event void VBTimeSync.sendDone(result_t success) {return;}
 
}

