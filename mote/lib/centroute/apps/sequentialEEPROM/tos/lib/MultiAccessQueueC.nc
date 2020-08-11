
includes eeprom_logger;
configuration MultiAccessQueueC {
	    provides interface StdControl;
	    provides interface SequentialQueueI[uint8_t id];

}implementation {
  components Main,
    SequentialIntegratedC,
    //SequentialQueueC,
    MultiAccessQueueM,
#ifdef DIST_STORAGE
    DistControllerM,
    StorageEstimatorM,
    AppAckCommC,
    StatTrackerM,
    LinkEstimatorM,
    RandomLFSR,
    BeaconTOSM_DistStorage,
    TimerC,
    QueuedSend,
    GenericComm as Comm,
#endif

    MyLedsC;
    
  StdControl = MultiAccessQueueM.StdControl;
  SequentialQueueI = MultiAccessQueueM.SequentialQueueI;
  
  Main.StdControl -> MultiAccessQueueM.StdControl;
  Main.StdControl -> SequentialIntegratedC.StdControl;
  //Main.StdControl -> SequentialQueueC.StdControl;
 
#ifdef DIST_STORAGE
  Main.StdControl -> DistControllerM.StdControl;
  Main.StdControl -> StorageEstimatorM.StdControl;
#endif

  MultiAccessQueueM.SingleQueueI -> SequentialIntegratedC.SequentialQueueI;
  //MultiAccessQueueM.SingleQueueI -> SequentialQueueC.SequentialQueueI;
  MultiAccessQueueM.Leds -> MyLedsC;

#ifdef DIST_STORAGE
  MultiAccessQueueM.DistControllerI -> DistControllerM.DistControllerI;
  DistControllerM.SequentialQueueI -> MultiAccessQueueM.SequentialQueueI[unique("MultiAccessQueue")];
  DistControllerM.Random -> RandomLFSR;
  DistControllerM.AppAckI -> AppAckCommC.AppAckI[DIST_STORAGE_APPACK];
  DistControllerM.FreeSpaceQueryI -> StatTrackerM.FreeSpaceQueryI;
  DistControllerM.StorageEstI -> StorageEstimatorM.StorageEstI;

  StorageEstimatorM.Random -> RandomLFSR.Random;
  StorageEstimatorM.FreeSpaceQueryI -> StatTrackerM.FreeSpaceQueryI;
  StorageEstimatorM.BeaconI -> BeaconTOSM_DistStorage.BeaconI;
  StorageEstimatorM.LinkEstimatorI -> LinkEstimatorM.LinkEstimatorI;

  BeaconTOSM_DistStorage.Random -> RandomLFSR.Random;
  BeaconTOSM_DistStorage.BeaconTimer -> TimerC.Timer[unique("Timer")];
  BeaconTOSM_DistStorage.SendMsg -> QueuedSend.SendMsg[STORAGE_BEACON];
  BeaconTOSM_DistStorage.ReceiveMsg -> Comm.ReceiveMsg[STORAGE_BEACON];

#endif

}
