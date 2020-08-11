includes CountMsg;

configuration SendRSSI {
}
implementation {
  components Main
           , SendRSSIM
           , TimerC
           , LedsC
           , GenericComm
           ;
           
  Main.StdControl -> TimerC;
  Main.StdControl -> GenericComm;
  Main.StdControl -> SendRSSIM;
  
  SendRSSIM.Timer   -> TimerC.Timer[unique("Timer")];
  SendRSSIM.Leds    -> LedsC;
  SendRSSIM.SendMsg -> GenericComm.SendMsg[AM_COUNT_MSG];
}
