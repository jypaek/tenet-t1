configuration TestDaq {

}
implementation {
  components Main, TestDaqM, LedsC, TimerC, DaqC;

  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> TestDaqM.StdControl;
  
  TestDaqM.Timer -> TimerC.Timer[unique("Timer")];
  TestDaqM.Leds -> LedsC;
  TestDaqM.ADConvert2 -> DaqC;
  TestDaqM.SetParam2 -> DaqC;
  TestDaqM.DaqControl -> DaqC;
}
