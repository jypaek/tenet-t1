includes ResetCount;

configuration ResetCountC {
  provides interface StdControl;
  provides interface ResetCountI;
}
implementation {
  components 
    Main,
    ResetCountM,
    LedsC;

  StdControl = ResetCountM.StdControl;

  Main.StdControl -> ResetCountM.StdControl;

  ResetCountI = ResetCountM.ResetCountI;

  ResetCountM.Leds -> LedsC;
}
