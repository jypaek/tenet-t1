/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

#include "PXA27XUSBClient.h"
#include "PXA27XUDCRegAddrs.h"
includes trace;

module PXA27XUSBClientM {
  provides {
    interface StdControl as Control;
    interface ReceiveData; /* Type is
			      IMOTE_HID_TYPE_CL_BLUSH or
			      IMOTE_HID_TYPE_CL_GENERAL.*/
    interface ReceiveMsg;  /* Type is 
			      IMOTE_HID_TYPE_CL_RPACKET.*/
    interface ReceiveBData;/* Type is 
			      IMOTE_HID_TYPE_CL_BINARY.*/
    
    interface SendVarLenPacket;/* Type is assumed to be 
				  IMOTE_HID_TYPE_CL_BLUSH.*/
    interface SendJTPacket[uint8_t channel];
    interface BareSendMsg; /* Type is assumed to be
			      IMOTE_HID_TYPE_CL_RPACKET */
    
  }
  uses {
    interface UID;
    interface PXA27XGPIOInt as USBAttached;
    interface PXA27XInterrupt as USBInterrupt;
    interface HPLUSBClientGPIO;
  }
}
implementation {
  
#include "PXA27Xdynqueue.c"
#include "PXA27XUSBdata.c"
  
  /*In and Out follow USB specifications.
    IN = Device->Host, OUT = Host->Device*/
  
  /*
   * The various write*Descriptor functions are used to initialize data for
   * USB enumeration and use
   */
  void writeStringDescriptor();
  void writeHidDescriptor();
  void writeHidReportDescriptor();
  void writeEndpointDescriptor(USBendpoint *endpoints, uint8_t config, uint8_t inter, uint8_t i);
  uint16_t writeInterfaceDescriptor(USBinterface *interfaces, uint8_t config, uint8_t i);
  void writeConfigurationDescriptor(USBconfiguration *configs, uint8_t i);
  void writeDeviceDescriptor();
  
  /*
   * clearDescriptors is a function to clean up all the memory used in 
   * initializing the USB descriptors in the various write*Descriptor 
   * functions.
   */
  void clearDescriptors();
  
  /*
   * The send*Descriptor functions convert the data initialized in the 
   * write*Descriptor functions into the data streams that are to be sent, and
   * then queues those data streams.
   */
  void sendStringDescriptor(uint8_t id, uint16_t wLength);
  void sendDeviceDescriptor(uint16_t wLength);
  void sendConfigDescriptor(uint8_t id, uint16_t wLength);
  void sendHidReportDescriptor(uint16_t wLength);
  
  /*
   * Once the device has been enumerated, sendReport is used to take data and
   * convert it into a queuable structure for sending. data is a pointer to the
   * buffer to be sent; datalen is the length of that buffer in bytes, type
   * is the type as specified in the JT protocol, and source is either 
   * SENDVARLENPACKET, SENDJTPACKET or SENDBAREMSG, depending on the 
   * interface used to send the data.
   */
  void sendReport(uint8_t *data, uint32_t datalen, uint8_t type, uint8_t source, uint8_t channel);
  
  /*
   * The sendIn() task prepends the necessary JT protocol information and
   * for a packet that has been queued and then handles sending it.
   */
  task void sendIn();
  
  /*
   * sendControlIn handles sending a queued control message.
   */
  
  void sendControlIn();
  
  /*
   * clearIn() clears the queue of data to be sent to the host PC. 
   * clearUSBdata() is a helper function
   */ 
  void clearIn();
  void clearUSBdata(USBdata Stream, uint8_t isConst);
  
  /*
   * The processOut() task handles converting data received from the host PC
   * in JT format into regular data.
   */
  task void processOut();
  
  /* retrieveOut() queues JT data that has been received from the host PC
   * for translating into regular data.
   */
  void retrieveOut();
  
  /*
   * clearOut() is a helper function that clears the data structure for the 
   * current packet of received data. 
   */ 
  void clearOut();
  
  /*
   * clearOutQueue() wipes the queue of data received from the PC waiting to 
   * be processed
   */
  void clearOutQueue();
  
  /*
   * handleControlSetup() processes setup requests from the host PC.
   */
  void handleControlSetup();
  
  /*
   * isAttached() checks if the mote is attached over USB to a power source
   * (assumed to be a host PC).
   */
  void isAttached();
  
  static USBdevice Device; //Contains data for various descriptors
  static USBhid Hid; //Contains Hid descriptor data
  static USBhidReport HidReport; //Contains the HidReport descriptor
  static USBstring Strings[STRINGS_USED + 1]; //Data for string descriptors
  
  static DynQueue InQueue, OutQueue; /*Queues for sending and receiving data
				       from the host PC*/
  static USBdata_t OutStream[IMOTE_HID_TYPE_COUNT]; 
  /*Data about the four possible current 
    transfer from the host PC (the four types
    being specified by JT protocol)*/
  
  static USBdata InState = NULL; /**/
  static uint32_t state = 0; /*State of the USB device: either 0, POWERED,
			       DEFAULT, or CONFIGURED*/
  static uint8_t init = 0, InTask = 0;//, OutTask = 0, OutPaused = 0;
  /*booleans to prevent multiple 
    initializations, excessive tasks
    being posted, and overfilling queues*/
  
  command result_t Control.init() {
    uint8_t i;
    DynQueue QueueTemp;
    if(init == 0){//one time initilization because of allocated memory
      writeDeviceDescriptor();
      writeStringDescriptor();
      writeHidDescriptor();
      writeHidReportDescriptor();
      
      QueueTemp = DynQueue_new();
      atomic InQueue = QueueTemp;
      QueueTemp = DynQueue_new();
      atomic OutQueue = QueueTemp;
    }
    
    call HPLUSBClientGPIO.init();      
    
    atomic{
      CKEN |= CKEN_CKEN11;
      
      UDCICR1 |= _UDC_bit(INT_IRRS); //reset     
      UDCICR1 |= _UDC_bit(INT_IRCC);
      UDCICR0 |= _UDC_bit(INT_END0);
      UDCICR0 |= _UDC_bit(INT_ENDA);
      UDCICR0 |= _UDC_bit(INT_ENDB);
      
      for(i = 0; i < IMOTE_HID_TYPE_COUNT; i++){
	OutStream[i].endpointDR = _udcdrb;
	OutStream[i].fifosize = Device.oConfigurations[1]->
	  oInterfaces[0]->oEndpoints[1]->wMaxPacketSize;
	OutStream[i].len = OutStream[i].index = OutStream[i].status =
	  OutStream[i].type = 0;
      }
      state = 0;
    }
    call USBAttached.enable(TOSH_BOTH_EDGE);
    
    call USBInterrupt.allocate();
    
    isAttached();
    
    return SUCCESS;
  }
  
  command result_t Control.start() {
    call USBInterrupt.enable();
    return SUCCESS;
  }
  
  command result_t Control.stop() {
    DynQueue QueueTemp;
    call USBInterrupt.disable();
    call USBAttached.disable();
    atomic state = 0;
    clearDescriptors();
    clearIn();
    atomic QueueTemp = InQueue;
    DynQueue_free(QueueTemp);
    clearOut();
    clearOutQueue();
    atomic QueueTemp = OutQueue;
    DynQueue_free(QueueTemp);
    return SUCCESS;
  }
  
  async event void USBAttached.fired()
  {
    isAttached();
    call USBAttached.clear();
  }
  
  async event void USBInterrupt.fired(){
    uint32_t statusreg;
    uint8_t statetemp;
    DynQueue QueueTemp;
    USBdata InStateTemp;
    
    atomic statetemp = state;
#if DEBUG   
    if(statetemp != CONFIGURED)
      trace("Interrupt; state: %d, UDCISRs: %x %x \r\n", statetemp, UDCISR0, UDCISR1);
#endif
    switch(statetemp){
    case POWERED:
      atomic{
	if(isFlagged(UDCISR1, _UDC_bit(INT_IRRS))){
	  state = DEFAULT;
	  UDCISR1 = _UDC_bit(INT_IRRS);
	}
	
	if(isFlagged(UDCISR0, _UDC_bit(INT_END0)))
	  UDCISR0 = _UDC_bit(INT_END0);
	if(isFlagged(UDCISR0, _UDC_bit(INT_ENDA)))
	  UDCISR0 = _UDC_bit(INT_ENDA);
	if(isFlagged(UDCISR0, _UDC_bit(INT_ENDB)))
	  UDCISR0 = _UDC_bit(INT_ENDB);
	if(isFlagged(UDCISR1, _UDC_bit(INT_IRCC)))
	  UDCISR1 = _UDC_bit(INT_IRCC);
      }
      break;     
    case DEFAULT:
    case CONFIGURED:
      if(isFlagged(UDCISR1, _UDC_bit(INT_IRRS))){
	clearIn();
	atomic{
	  state = DEFAULT;
	  UDCISR1 = _UDC_bit(INT_IRRS);
	}
      }
      
      if(isFlagged(UDCISR1, _UDC_bit(INT_IRCC))){
	handleControlSetup();
	/*atomic*/ UDCISR1 = _UDC_bit(INT_IRCC);
      }
      else if(isFlagged(UDCISR0, _UDC_bit(INT_END0))){
	/*atomic*/{
	  statusreg = UDCCSR0;
	  UDCISR0 = _UDC_bit(0);
	}
	atomic InStateTemp = InState;
	if(isFlagged(statusreg, _UDC_bit(UDCCSR0_SA))){
	  handleControlSetup();
	}
	else if(InStateTemp != NULL && InStateTemp->endpointDR == _udcdr0 &&
		InStateTemp->index != 0) //packet sent from endpoint 0
	  {
	    if(!isFlagged(InStateTemp->status, _UDC_bit(MIDSEND))){
#if DEBUG
	      trace("Packet Complete, no longer in progress; len %d\r\n");
#endif	     
	      atomic QueueTemp = InQueue;
	      clearUSBdata(((USBdata)DynQueue_dequeue(QueueTemp)), 0);
	      atomic InState = NULL;
	      if(DynQueue_getLength(QueueTemp) > 0)
		sendControlIn();
	      else
		atomic InTask = 0;
	    }
	    else{
#if DEBUG
	      trace("Packet Complete, continuing\r\n");
#endif
	      sendControlIn();
	    }
	  }
	else //unrecognized control request
	  {
	    ///*atomic*/ UDCCSR0 |= _UDC_bit(UDCCSR0_FST);
	    //trace("Unrecognized Control request\r\n");
	  }
      }
      if(isFlagged(UDCISR0, _UDC_bit(INT_ENDA))){
#if DEBUG
	trace("Endpoint A int fired\r\n");
#endif
	atomic statetemp = state;
	UDCISR0 = _UDC_bit(INT_ENDA);
	atomic InStateTemp = InState;
	if(statetemp != CONFIGURED)
	  UDCCSRB |= _UDC_bit(UDCCSRAX_PC);
	else if(InStateTemp != NULL && InStateTemp->endpointDR == _udcdra &&
		InStateTemp->index != 0 && statetemp == CONFIGURED) //packet sent from endpoint a
	  {
	    ///*atomic*/ InState->status |= _UDC_bit(PACKETCOMPLETE);
	    
	    if(!isFlagged(InStateTemp->status, _UDC_bit(MIDSEND))){
#if DEBUG
	      trace("Packet Complete, no longer in progress\r\n");
#endif
	      if(InStateTemp->source == SENDVARLENPACKET)
		signal SendVarLenPacket.sendDone(InStateTemp->src, SUCCESS);
	      else if(InStateTemp->source == SENDJTPACKET)
		signal SendJTPacket.sendDone[InStateTemp->channel](InStateTemp->src, 
					     InStateTemp->type, SUCCESS);
	      else if(InStateTemp->source == SENDBAREMSG)
		signal BareSendMsg.sendDone((TOS_MsgPtr) InStateTemp->src,
					    SUCCESS);
	      atomic QueueTemp = InQueue;
	      clearUSBdata(((USBdata)DynQueue_dequeue(QueueTemp)), 1);
	      atomic InState = NULL;
	      if(DynQueue_getLength(QueueTemp) > 0)
		post sendIn();
	      else
		atomic InTask = 0;
	      
	    }
	    else{
#if DEBUG
	      trace("Packet Complete, continuing\r\n");
#endif
	      post sendIn();
	    }
	  }
      }
      if(isFlagged(UDCISR0, _UDC_bit(INT_ENDB))){
#if DEBUG
	trace("Endpoint B int fired\r\n");
#endif
	
	atomic statetemp = state;
	UDCISR0 = _UDC_bit(INT_ENDB);
	if(statetemp == CONFIGURED)
	  retrieveOut();
	else{
	  UDCCSRB = _UDC_bit(UDCCSRAX_PC);
	}
      }
      
      break;
    default:
      if(isFlagged(UDCISR0, _UDC_bit(INT_END0)))
	/*atomic*/ UDCISR0 = _UDC_bit(INT_END0);
      if(isFlagged(UDCISR0, _UDC_bit(INT_ENDA)))
	/*atomic*/ UDCISR0 = _UDC_bit(INT_ENDA);
      if(isFlagged(UDCISR0, _UDC_bit(INT_ENDB)))
	/*atomic*/ UDCISR0 = _UDC_bit(INT_ENDB);
      if(isFlagged(UDCISR1, _UDC_bit(INT_IRCC)))
	/*atomic*/ UDCISR1 = _UDC_bit(INT_IRCC);
      if(isFlagged(UDCISR1, _UDC_bit(INT_IRRS)))
	/*atomic*/ UDCISR1 = _UDC_bit(INT_IRRS);
      break;
    }
  }
  
  command result_t SendVarLenPacket.send(uint8_t* packet, uint8_t numBytes){
    uint8_t statetemp;
    atomic statetemp = state;
    if(statetemp != CONFIGURED)
      return FAIL;
    sendReport(packet, numBytes, IMOTE_HID_TYPE_CL_BLUSH, SENDVARLENPACKET, 0);
    return SUCCESS;
  }
  
  command result_t SendJTPacket.send[uint8_t channel](uint8_t* data, uint32_t numBytes, uint8_t type){
    uint8_t statetemp;
    atomic statetemp = state;
    if(statetemp != CONFIGURED)
      return FAIL;
    sendReport(data, numBytes, type, SENDJTPACKET, channel);
    return SUCCESS;
  }
  
  command result_t BareSendMsg.send(TOS_MsgPtr msg){
    uint8_t statetemp;
    atomic statetemp = state;
    if(statetemp != CONFIGURED)
      return FAIL;
    sendReport((uint8_t *)msg, sizeof(TOS_Msg), IMOTE_HID_TYPE_CL_RPACKET, SENDBAREMSG, 0);
    return SUCCESS;
  }
  
 default event result_t SendVarLenPacket.sendDone(uint8_t* packet, result_t success){
   return SUCCESS;
 }
 
 default event result_t SendJTPacket.sendDone[uint8_t channel](uint8_t* packet, uint8_t type,
					      result_t success){
   return SUCCESS;
 }
 
 default event result_t BareSendMsg.sendDone(TOS_MsgPtr msg, result_t success){
   return SUCCESS;
 }
 
 default event result_t ReceiveData.receive(uint8_t* Data, uint32_t Length) {
   return SUCCESS;
 }
 
 default event result_t ReceiveBData.receive(uint8_t* buffer, uint8_t numBytesRead, uint32_t i, uint32_t n, uint8_t type){
   return SUCCESS;
 }
 
 default event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr m){
   return NULL;
 }
 
 void handleControlSetup(){
   uint32_t data[2];
   uint8_t statetemp;
   
   clearIn();
   atomic statetemp = state;
   
   /*atomic*/{
     data[0] = UDCDR0;
     data[1] = UDCDR0;
     
#if DEBUG
     if(statetemp != CONFIGURED)
       trace("hCS; data: %x %x \r\n", data[0], data[1]);
#endif
     
     //UDCCSR0 |= _UDC_bit(UDCCSR0_OPC);
     UDCCSR0 |= _UDC_bit(UDCCSR0_SA);//does both in one step...the magic of |=
   }
   if(getBit(getByte(data[0], 0), 6) == 0 &&
      getBit(getByte(data[0], 0), 5) == 0 &&
      getByte(data[0], 1) == USB_GETDESCRIPTOR){
     
     switch(getByte(data[0], 3))
       {
       case USB_DESCRIPTOR_DEVICE:
	 sendDeviceDescriptor((data[1] >> 16) & 0xFFFF);
	 break;
       case USB_DESCRIPTOR_CONFIGURATION:
	 sendConfigDescriptor(getByte(data[0],2),(data[1] >> 16) & 0xFFFF);
	 break;
       case USB_DESCRIPTOR_STRING:
	 sendStringDescriptor(getByte(data[0],2),(data[1] >> 16) & 0xFFFF);
	 break;
       case USB_DESCRIPTOR_HID_REPORT:
	 sendHidReportDescriptor((data[1] >> 16) & 0xFFFF);
	 break;
       default:
	 //trace("Unrecognized Descriptor request\r\n");
	 //	 /*atomic*/ UDCCSR0 |= _UDC_bit(UDCCSR0_FST);
	 break;
       }
   }
   else if(getBit(getByte(data[0], 0), 6) == 0 &&
	   getBit(getByte(data[0], 0), 5) == 0 &&
	   getByte(data[0], 1) == USB_SETCONFIGURATION){
     /*atomic*/ UDCCR |= _UDC_bit(UDCCR_SMAC);
     
     if((UDCCR & _UDC_bit(UDCCR_EMCE)) != 0)
       //       state = CONFIGURED;
       //     else
#if DEBUG
       TRACE("Error: Memory configuration\r\n");
#else
     ;
#endif     
   }
   else if(getBit(getByte(data[0], 0), 6) == 0 &&
	   getBit(getByte(data[0], 0), 5) == 1){
     switch(getByte(data[0], 1)){
     case USB_HID_GETREPORT:
       //write
       break;
     case USB_HID_GETIDLE:
       //fairly optional
       break;
     case USB_HID_GETPROTOCOL:
       //fairly optional
       break;
     case USB_HID_SETREPORT:
       //fairly optional
       break;
     case USB_HID_SETIDLE:
       //called but optional...should stall in response to this according to the book
       /*atomic*/ UDCCSR0 |= _UDC_bit(UDCCSR0_FST);
       break;
     case USB_HID_SETPROTOCOL:
       //fairly optional
       break;
     }
     
   }
   else
     {
       //trace("Unrecognized Setup request\r\n");
       ///*atomic*/ UDCCSR0 |= _UDC_bit(UDCCSR0_FST);
     }
 }
 
 //caller frees his own memory once this exits
 void sendReport(uint8_t *data, uint32_t datalen, uint8_t type, uint8_t source, uint8_t channel){
   USBdata InStream;
   uint8_t statetemp, InTaskTemp;
   DynQueue QueueTemp;
   
   atomic statetemp = state;
   
   if(statetemp != CONFIGURED)
     return;
   
#if DEBUG   
   trace("Sending report\r\n");
#endif
   
   if(isFlagged(UDCCSRA, _UDC_bit(UDCCSRAX_PC)))
     UDCCSRA |= _UDC_bit(UDCCSRAX_PC);
   
   atomic{
     InStream = (USBdata)malloc(sizeof(USBdata_t));
     
     InStream->channel = channel;
     InStream->endpointDR = _udcdra;
     InStream->fifosize = Device.oConfigurations[1]->oInterfaces[0]->oEndpoints[0]->wMaxPacketSize;
     InStream->pindex = InStream->index = 0;
     InStream->type = type;
     InStream->source = source;
     InStream->len = datalen;
     InStream->src = data;
     InStream->param = (uint8_t *)IMOTE_HID_REPORT;
   }
   
   if(datalen <= IMOTE_HID_TYPE_L_BYTE_SIZE){
     InStream->type |= (IMOTE_HID_TYPE_L_BYTE << IMOTE_HID_TYPE_L);
     InStream->n =  (uint8_t)(datalen / IMOTE_HID_BYTE_MAXPACKETDATA);
     InStream->tlen = InStream->n * InStream->fifosize + 3 +
       datalen % IMOTE_HID_BYTE_MAXPACKETDATA;
   }
   else if(datalen <= IMOTE_HID_TYPE_L_SHORT_SIZE){
     InStream->type |= (IMOTE_HID_TYPE_L_SHORT << IMOTE_HID_TYPE_L);
     InStream->n =  (uint16_t)(datalen / IMOTE_HID_SHORT_MAXPACKETDATA);
     InStream->tlen = InStream->n * InStream->fifosize + 4 +
       datalen % IMOTE_HID_SHORT_MAXPACKETDATA;
   }
   else if(datalen <= IMOTE_HID_TYPE_L_INT_SIZE){
     InStream->type |= (IMOTE_HID_TYPE_L_INT << IMOTE_HID_TYPE_L);
     InStream->n = datalen / IMOTE_HID_SHORT_MAXPACKETDATA;
     InStream->tlen = InStream->n * InStream->fifosize + 6 +
       datalen % IMOTE_HID_INT_MAXPACKETDATA;
   }
   else{//too much data...which isn't really possible in this case so not a big deal
   }
   
   atomic InTaskTemp = InTask;
   atomic QueueTemp = InQueue;
   DynQueue_enqueue(QueueTemp, InStream);
   if(DynQueue_getLength(QueueTemp) == 1 && InTaskTemp == 0){
     atomic InTask = 1;
     post sendIn();
   }
 }
 
 void retrieveOut(){
   uint16_t i = 0;
   uint8_t *buff;
   uint32_t temp;
   uint8_t bufflen;//, OutPausedTemp, OutTaskTemp;
   
   for(i = 0; i < IMOTE_HID_TYPE_COUNT; i++)
     atomic OutStream[i].endpointDR = _udcdrb;
   
   bufflen = Device.oConfigurations[1]->oInterfaces[0]->oEndpoints[1]->wMaxPacketSize;
   buff = (uint8_t *)malloc(bufflen);
   
   atomic{
     for(i = 0; (_PXAREG(OutStream[0].endpointDR - _udcdr0 + _udcbcr0) & 0x1FF) > 0 && i < bufflen; i+=4){
       temp = _PXAREG(OutStream[0].endpointDR);
       *(uint32_t *)(buff + i) = temp;//(temp << 24) | ((temp >> 8) << 16) | ((temp >> 16) << 8) | (temp >> 24);
     }
   }
   DynQueue_enqueue(OutQueue, buff);
   /*if(DynQueue_getLength(OutQueue) >= 20){
     atomic OutPaused = 1;
     }
     atomic OutPausedTemp = OutPaused;
     if(OutPausedTemp == 0)
     atomic _PXAREG(OutStream[0].endpointDR - _udcdr0 + _udccsr0) |=
     _UDC_bit(UDCCSRAX_PC);
     
     atomic OutTaskTemp = OutTask;
     if(DynQueue_getLength(OutQueue) <= 1 && OutTaskTemp == 0){
     atomic OutTask = 1;
     post processOut();
     }*/
   post processOut();
 }
 
 task void processOut(){
   uint8_t *buff;
   uint8_t type, valid = 0;//, OutPausedTemp;
   USBdata OutStreamTemp;
   
#if DEBUG
   trace("In processOut;\r\n");
#endif
   
   /*   if(DynQueue_getLength(OutQueue) < 1){
	atomic{
	OutTask = 0;
	OutPaused = 0;
	}
	return;
	}
	
	atomic OutTask = 1;*/
   buff = (uint8_t *)DynQueue_dequeue(OutQueue);
   
   /*   if(DynQueue_getLength(OutQueue) <= 10 && OutPausedTemp == 1){
	atomic OutPaused = 0;
	_PXAREG(_udcdrb - _udcdr0 + _udccsr0) |= _UDC_bit(UDCCSRAX_PC);
	}*/
   
   
   atomic OutStream[0].endpointDR = _udcdrb;   
   type = *(buff + IMOTE_HID_TYPE);
   atomic OutStreamTemp = &OutStream[type & 0x3];
   if(isFlagged(type, _UDC_bit(IMOTE_HID_TYPE_H))){
     clearOut();
     atomic OutStream[type & 0x3].type = type;
     atomic OutStream[0].endpointDR = _udcdrb;   
     
     switch((OutStreamTemp->type >> IMOTE_HID_TYPE_L) & 3){
     case IMOTE_HID_TYPE_L_BYTE:
       OutStreamTemp->n = *(buff + IMOTE_HID_NI);
       if(OutStreamTemp->n == 0){
	 valid = *(buff + IMOTE_HID_NI + 1);
	 OutStreamTemp->len = valid;
       }
       else{
	 valid = IMOTE_HID_BYTE_MAXPACKETDATA;
	 OutStreamTemp->len = (OutStreamTemp->n + 1) * 
	   IMOTE_HID_BYTE_MAXPACKETDATA - 1;
       }
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 1 + 
	      (OutStreamTemp->n == 0?1:0), valid);
       break;
     case IMOTE_HID_TYPE_L_SHORT:
       OutStreamTemp->n = (*(buff + IMOTE_HID_NI) << 8) | *(buff + IMOTE_HID_NI + 1);
       if(OutStreamTemp->n == 0){
	 valid = *(buff + IMOTE_HID_NI + 2);
	 OutStreamTemp->len = valid;
       }
       else{
	 valid = IMOTE_HID_SHORT_MAXPACKETDATA;
	 OutStreamTemp->len = (OutStreamTemp->n + 1) * 
	   IMOTE_HID_SHORT_MAXPACKETDATA - 1;
       }
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 2 +
	      (OutStreamTemp->n == 0?1:0), valid);
       break;
     case IMOTE_HID_TYPE_L_INT:
       OutStreamTemp->n = (*(buff + IMOTE_HID_NI) << 24) | (*(buff + IMOTE_HID_NI + 1) << 16) | (*(buff + IMOTE_HID_NI + 2) << 8) | *(buff + IMOTE_HID_NI + 3);
       if(OutStreamTemp->n == 0){
	 valid = *(buff + IMOTE_HID_NI + 4);
	 OutStreamTemp->len = valid;
       }
       else{
	 valid = IMOTE_HID_INT_MAXPACKETDATA;
	 OutStreamTemp->len = (OutStreamTemp->n + 1) *
	   IMOTE_HID_INT_MAXPACKETDATA - 1;
       }
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 4 + 
	      (OutStreamTemp->n == 0?1:0), valid);
     }
   }
   else if(isFlagged(OutStreamTemp->type, _UDC_bit(IMOTE_HID_TYPE_H))){
     switch((OutStreamTemp->type >> IMOTE_HID_TYPE_L) & 3){
     case IMOTE_HID_TYPE_L_BYTE:
       if(OutStreamTemp->index != *(buff + IMOTE_HID_NI)){
//	 trace("Received packet has incorrect index\r\n");
	 clearOut();
	 free(buff);
	 buff = NULL;
	 _PXAREG(_udcdrb - _udcdr0 + _udccsr0) |= _UDC_bit(UDCCSRAX_PC);
	 //post processOut();
	 return;
       }
       if(OutStreamTemp->n == OutStreamTemp->index)
	 valid = *(buff + IMOTE_HID_NI + 1);
       else
	 valid = IMOTE_HID_BYTE_MAXPACKETDATA;
       
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL && valid != 0){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 1 + 
	      (OutStreamTemp->n == OutStreamTemp->index?1:0), valid);
       break;
     case IMOTE_HID_TYPE_L_SHORT:
       if(OutStreamTemp->index != ((*(buff + IMOTE_HID_NI) << 8) | *(buff + IMOTE_HID_NI + 1))){
//	 trace("Received packet has incorrect index\r\n");
	 clearOut();
	 free(buff);
	 buff = NULL;
	 _PXAREG(_udcdrb - _udcdr0 + _udccsr0) |= _UDC_bit(UDCCSRAX_PC);
	 //post processOut();
	 return;
       }
       
       if(OutStreamTemp->n == OutStreamTemp->index)
	 valid = *(buff + IMOTE_HID_NI + 2);
       else
	 valid = IMOTE_HID_SHORT_MAXPACKETDATA;
       
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 2 +
	      (OutStreamTemp->n == OutStreamTemp->index?1:0), valid);
       break;
     case IMOTE_HID_TYPE_L_INT:
       if(OutStreamTemp->index != ((*(buff + IMOTE_HID_NI) << 24) | (*(buff + IMOTE_HID_NI + 1) << 16) | (*(buff + IMOTE_HID_NI + 2) << 8) | *(buff + IMOTE_HID_NI + 3))){
	 //trace("Received packet has incorrect index\r\n");
	 clearOut();
	 free(buff);
	 buff = NULL;
	 _PXAREG(_udcdrb - _udcdr0 + _udccsr0) |= _UDC_bit(UDCCSRAX_PC);
	 //post processOut();
	 return;
       }
       if(OutStreamTemp->n == OutStreamTemp->index)
	 valid = *(buff + IMOTE_HID_NI + 4);
       else
	 valid = IMOTE_HID_INT_MAXPACKETDATA;
       
       OutStreamTemp->src = (uint8_t *)malloc(valid);
       if(OutStreamTemp->src == NULL){
	 DynQueue_push(OutQueue, buff);
	 post processOut();
	 return;
       }
       memcpy(OutStreamTemp->src, buff + IMOTE_HID_NI + 4 + (OutStreamTemp->n == OutStreamTemp->index?1:0), valid);
       break;
     }
   }
   else //assume in this case it can be ignored
     ;
   
   if((OutStreamTemp->type & 0x3) == IMOTE_HID_TYPE_CL_RPACKET)
     signal ReceiveMsg.receive((TOS_MsgPtr) OutStreamTemp->src);
   else if((OutStreamTemp->type & 0x3) == IMOTE_HID_TYPE_CL_BINARY)
     signal ReceiveBData.receive(OutStreamTemp->src, valid,
				 OutStreamTemp->index, OutStreamTemp->n, type);
