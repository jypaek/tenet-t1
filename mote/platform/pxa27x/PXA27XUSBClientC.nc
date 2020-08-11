/* 
  * Author:		Josh Herbach
  * Revision:	1.0
  * Date:		09/02/2005
  */

#include "PXA27XUSBClient.h"

/*
 * It is assumed that anyone who sends data will not modify their send buffer
 * until they receive the senddone event
 *
*/

configuration PXA27XUSBClientC {
  provides{
    interface SendVarLenPacket;
    interface SendJTPacket[uint8_t channel];
    interface ReceiveData;
    interface ReceiveMsg;
    interface ReceiveBData;
    interface BareSendMsg;
    interface StdControl as Control;
  }
  uses{
    interface UID;
    interface PXA27XGPIOInt;
    interface HPLUSBClientGPIO;
  }
}
implementation {
  components Main, PXA27XUSBClientM, PXA27XInterruptM;
  
  SendVarLenPacket = PXA27XUSBClientM;
  SendJTPacket = PXA27XUSBClientM;
  BareSendMsg = PXA27XUSBClientM;
  ReceiveData = PXA27XUSBClientM;
  ReceiveMsg = PXA27XUSBClientM;
  ReceiveBData = PXA27XUSBClientM;
  
  Main.StdControl -> PXA27XUSBClientM;
  Control = PXA27XUSBClientM;
  
  PXA27XUSBClientM.USBInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_USBC];
  PXA27XUSBClientM.USBAttached = PXA27XGPIOInt;
  PXA27XUSBClientM = UID;
  PXA27XUSBClientM = HPLUSBClientGPIO;
}
