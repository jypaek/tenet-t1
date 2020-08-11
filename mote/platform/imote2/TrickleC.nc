/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */
configuration TrickleC {
  provides interface StdControl as Control;
}
implementation {
  components 
    TrickleM,
    HPLUSBClientC,
    FlashC;
 
  Control = TrickleM;
  
  TrickleM.USBControl -> HPLUSBClientC.Control;
  TrickleM.ReceiveBData -> HPLUSBClientC;
  TrickleM.SendJTPacket -> HPLUSBClientC;
  TrickleM.Flash -> FlashC;
}
