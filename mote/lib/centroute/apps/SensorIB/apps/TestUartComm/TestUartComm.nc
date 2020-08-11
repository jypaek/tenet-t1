configuration TestUartComm {
  //provides interface StdControl;

  //uses interface StdControl as UartControl;
  //uses interface UartCommI as UartComm;
}
implementation {
  components Main, TestUartCommM, LedsC, TimerC, UartCommC;

  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> TestUartCommM.StdControl;
  
  TestUartCommM.Timer -> TimerC.Timer[unique("Timer")];
  TestUartCommM.Leds -> LedsC;
  TestUartCommM.UartComm -> UartCommC;
  TestUartCommM.UartControl -> UartCommC;
}
