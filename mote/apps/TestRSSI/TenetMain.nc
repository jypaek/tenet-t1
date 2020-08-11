includes element_map;
includes CountMsg;

configuration TenetMain {
}
implementation {
  components Main, TimerC, GenericComm, LedsC,
    TenetMainM, Scheduler, MemoryM, TaskLib, 
    Install, RecvFrom, SendTo, Wait, Gate,
    LocalTimeC,
#ifdef FASTSAMPLE
    FastSample,
#ifdef PLATFORM_TELOSB
    MSP430DMAC, MSP430ADC12C,
#endif
    new AsyncToSyncQueue() as FSQ0,
    new AsyncToSyncQueue() as FSQ1,
    new AsyncToSyncQueue() as FSQ2
#else
#ifdef PLATFORM_TELOSB
    MSP430ADC12C,
#endif
    SlowSample as Sample, SampleRSSI
#endif
    ;

  Main.StdControl -> TimerC;
  Main.StdControl -> GenericComm;
  Main.StdControl -> TenetMainM;
  Main.StdControl -> Install;
  Main.StdControl -> RecvFrom;
  Main.StdControl -> SendTo;
  Main.StdControl -> Wait;
  Main.StdControl -> Gate;
  
  Main.StdControl -> Sample;
  Sample.TenetTask     -> TaskLib;
  Sample.List -> TaskLib;
  Install.Element_u[ ELEMENT_SLOWSAMPLE ] -> Sample.Element;
  Sample.Schedule      -> Scheduler;
  Sample.Memory     -> MemoryM;
  Sample.ADC -> SampleRSSI;
  SampleRSSI.ReceiveMsg -> GenericComm.ReceiveMsg[AM_COUNT_MSG];
  SampleRSSI.Leds -> LedsC;
  Sample.Timer -> TimerC.Timer[unique("Timer")];
  Sample.LocalTime -> LocalTimeC;
  Sample.LocalTimeInfo -> LocalTimeC;
  Sample.Leds -> LedsC;


  TenetMainM.TenetTask -> TaskLib;
  Install.TenetTask    -> TaskLib;
  RecvFrom.TenetTask   -> TaskLib;
  SendTo.TenetTask     -> TaskLib;
  Wait.TenetTask       -> TaskLib;
  Gate.TenetTask       -> TaskLib;
  Scheduler.TenetTask  -> TaskLib;

  Scheduler.List -> TaskLib;
  RecvFrom.List -> TaskLib;
  SendTo.List -> TaskLib;
  Wait.List -> TaskLib;
  Install.List -> TaskLib;

  /* to install the install task */

  TenetMainM.Element[ ELEMENT_INSTALL  ] -> Install.Element;
  TenetMainM.Element[ ELEMENT_RECVFROM ] -> RecvFrom.Element;

  /* to install arbitrary tasks */

  Install.Element_u[ ELEMENT_INSTALL    ] -> Install.Element;
  Install.Element_u[ ELEMENT_RECVFROM   ] -> RecvFrom.Element;
  Install.Element_u[ ELEMENT_SENDTO     ] -> SendTo.Element;
  Install.Element_u[ ELEMENT_WAIT       ] -> Wait.Element;
  Install.Element_u[ ELEMENT_GATE       ] -> Gate.Element;

  TenetMainM.Schedule  -> Scheduler;
  Install.Schedule     -> Scheduler;
  RecvFrom.Schedule    -> Scheduler;
  SendTo.Schedule      -> Scheduler;
  Wait.Schedule        -> Scheduler;
  Gate.Schedule        -> Scheduler;

  TaskLib.Memory    -> MemoryM;
  Install.Memory    -> MemoryM;
  RecvFrom.Memory   -> MemoryM;
  SendTo.Memory     -> MemoryM;
  Wait.Memory       -> MemoryM;
  Gate.Memory       -> MemoryM;

  Wait.Leds       -> LedsC;
  //SendTo.Leds     -> LedsC;
  //Scheduler.Leds  -> LedsC;

  RecvFrom.ReceiveMsg -> GenericComm.ReceiveMsg[PORT_TENET];
#ifdef TESTING
  RecvFrom.ReceiveMsg -> TenetMainM.ReceiveMsg;
#endif
  SendTo.SendMsg -> GenericComm.SendMsg[PORT_TENET];
  Wait.Timer -> TimerC.Timer[unique("Timer")];
  Wait.LocalTime -> LocalTimeC;
  Wait.LocalTimeInfo -> LocalTimeC;

#ifdef TESTING
  TenetMainM.Timer -> TimerC.Timer[unique("Timer")];
#endif
}

