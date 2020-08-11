
includes mDTN;
#ifdef USE_SYMPATHY
includes Sympathy;
#endif
includes eeprom_logger;
configuration ESS_mDTNC {
	    provides interface StdControl;
	    provides interface mDTNSendI[uint8_t id];
	    provides interface mDTNRecvI[uint8_t id];
	    provides interface mDTNSendRawI;
	    provides interface mDTNRecvRawI;
}implementation {
  components Main,
    ESS_mDTNM,
#ifdef USE_ROUTE_ADAPTATION
    RouteToAppC,
#else
    ESS_mDTNRouting_MultihopC,
#endif // USE_ROUTE_ADAPTATION
    MultiAccessQueueC,
#ifdef EMSTAR_NO_KERNEL
  EmTimerC,
#else
  TimerC,
#endif
#ifdef STAT_TRACKER
    StatTrackerM,
#endif
#ifdef USE_SYMPATHY
  SReturnStateM,
#endif
#ifdef NODE_HEALTH
    NodeHealthC,
#endif
    MyLedsC;


  StdControl = ESS_mDTNM.StdControl;
  mDTNSendI = ESS_mDTNM.mDTNSendI;
  mDTNRecvI = ESS_mDTNM.mDTNRecvI;
  mDTNSendRawI =  ESS_mDTNM.mDTNSendRawI;
  mDTNRecvRawI =  ESS_mDTNM.mDTNRecvRawI;

  Main.StdControl -> ESS_mDTNM.StdControl;

#ifdef USE_ROUTE_ADAPTATION
  ESS_mDTNM.ApplicationI -> RouteToAppC.ApplicationI;
#else
  ESS_mDTNM.mDTNRoutingI -> ESS_mDTNRouting_MultihopC.mDTNRoutingI;
  //ESS_mDTNM.RecvQueueI -> MultiAccessQueueC.SequentialQueueI[unique("MultiAccessQueue")];
#endif
  ESS_mDTNM.SendQueueI -> MultiAccessQueueC.SequentialQueueI[unique("MultiAccessQueue")];
  ESS_mDTNM.Leds -> MyLedsC;
#ifdef EMSTAR_NO_KERNEL
  ESS_mDTNM.ForwardTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
  ESS_mDTNM.ForwardTimer -> TimerC.Timer[unique("Timer")];
#endif

#ifdef STAT_TRACKER
  ESS_mDTNM.FreeSpaceQueryI -> StatTrackerM.FreeSpaceQueryI;
#endif

#ifdef USE_SYMPATHY
  ESS_mDTNM.ProvideCompMetrics -> SReturnStateM.ProvideCompMetrics[SCOMP_STATS3];
#endif
#ifdef NODE_HEALTH
  ESS_mDTNM.NodeHealthI -> NodeHealthC.NodeHealthI;
#endif

}
