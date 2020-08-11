configuration UartCommC {
  provides {
    interface StdControl as UartControl;
    interface UartCommI as UartComm;
  }
}
implementation {
  components UartCommM, LedsC;

  // Interface wiring
  UartControl = UartCommM.UartControl;
  UartComm    = UartCommM.UartComm;

  // Component wiring
  UartCommM.Leds -> LedsC;
}
