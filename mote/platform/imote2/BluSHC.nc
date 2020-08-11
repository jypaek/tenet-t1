/* 
 * Edits:		Josh Herbach
 * Revision:	1.1
 * Date:		09/02/2005
 */

#ifndef USE_USB
#define USE_USB 1
#endif

configuration BluSHC {
  provides interface StdControl;
  uses interface BluSH_AppI[uint8_t id];
}
implementation {
  components 
  BufferedSTUARTC as UARTBuffer,
    //DebugUARTBufferC as UARTBuffer,
#if USE_USB    
    HPLUSBClientC as USBClient,
#endif
    BluSHM;

  StdControl = BluSHM;

#if USE_USB
  BluSHM.USBSend -> USBClient.SendJTPacket[unique("JTPACKET")];
  BluSHM.USBReceive -> USBClient.ReceiveData;
#endif

  BluSHM.UartControl -> UARTBuffer.Control;
  BluSHM.UartSend -> UARTBuffer.SendData;
  BluSHM.UartReceive -> UARTBuffer.ReceiveData;
  
  BluSH_AppI = BluSHM;
}
