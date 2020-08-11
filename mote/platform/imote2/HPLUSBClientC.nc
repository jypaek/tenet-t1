/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */
#include "HPLUSBClient.h"

configuration HPLUSBClientC {
  provides{
    interface StdControl as Control;
    interface SendVarLenPacket;
    interface SendJTPacket[uint8_t channel];
    interface ReceiveData;
    interface ReceiveMsg;
    interface ReceiveBData;
    interface BareSendMsg;
  }
}

implementation {
  components
    Main,
    UIDC,
    HPLUSBClientGPIOM,
    PXA27XGPIOIntC,
    PXA27XUSBClientC;
  
  Control = PXA27XUSBClientC;
  SendVarLenPacket = PXA27XUSBClientC;
  SendJTPacket = PXA27XUSBClientC;
  BareSendMsg = PXA27XUSBClientC;
  ReceiveData = PXA27XUSBClientC;
  ReceiveMsg = PXA27XUSBClientC;
  ReceiveBData = PXA27XUSBClientC;
  
  Main.StdControl -> PXA27XGPIOIntC;
  PXA27XUSBClientC -> PXA27XGPIOIntC.PXA27XGPIOInt[USBC_GPION_DET];
  PXA27XUSBClientC.HPLUSBClientGPIO -> HPLUSBClientGPIOM;

  PXA27XUSBClientC.UID -> UIDC;
}
