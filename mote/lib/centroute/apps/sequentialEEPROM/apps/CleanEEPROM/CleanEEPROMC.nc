
includes eeprom_logger;
configuration CleanEEPROMC {
	provides{
		interface StdControl;
	}uses{
		interface Timer;
		interface Leds;
		interface PageEEPROM;
	}

}
implementation {
  components Main,
  			CleanEEPROMM,
  			PageEEPROMC,
  			LedsC,
  			TimerC;

  StdControl=CleanEEPROMM.StdControl;
  Timer = CleanEEPROMM.Timer;
  Leds = CleanEEPROMM.Leds;
  PageEEPROM = CleanEEPROMM.PageEEPROM;

  Main.StdControl -> TimerC;
  Main.StdControl -> PageEEPROMC;
  Main.StdControl -> CleanEEPROMM.StdControl;

  CleanEEPROMM.Leds -> LedsC;
  CleanEEPROMM.Timer -> TimerC.Timer[unique("Timer")];
  CleanEEPROMM.PageEEPROM -> PageEEPROMC.PageEEPROM[0];

  }
