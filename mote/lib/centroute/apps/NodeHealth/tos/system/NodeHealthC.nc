includes NodeHealth;

configuration NodeHealthC {
  provides interface StdControl;
  provides interface NodeHealthI;
}
implementation {
  components 
    Main,
    NodeHealthM,
#ifdef EMSTAR_NO_KERNEL
    EmTimerC,
#else
    TimerC,
#endif 
   EssSysTimeC,
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    WatchDogHWC,
#endif
    LedsC;

  StdControl = NodeHealthM.StdControl;

  Main.StdControl -> NodeHealthM.StdControl;

  NodeHealthI = NodeHealthM.NodeHealthI;

  NodeHealthM.Leds -> LedsC;

#ifdef EMSTAR_NO_KERNEL
  NodeHealthM.NodeHealthTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
  NodeHealthM.NodeHealthTimer -> TimerC.Timer[unique("Timer")];
#endif

  NodeHealthM.EssSysTimeI -> EssSysTimeC;
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
  NodeHealthM.WatchDogHWI -> WatchDogHWC;
#endif
}
