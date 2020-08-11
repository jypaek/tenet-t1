// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 

includes adcm1700Const;

configuration activeEye {
  provides {
    interface StdControl as control;
    interface imager;
  }
}
implementation {
  components 
      adcm1700ControlM,
      adcm1700CommC,
      adcm1700ctrlExposureM,
      adcm1700ctrlFormatM,
      adcm1700ctrlPatchM,
      //      adcm1700ctrlSnapM,
      adcm1700ctrlRunM,
      //      adcm1700ctrlVideoM,
      adcm1700ctrlWindowSizeM,
      adcm1700ctrlStatM, 
      adcm1700ctrlPatternM,
      cpldC,
      TimerC,
      LedsC;

  //what it provides
  control = adcm1700ControlM;
  imager = adcm1700ControlM;

  // cpld interface
  adcm1700ControlM.cpldControl -> cpldC.cpldControl;
  adcm1700ControlM.cpld -> cpldC.cpld[unique("cpld")];

  //initialization of all the feature components
  adcm1700ControlM.StdControlExposure->adcm1700ctrlExposureM.StdControlExposure;
  adcm1700ControlM.StdControlFormat->adcm1700ctrlFormatM.StdControlFormat;
  adcm1700ControlM.StdControlPatch->adcm1700ctrlPatchM.StdControlPatch;
    //adcm1700ControlM.StdControlSnap->adcm1700ctrlSnapM.StdControlSnap;
  adcm1700ControlM.StdControlRun->adcm1700ctrlRunM.StdControlRun;
    //adcm1700ControlM.StdControlVideo->adcm1700ctrlVideoM.StdControlVideo;
  adcm1700ControlM.StdControlWindowSize->adcm1700ctrlWindowSizeM.StdControlWindowSize;
  adcm1700ControlM.StdControlPattern->adcm1700ctrlPatternM.StdControlPattern;
  adcm1700ControlM.StdControlStat->adcm1700ctrlStatM.StdControlStat;
    //adcm1700ControlM.StdControlRun->adcm1700ctrlRunM.StdControlRun;

  //all the feature components
  adcm1700ControlM.exposure->adcm1700ctrlExposureM.exposure;
  adcm1700ControlM.format->adcm1700ctrlFormatM.format;
  adcm1700ControlM.patch->adcm1700ctrlPatchM.patch;
    //adcm1700ControlM.snap->adcm1700ctrlSnapM.snap;
  adcm1700ControlM.run->adcm1700ctrlRunM.run;
    //adcm1700ControlM.video->adcm1700ctrlVideoM.video;
  adcm1700ControlM.windowSize->adcm1700ctrlWindowSizeM.windowSize;
  adcm1700ControlM.pattern->adcm1700ctrlPatternM.pattern;
  adcm1700ControlM.stat->adcm1700ctrlStatM.stat;
    //adcm1700ControlM.run->adcm1700ctrlRunM.run;


  //in case it wants to write something directly
  adcm1700ControlM.imagerCommStdControl -> adcm1700CommC.imagerCommControl;
  adcm1700ControlM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_CONTROL_ADDRESS];

  //the rest of the connections
  adcm1700ctrlExposureM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_EXPOSURE_ADDRESS];
  adcm1700ctrlFormatM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_FORMAT_ADDRESS];
  adcm1700ctrlPatchM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_PATCH_ADDRESS];
    //adcm1700ctrlSnapM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_SNAP_ADDRESS];
  adcm1700ctrlRunM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_RUN_ADDRESS];
    //adcm1700ctrlVideoM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_VIDEO_ADDRESS];
  adcm1700ctrlWindowSizeM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_WINDOWSIZE_ADDRESS];
  adcm1700ctrlPatternM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_PATTERN_ADDRESS];
  adcm1700ctrlStatM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_STATISITICS_ADDRESS];
    //adcm1700ctrlStatM.imagerComm -> adcm1700CommC.imagerComm[ADCM1700_RUN_ADDRESS];
  adcm1700ctrlPatchM.Timer -> TimerC.Timer[unique("Timer")];
    adcm1700ctrlRunM.Timer -> TimerC.Timer[unique("Timer")];  // for polling loop

  // for start-up delay
  adcm1700ControlM.Timer -> TimerC.Timer[unique("Timer")];
  
  //for test
  adcm1700ControlM.Leds -> LedsC;
  adcm1700ctrlFormatM.Leds -> LedsC;
  adcm1700ctrlExposureM.Leds -> LedsC;
  adcm1700ctrlRunM.Leds -> LedsC;
  adcm1700ctrlWindowSizeM.Leds -> LedsC;
 }