#ifdef BOOTLOADER
   /** 
    * Added for Boot Loader compatibility, All the messages from the boot loader
    * application will reboot the board. -junaith
    */
   else if ((((OutStreamTemp->type) & 0xE3) == IMOTE_HID_TYPE_MSC_REBOOT) ||
            (((OutStreamTemp->type) & 0xE3) == IMOTE_HID_TYPE_MSC_BINARY) ||
            (((OutStreamTemp->type) & 0xE3) == IMOTE_HID_TYPE_MSC_COMMAND))
   {
      OSMR3 = OSCR0 + 9000;
      OWER = 1;
      while(1);     
   }
#endif
   else
     signal ReceiveData.receive(OutStreamTemp->src, valid);
   
   free(OutStreamTemp->src);
   OutStreamTemp->src = NULL;
   OutStreamTemp->index++;
   free(buff);
   buff = NULL;
   _PXAREG(_udcdrb - _udcdr0 + _udccsr0) |= _UDC_bit(UDCCSRAX_PC);
   /*atomic OutPausedTemp = OutPaused;
     atomic OutTask = 0;
     
     if(DynQueue_getLength(OutQueue) >= 1){
     atomic OutTask = 1;
     post processOut();
     }*/
 }
 
 task void sendIn(){
   uint16_t i = 0;
   uint8_t buf[64];//fifosize
   uint8_t valid;
   DynQueue QueueTemp;
   USBdata InStateTemp;
   
#if DEBUG
   trace("In sendIn;\r\n");
#endif
   atomic QueueTemp = InQueue;
   if(DynQueue_getLength(QueueTemp) <= 0)
     return;
   
   atomic{
     InState = (USBdata)DynQueue_peek(QueueTemp);
     InState->status |= _UDC_bit(MIDSEND);
     InStateTemp = InState;
   }
   if((uint32_t)InStateTemp->param != IMOTE_HID_REPORT){
     sendControlIn();//should never happen
     return;
   }
   
   if(InStateTemp->pindex <= InStateTemp->n)
     if(((InStateTemp->type >> IMOTE_HID_TYPE_L) & 0x3) == IMOTE_HID_TYPE_L_BYTE){
       buf[IMOTE_HID_TYPE] = InStateTemp->type;
       
       if(InStateTemp->pindex == 0){
	 buf[IMOTE_HID_TYPE] |= _UDC_bit(IMOTE_HID_TYPE_H);
	 buf[IMOTE_HID_NI] = InStateTemp->n;
       }
       else
	 buf[IMOTE_HID_NI] = InStateTemp->pindex;
       
       if(InStateTemp->pindex == InStateTemp->n){
	 valid = (uint8_t)(InStateTemp->len % IMOTE_HID_BYTE_MAXPACKETDATA);
	 buf[IMOTE_HID_NI + 1] = valid;
       }
       else
	 valid = (uint8_t)IMOTE_HID_BYTE_MAXPACKETDATA;
       memcpy(buf + IMOTE_HID_NI + 1 + (InStateTemp->pindex==InStateTemp->n?1:0),
	      InStateTemp->src + InStateTemp->pindex * IMOTE_HID_BYTE_MAXPACKETDATA, valid);
     }
     else if(((InStateTemp->type >> IMOTE_HID_TYPE_L) & 0x3) == 
	     IMOTE_HID_TYPE_L_SHORT){
       buf[IMOTE_HID_TYPE] = InStateTemp->type;
       if(InStateTemp->pindex == 0){
	 buf[IMOTE_HID_TYPE] |= _UDC_bit(IMOTE_HID_TYPE_H);
	 buf[IMOTE_HID_NI] = (uint8_t)(InStateTemp->n >> 8);
	 buf[IMOTE_HID_NI + 1] = (uint8_t)InStateTemp->n;
       }
       else{
	 buf[IMOTE_HID_NI] = (uint8_t)(InStateTemp->pindex >> 8);
	 buf[IMOTE_HID_NI + 1] = (uint8_t)InStateTemp->pindex;
       }
       
       if(InStateTemp->pindex == InStateTemp->n){
	 valid = (uint8_t)(InStateTemp->len % IMOTE_HID_SHORT_MAXPACKETDATA);
	 buf[IMOTE_HID_NI + 2] = valid;
       }
       else
	 valid = (uint8_t)IMOTE_HID_SHORT_MAXPACKETDATA;
       memcpy(buf + IMOTE_HID_NI + 2 + (InStateTemp->pindex==InStateTemp->n?1:0),
	      InStateTemp->src + InStateTemp->pindex * IMOTE_HID_SHORT_MAXPACKETDATA, valid);
     }
     else if(((InStateTemp->type >> IMOTE_HID_TYPE_L) & 0x3) ==
	     IMOTE_HID_TYPE_L_INT){
       buf[IMOTE_HID_TYPE] = InStateTemp->type;
       if(InStateTemp->pindex == 0){
	 buf[IMOTE_HID_TYPE] |= _UDC_bit(IMOTE_HID_TYPE_H);
	 buf[IMOTE_HID_NI] = (uint8_t)(InStateTemp->n >> 24);
	 buf[IMOTE_HID_NI + 1] = (uint8_t)(InStateTemp->n >> 16);
	 buf[IMOTE_HID_NI + 2] = (uint8_t)(InStateTemp->n >> 8);
	 buf[IMOTE_HID_NI + 3] = (uint8_t)InStateTemp->n;
       }
       else{
	 buf[IMOTE_HID_NI] = (uint8_t)(InStateTemp->pindex >> 24);
	 buf[IMOTE_HID_NI + 1] = (uint8_t)(InStateTemp->pindex >> 16);
	 buf[IMOTE_HID_NI + 2] = (uint8_t)(InStateTemp->pindex >> 8);
	 buf[IMOTE_HID_NI + 3] = (uint8_t)InStateTemp->pindex;
       }
       
       if(InStateTemp->pindex == InStateTemp->n){
	 valid = (uint8_t)(InStateTemp->len % IMOTE_HID_INT_MAXPACKETDATA);
	 buf[IMOTE_HID_NI + 4] = valid;
       }
       else
	 valid = (uint8_t)IMOTE_HID_INT_MAXPACKETDATA;
       memcpy(buf + IMOTE_HID_NI + 4 + (InStateTemp->pindex == 
					InStateTemp->n?1:0),
	      InStateTemp->src + InStateTemp->pindex * 
	      IMOTE_HID_INT_MAXPACKETDATA, valid);
     }
   /*atomic*/{
     InStateTemp->pindex++;
     if(InStateTemp->index < InStateTemp->tlen)
       while(i < InStateTemp->fifosize){
	 _PXAREG(InStateTemp->endpointDR) = *(uint32_t *)(buf + i);
	 InStateTemp->index += 4;
	 i += 4;
       }
     
     if(InStateTemp->index >= InStateTemp->tlen && InStateTemp->index % InStateTemp->fifosize != 0){
       if(i < InStateTemp->fifosize)
	 _PXAREG(InStateTemp->endpointDR - _udcdr0 + _udccsr0) |= _UDC_bit(InStateTemp->endpointDR == _udcdr0?UDCCSR0_IPR:UDCCSRAX_SP);
       InStateTemp->status &= ~_UDC_bit(MIDSEND);
     }
     else if(InStateTemp->index >= InStateTemp->tlen && InStateTemp->index % InStateTemp->fifosize == 0)
       InStateTemp->index++;
   }
 }
 
 
 void sendControlIn(){
   uint16_t i = 0;
   DynQueue QueueTemp;
   USBdata InStateTemp;
   
   atomic QueueTemp = InQueue;
   if(DynQueue_getLength(QueueTemp) <= 0)
     return;
   
   atomic InState = (USBdata)DynQueue_peek(QueueTemp);
   atomic InStateTemp = InState;
   if((uint32_t)InStateTemp->param != 0)
     return;
   
   atomic InState->status |= _UDC_bit(MIDSEND);
   
   /*atomic*/{
     while(InStateTemp->index < InStateTemp->len && 
	   i < InStateTemp->fifosize){
       if(InStateTemp->len - InStateTemp->index > 3 && 
	  InStateTemp->fifosize - i > 3){
	 _PXAREG(InStateTemp->endpointDR) = *(uint32_t *)(InStateTemp->src +
							  InStateTemp->index);
	 InStateTemp->index += 4;
	 i += 4;
       }
       else{
	 _PXAREG8(InStateTemp->endpointDR) = *(InStateTemp->src + InStateTemp->index);
	 InStateTemp->index++;
	 i++;
       }
     }
     if(InStateTemp->index >= InStateTemp->len && 
	InStateTemp->index % InStateTemp->fifosize != 0){
       if(i < InStateTemp->fifosize)
	 _PXAREG(InStateTemp->endpointDR - _udcdr0 + _udccsr0) |= 
	   _UDC_bit(InStateTemp->endpointDR == 
		    _udcdr0?UDCCSR0_IPR:UDCCSRAX_SP);
       atomic InState->status &= ~_UDC_bit(MIDSEND);
     }
     else if(InStateTemp->index == InStateTemp->len && 
	     InStateTemp->index % InStateTemp->fifosize == 0)
       atomic InState->index++;
   }
 }
 
 void isAttached(){
   uint8_t statetemp;
   
   if(call HPLUSBClientGPIO.checkConnection() == SUCCESS)
#if DEBUG
     trace("Device Attached %d;\r\n", state);
#endif
	//HACK>>>RA....the assumed convention that _UDC_bit uses has been violated by moving the UDCCR_UDE defnition to pxa27x_registers.h..need to fix
   UDCCR |= _UDC_bit(UDCCR_UDE-1);

   
   if((UDCCR & _UDC_bit(UDCCR_EMCE)) != 0)
#if DEBUG
     trace("Memory Configuration Issue");
#else
   ;
#endif
   atomic statetemp = state;
   if(statetemp == 0)
     atomic state = POWERED;
   else{
#if DEBUG
     trace("Device Removed;\r\n");
#endif
     UDCCR &= ~_UDC_bit(UDCCR_UDE);
     atomic state = 0;
     clearIn();
     clearOut();
   }
 }
 
 void sendDeviceDescriptor(uint16_t wLength){
   USBdata InStream;
   uint8_t InTaskTemp;
   DynQueue QueueTemp;
   
#if DEBUG
   trace("Sending device descriptor;\r\n");
#endif
   if(wLength == 0)
     return;
   atomic {
     InStream = (USBdata)malloc(sizeof(USBdata_t));
     
     InStream->endpointDR = _udcdr0;
     InStream->fifosize = 16;
     InStream->src = (uint8_t *)malloc(0x12);
     
     InStream->len = wLength < 0x12?wLength:0x12;
     InStream->index = 0;
     InStream->param = 0;
     
     *(uint32_t *)(InStream->src) = 0x12 | (USB_DESCRIPTOR_DEVICE << 8) | (Device.bcdUSB << 16);
     *(uint32_t *)(InStream->src + 4) = Device.bDeviceClass | (Device.bDeviceSubclass << 8) | (Device.bDeviceProtocol << 16) | (Device.bMaxPacketSize0 << 24);
     
     *(uint32_t *)(InStream->src + 8) = Device.idVendor | (Device.idProduct << 16);
     *(uint32_t *)(InStream->src + 12) = Device.bcdDevice | (Device.iManufacturer << 16) | (Device.iProduct << 24);
     *(InStream->src + 16) = Device.iSerialNumber;
     *(InStream->src + 17) = Device.bNumConfigurations;
     
     atomic InTaskTemp = InTask;
     atomic QueueTemp = InQueue;
     DynQueue_enqueue(QueueTemp, InStream);
     if(DynQueue_getLength(QueueTemp) == 1 && InTaskTemp == 0){
       atomic InTask = 1;
       sendControlIn();
     }
   }
 }
 
 void sendConfigDescriptor(uint8_t id, uint16_t wLength){
   USBconfiguration Config;
   USBinterface Inter;
   USBendpoint EndpointIn, EndpointOut;
   USBdata InStream;
   uint8_t InTaskTemp;
   DynQueue QueueTemp;
   
#if DEBUG   
   trace("Sending config descriptor; ID: %x\r\n", id);
#endif
   
   if(wLength == 0)
     return;
   atomic{
     Config = Device.oConfigurations[1];
     Inter = Config->oInterfaces[0];
     EndpointIn = Inter->oEndpoints[0];
     EndpointOut = Inter->oEndpoints[1];
     
     InStream = (USBdata)malloc(sizeof(USBdata_t));
     
     InStream->endpointDR = _udcdr0;
     InStream->fifosize = 16;
     InStream->src = (uint8_t *)malloc(Config->wTotalLength);
     
     InStream->len = wLength < Config->wTotalLength?wLength:Config->wTotalLength;
     InStream->index = 0;
     InStream->param = 0;
     
     *(uint32_t *)(InStream->src) = 0x09 | (USB_DESCRIPTOR_CONFIGURATION << 8) | (Config->wTotalLength<< 16);
     *(uint32_t *)(InStream->src + 4) = Config->bNumInterfaces | (Config->bConfigurationID << 8) | (Config->iConfiguration << 16) | (Config->bmAttributes << 24);
     
     *(uint32_t *)(InStream->src + 8) = Config->MaxPower | (0x09 << 8) | (USB_DESCRIPTOR_INTERFACE << 16) | (Inter->bInterfaceID << 24);
     
     *(uint32_t *)(InStream->src + 12) = Inter->bAlternateSetting | (Inter->bNumEndpoints << 8) | (Inter->bInterfaceClass << 16) | (Inter->bInterfaceSubclass << 24);
     
     *(uint32_t *)(InStream->src + 16) = Inter->bInterfaceProtocol | (Inter->iInterface << 8) | (0x09 << 16) | (USB_DESCRIPTOR_HID << 24);
     *(uint32_t *)(InStream->src + 20) = Hid.bcdHID | (Hid.bCountryCode << 16) | (Hid.bNumDescriptors << 24);
     *(uint32_t *)(InStream->src + 24) = USB_DESCRIPTOR_HID_REPORT | (Hid.wDescriptorLength << 8) | (0x07 << 24);
     *(uint32_t *)(InStream->src + 28) = USB_DESCRIPTOR_ENDPOINT | (EndpointIn->bEndpointAddress << 8) | (EndpointIn->bmAttributes << 16) | (EndpointIn->wMaxPacketSize << 24);
     *(uint32_t *)(InStream->src + 32) = ((EndpointIn->wMaxPacketSize >> 8) & 0xFF) | (EndpointIn->bInterval << 8) | (0x07 << 16) | (USB_DESCRIPTOR_ENDPOINT << 24);
     *(uint32_t *)(InStream->src + 36) =  EndpointOut->bEndpointAddress | (EndpointOut->bmAttributes << 8) | (EndpointOut->wMaxPacketSize << 16);
     *(uint8_t *)(InStream->src + 40) = EndpointOut->bInterval;
     
     
     atomic InTaskTemp = InTask;
     atomic QueueTemp = InQueue;
     DynQueue_enqueue(QueueTemp, InStream);
     if(DynQueue_getLength(QueueTemp) == 1 && InTaskTemp == 0){
       atomic InTask = 1;
       sendControlIn();
     }
   }
 }
 
 void sendStringDescriptor(uint8_t id, uint16_t wLength){
   USBstring str;
   uint8_t count = 0, InTaskTemp;
   uint8_t *src = NULL;
   USBdata InStream = NULL;
   DynQueue QueueTemp;
   
   str = Strings[id];
   
#if DEBUG
   trace("Sending string descriptor; ID: %x\r\n", id);
#endif
   if(wLength == 0)
     return;
   atomic{
     InStream = (USBdata)malloc(sizeof(USBdata_t));
     InStream->endpointDR = _udcdr0;
     InStream->fifosize = 16;
     InStream->src = (uint8_t *)malloc(str->bLength);
     InStream->param = 0;
     
#if ASSERT
     if(InStream->src == NULL){
       trace("Assert Fired; %s:%d\r\n",__FILE__,__LINE__ - 2);
     }       
#endif
     
     InStream->len = wLength < str->bLength?wLength:str->bLength;
     InStream->index = 0;
     
     if(id == 0)
       *(uint32_t *)(InStream->src) = str->bLength | (USB_DESCRIPTOR_STRING << 8) | (str->uMisc.wLANGID << 16);
     else{
       src = str->uMisc.bString;
#if DEBUG
       trace("%s\r\n", src);
#endif
       
       *(uint32_t *)(InStream->src) = str->bLength | (USB_DESCRIPTOR_STRING << 8) | (*src << 16);
       src++;
       for(count = 1; *src != '\0'; count++, src++){
	 if(*(src + 1) == '\0'){
	   *(InStream->src + count * 4) = (uint8_t)*src;
	   *(InStream->src + count * 4 + 1) = (uint8_t)0;
	 }
	 else{
	   *(uint32_t *)(InStream->src + count * 4) = *src | (*(src+1) << 16);
	   src++;
	 }
       }
     }
     
     atomic InTaskTemp = InTask;
     atomic QueueTemp = InQueue;
     DynQueue_enqueue(QueueTemp, InStream);
     if(DynQueue_getLength(QueueTemp) == 1 && InTaskTemp == 0){
       atomic InTask = 1;
       sendControlIn();
     }
   }
 }
 
 void sendHidReportDescriptor(uint16_t wLength){
   USBdata InStream;
   uint8_t InTaskTemp;
   DynQueue QueueTemp;
   
#if DEBUG
   atomic QueueTemp = InQueue;
   trace("Sending hid report descriptor %d;\r\n", DynQueue_getLength(QueueTemp));
#endif   
   
   if(wLength == 0)
     return;
   atomic{
     InStream = (USBdata)malloc(sizeof(USBdata_t));
     
     InStream->endpointDR = _udcdr0;
     InStream->fifosize = 16;
     InStream->src = (uint8_t *)malloc(HidReport.wLength);
     
     InStream->len = wLength < HidReport.wLength?wLength:HidReport.wLength;
     InStream->index = 0;
     InStream->param = 0;
     
     memcpy(InStream->src, HidReport.bString, HidReport.wLength);
     
     atomic InTaskTemp = InTask;
     atomic QueueTemp = InQueue;
     DynQueue_enqueue(QueueTemp, InStream);
     if(DynQueue_getLength(QueueTemp) == 1 && InTaskTemp == 0){
       atomic InTask = 1;
       sendControlIn();
     }
     atomic state = CONFIGURED;
   }
 }
 
 void writeHidDescriptor(){
   atomic{
     Hid.bcdHID = 0x0110;
     Hid.bCountryCode = 0;
     Hid.bNumDescriptors = 1;
     Hid.bDescriptorType = USB_DESCRIPTOR_HID_REPORT;
     Hid.wDescriptorLength = 0x22;
   }
 }
 
 void writeHidReportDescriptor(){
   atomic{
     HidReport.wLength = Hid.wDescriptorLength;
     HidReport.bString = (uint8_t *)malloc(HidReport.wLength);
     *(uint32_t *)(HidReport.bString) = 0x06 | (0xA0 << 8) | (0xFF << 16) | (0x09 << 24);
     *(uint32_t *)(HidReport.bString + 4) = 0xA5 | (0xA1 << 8) | (0x01 << 16) | (0x09 << 24);
     *(uint32_t *)(HidReport.bString + 8) = 0xA6 | (0x09 << 8) | (0xA7 << 16) | (0x15 << 24);
     *(uint32_t *)(HidReport.bString + 12) = 0x80 | (0x25 << 8) | (0x7F << 16) | (0x75 << 24);
     *(uint32_t *)(HidReport.bString + 16) = 0x08 | (0x95 << 8) | (0x40 << 16) | (0x81 << 24);
     *(uint32_t *)(HidReport.bString + 20) = 0x02 | (0x09 << 8) | (0xA9 << 16) | (0x15 << 24);
     *(uint32_t *)(HidReport.bString + 24) = 0x80 | (0x25 << 8) | (0x7F << 16) | (0x75 << 24);
     *(uint32_t *)(HidReport.bString + 28) = 0x08 | (0x95 << 8) | (0x40 << 16) | (0x91 << 24);
     *(uint8_t *)(HidReport.bString + 32) = 0x02;
     *(uint8_t *)(HidReport.bString + 33) = 0xC0;
   }
 }
 
 void writeStringDescriptor(){
   uint8_t i;
   char *buf = (char *)malloc(80); /*requires special freeing in 
				     clearDescriptors()*/
   atomic{
     for(i = 0; i < STRINGS_USED + 1; i++)
       Strings[i] = (USBstring)malloc(sizeof(__string_t));
     
     Strings[0]->bLength = 4;
     Strings[0]->uMisc.wLANGID = 0x0409;
     
     Strings[1]->uMisc.bString = "SNO";
     Strings[2]->uMisc.bString = "Intel Mote 2 Embedded Device";
     
     sprintf(buf, "%x", call UID.getUID());
     realloc(buf, strlen(buf) + 1);
     Strings[3]->uMisc.bString = buf; //serial number 
     
     for(i = 1; i < STRINGS_USED + 1; i++)
       Strings[i]->bLength = 2 + 2 * strlen(Strings[i]->uMisc.bString);
   }
 }
 
 void writeEndpointDescriptor(USBendpoint *endpoints, uint8_t config, uint8_t inter, uint8_t i){
   USBendpoint End;
   End = (USBendpoint)malloc(sizeof(__endpoint_t));
   
   endpoints[i] = End;
   End->bEndpointAddress = i + 1;
   switch(config){
   case 1:
     switch(inter){
     case 0:
       switch(i){
       case 0:
	 End->bEndpointAddress |= _UDC_bit(USB_ENDPOINT_IN);
	 End->bmAttributes = 0x3;
	 End->wMaxPacketSize = 0x40;
	 End->bInterval = 0x01;
	 
	 UDCCRA |= (1 << 25) | ((End->bEndpointAddress & 0xF) << 15) | ((End->bmAttributes & 0x3) << 13) | (((End->bEndpointAddress & _UDC_bit(USB_ENDPOINT_IN)) != 0) << 12) | (End->wMaxPacketSize << 2) | 1;
	 break;
       case 1:
	 End->bmAttributes = 0x3;
	 End->wMaxPacketSize = 0x40;
	 End->bInterval = 0x01;
	 
	 UDCCRB |= (1 << 25) | ((End->bEndpointAddress & 0xF) << 15) | ((End->bmAttributes & 0x3) << 13) | (((End->bEndpointAddress & _UDC_bit(USB_ENDPOINT_IN)) != 0) << 12) | (End->wMaxPacketSize << 2) | 1;
	 break;
       }
       break;
     }
     break;
   }
 }
 
 uint16_t writeInterfaceDescriptor(USBinterface *interfaces, uint8_t config, uint8_t i){
   uint8_t j;
   uint16_t length;
   USBinterface Inter;
   Inter = (USBinterface)malloc(sizeof(__interface_t));
   
   interfaces[i] = Inter;
   length = 9;
   Inter->bInterfaceID = i;
   switch(config){
   case 0:
     switch(i){
     case 0:
       Inter->bAlternateSetting = 0;
       Inter->bNumEndpoints = 0;
       Inter->bInterfaceClass = 0;
       Inter->bInterfaceSubclass = 0;
       Inter->bInterfaceProtocol = 0;
       Inter->iInterface = 0;
       break;
     }
     break;
   case 1:
     switch(i){
     case 0:
       Inter->bAlternateSetting = 0;
       Inter->bNumEndpoints = 2;
       Inter->bInterfaceClass = 0x03;
       Inter->bInterfaceSubclass = 0x00;
       Inter->bInterfaceProtocol = 0x00;
       Inter->iInterface = 0;
       length += 0x09;
       break;
     }
   }
   
   if(Inter->bNumEndpoints > 0){
     Inter->oEndpoints = (USBendpoint *)malloc(sizeof(__endpoint_t) * Inter->bNumEndpoints);
     
     length += Inter->bNumEndpoints * 7;
     for(j = 0; j < Inter->bNumEndpoints; j++)
       writeEndpointDescriptor(Inter->oEndpoints, config,i,j);
   }
   return length;
 }
 
 void writeConfigurationDescriptor(USBconfiguration *configs, uint8_t i){
   uint8_t j;
   USBconfiguration Config;
   Config = (USBconfiguration)malloc(sizeof(__configuration_t));
   
   configs[i] = Config;
   Config->wTotalLength = 9;
   Config->bConfigurationID = i;
   
   switch(i){
   case 0: 
     Config->bNumInterfaces = 1;
     Config->iConfiguration = 0;
     Config->bmAttributes = 0x80;
     Config->MaxPower = USBPOWER; 
     break;
   case 1:
     Config->bNumInterfaces = 1;
     Config->iConfiguration = 0;
     Config->bmAttributes = 0x80;
     Config->MaxPower = USBPOWER; 
   }
   
   Config->oInterfaces = (USBinterface *)malloc(sizeof(__interface_t) * Config->bNumInterfaces);
   
   for(j = 0; j < Config->bNumInterfaces; j++)
     Config->wTotalLength += writeInterfaceDescriptor(Config->oInterfaces, i,j);
   
 }
 
 void writeDeviceDescriptor(){
   uint8_t i;
   atomic{
     Device.bcdUSB = 0x0110;
     Device.bDeviceClass = Device.bDeviceSubclass = Device.bDeviceProtocol = 0;
     Device.bMaxPacketSize0 = 16;
     Device.idVendor = 0x042b;
     Device.idProduct = 0x1337;
     Device.bcdDevice = 0x0312;
     Device.iManufacturer = 1;
     Device.iProduct = 2;
     Device.iSerialNumber = 3;
     Device.bNumConfigurations = 2;
     Device.oConfigurations = (USBconfiguration *)malloc(sizeof(__configuration_t) * Device.bNumConfigurations);     
     
   }
   for(i = 0; i < Device.bNumConfigurations; i++)
     writeConfigurationDescriptor(Device.oConfigurations, i);
 }
 
 void clearDescriptors(){
   uint8_t i, j, k;
   for(i = 0; i < Device.bNumConfigurations; i++){
     for(j = 0; j < Device.oConfigurations[i]->bNumInterfaces; j++){
       for(k = 0; k < Device.oConfigurations[i]->oInterfaces[j]->bNumEndpoints; k++)
	 free(Device.oConfigurations[i]->oInterfaces[j]->oEndpoints[k]);
       free(Device.oConfigurations[i]->oInterfaces[j]->oEndpoints);
       free(Device.oConfigurations[i]->oInterfaces[j]);
     }
     free(Device.oConfigurations[i]->oInterfaces);
     free(Device.oConfigurations[i]);
   }
   free(Device.oConfigurations);
   for(i = 0; i < STRINGS_USED + 1; i++){
     if(i == 3)//serial num, special freeing mentioned in writeStringDescriptor
       free(Strings[i]->uMisc.bString);
     free(Strings[i]);
   }
   free(HidReport.bString);
 }
 
 void clearIn(){
   DynQueue QueueTemp;
   atomic QueueTemp = InQueue;
   atomic{
     while(DynQueue_getLength(QueueTemp) > 0){
       uint8_t temp;
       InState = (USBdata)DynQueue_dequeue(QueueTemp);
       temp = ((uint32_t)InState->param == IMOTE_HID_REPORT);
       clearUSBdata(InState, temp);
     }
     InState = NULL;
     InTask = 0;
   }
 }
 
 void clearUSBdata(USBdata Stream, uint8_t isConst){
   atomic{
     if(isConst == 0)
       free(Stream->src);
     Stream->src = NULL;
     free(Stream);
     Stream = NULL;
   }
 }
 
 void clearOut(){
   uint8_t i;
   atomic{
     for(i = 0; i < IMOTE_HID_TYPE_COUNT; i++){
       free(OutStream[i].src);
       OutStream[i].endpointDR = NULL;
       OutStream[i].src = NULL;
       OutStream[i].status = 0;
       OutStream[i].type = 0;
       OutStream[i].index = 0;
       OutStream[i].n = 0;
       OutStream[i].len = 0;
     }
   }
 }
 
 void clearOutQueue(){
   while(DynQueue_getLength(OutQueue) > 0)
     free((uint8_t *)DynQueue_dequeue(OutQueue));
 } 
}
