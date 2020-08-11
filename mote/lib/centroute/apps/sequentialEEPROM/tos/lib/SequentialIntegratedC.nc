
includes eeprom_logger;
configuration SequentialIntegratedC {
  provides interface StdControl;
  provides interface SequentialQueueI;
  
#ifdef STAT_TRACKER
  provides interface FreeSpaceQueryI;
#endif
  
  
}implementation {
  components Main,
    SequentialRLTM,
    SequentialPageMetaM,
    PageEEPROMC,
    SequentialIntegratedM,
#ifdef STAT_TRACKER
    StatTrackerM,
#endif
    MyLedsC;

  StdControl = SequentialRLTM.StdControl;
  StdControl = PageEEPROMC;
  StdControl = SequentialPageMetaM.StdControl;
  StdControl = SequentialIntegratedM.StdControl;



  SequentialQueueI = SequentialIntegratedM.SequentialQueueI;
#ifdef STAT_TRACKER
  FreeSpaceQueryI = SequentialIntegratedM.FreeSpaceQueryI;
#endif

  
  SequentialRLTM.SequentialPageMetaI -> SequentialPageMetaM.SequentialPageMetaI;
  SequentialRLTM.Leds -> MyLedsC;
  SequentialPageMetaM.PageEEPROM -> PageEEPROMC.PageEEPROM[PAGE_META];
  SequentialPageMetaM.Leds -> MyLedsC.Leds;

  SequentialIntegratedM.SequentialRLTI -> SequentialRLTM.SequentialRLTI;
  
  SequentialIntegratedM.Leds -> MyLedsC;

  SequentialIntegratedM.PageEEPROM -> PageEEPROMC.PageEEPROM[SEQUENTIAL_EEPROM];

#ifdef STAT_TRACKER
  StatTrackerM.ActualFreeSpaceQueryI -> SequentialIntegratedM.FreeSpaceQueryI;
#endif


}
