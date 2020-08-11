// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 

// This interface provides six functions:
//  start   - start the interface 
//  init    - set initial parameters, power camera module and load default values
//  setCaptureParameters - specify new capture parameters (e.g. exposure period)
//  snapImage  - capture an image to SRAM memory (test images are specified by capture parameters)
//  getImagerStats - 
//  stop    - stop the interface, remove clock and power from module.
// Unless an init, or snapImage operation is being performed, the camera 
// module is placed in standby mode (to reduce power consumption). This is accomplished
// by writing 0x00 to the CONTROL register. Further power reduction may be accomplished 
// by stopping the camera clock (MCLK). In early versions of Cyclops, the CPLD state 
// controlled the camera clock. I recent versions, the camera clock is controlled directly
// by the microcontroller.

 

    /* Cyclops1 - original large board (only RLB and MHR have them)
     * Cyclops2 - compact board with RS-232 driver (samples: only 20 exist)
     *    2A : CPLD state controls MCLK
     *    2B : HS3 controls MCLK
     */ 


includes image;
//includes imagerConst;
includes adcm1700Const;
includes memConst;
includes cpldConst;

module adcm1700ControlM
{
    provides {
        interface StdControl as control;
        interface imager;
    }
    uses {
        // This module facilitate setting registers in the imager address space to control its behaviour
        interface StdControl as imagerCommStdControl;
        interface imagerComm;

        // CPLD Communication (for capture)
        interface StdControl as cpldControl;
        interface cpld;

        //undelying components
        interface StdControl as StdControlExposure;
        interface ctrlExposure as exposure;
        interface StdControl as StdControlFormat;
        interface ctrlFormat as format;
        interface StdControl as StdControlPatch;
        interface ctrlPatch as patch;
        interface StdControl as StdControlRun;
        interface ctrlRun as run;
        interface StdControl as StdControlWindowSize;
        interface ctrlWindowSize as windowSize;
        interface StdControl as StdControlPattern;
        interface ctrlPattern as pattern;
        interface StdControl as StdControlStat;
        interface ctrlStat as stat;
        
        // Start-up delay
        interface Timer;

        // Diagnostic
        interface Leds;
    }
}
implementation
{
    // state of this interface (which command was called, and how far as it progressed)
    uint8_t state;                    
    enum
        {
            //ON OFF ProcedureADDRESS
            CAMERA_NOT_POWERED=0x11,
            CAMERA_POWERED=0x23,
            CAMERA_CLOCKED=0x31,
            CAMERA_PATCHED=0x47,
            CAMERA_READY=SUCCESS,
            CAMERA_BUSY=0x58,
        };

    cpldCommand_t  myCPLDcode;

    uint8_t currentCommand;
    enum
        {                    

            CINIT,   // initialization
            CSET,    // setCaptureParameters
            CSNAP,   // snapImage
            CSTAT,   // getImageStats
            CRUN     // run the module (for autofunction convergence)
        };

   
    uint8_t sPage;     //start page for capture / test operations
    uint8_t nFrames;   // number of sequential frames to capture

    // current image and capture parameters
    CYCLOPS_ImagePtr pImg;                  // pointer to image structure
    CYCLOPS_Image    image;                 // default image, used for init
    CYCLOPS_Capture_Parameters capture;     // capture info

    uint16_t runTime; // run time (milliseconds) for run command


    //*******************camera Voltage Regulator Functionality***************
    // PORTD:2 is used for debugging (monitor camera Vcc)
#define MAKE_CAMERA_POWER_PIN_OUTPUT() sbi(DDRB, 5); sbi(DDRD, 2)
#define TURN_CAMERA_POWER_ON()         cbi(PORTB, 5); sbi(PORTD,2)  //by making the pin low we turn on the P-Channel Mosfet
#define TURN_CAMERA_POWER_OFF()        sbi(PORTB, 5); cbi(PORTD, 2)  //by making the pin high we turn off the P-Channel Mosfet

    //****************** Camera Module clock control *************************
    // Cyclops2 with new CPLD firmware (direct uP control of MCLK through HS3)
#define MAKE_CAMERA_CLOCK_PIN_OUTPUT() sbi(DDRE, 4)
//#define GET_MCLK_STATE()  ((inp(PINE) & 0x10) >> 4)
#define TURN_CAMERA_CLOCK_ON() sbi(PORTE, 4)                   
#define TURN_CAMERA_CLOCK_OFF() cbi(PORTE, 4)

  // ******************* CPLD control function **********************************

    // This component shouldn't mess with the CPLD clock. It is assumed that another
    // component will have activated it.
    // (CYCLOPS2 feature)
    //#define MAKE_CPLD_CLOCK_PIN_OUTPUT() sbi(DDRB, 6)
    //#define TURN_CPLD_CLOCK_ON()  sbi(PORTB, 6)  // enable CPLD clock oscillator
    //#define TURN_CPLD_CLOCK_OFF() cbi(PORTB, 6)  // disable CPLD clock oscillator

    // last argument used to be stopPage
    void set_CPLD_run_mode(uint8_t opcode,uint8_t startPage,uint8_t count)
        {
	  // A cleaner way to do this would be to change the definition of the
	  // CPLDcommand structure. However it might have other consequences. 
	    myCPLDcode.opcode= ((count & 0x0f) << 4) | (opcode & 0x0f); 
            myCPLDcode.sramBank         = 0x00;      // 4 bit   0x00-0x0f
            myCPLDcode.flashBank        = 0x00;      // 4 bit   0x00-0x0f
            myCPLDcode.startPageAddress = startPage; // 1 byte  0x00-0xff
            myCPLDcode.endPageAddress   = 0xFF;      // 1 byte  (ignored)
            call cpld.setCpldMode(&myCPLDcode);
        }
    
         
    //***************initiation and termination*******************//
    command result_t control.init() 
        {                   
            // turn off Timer1 compare outputs
            cbi(TCCR1A,7); cbi(TCCR1A,6); cbi(TCCR1A, 5); cbi(TCCR1A, 4);  // *** DEBUG ***

            TURN_CAMERA_POWER_OFF();            // the camera should already be off
            MAKE_CAMERA_POWER_PIN_OUTPUT();

            TURN_CAMERA_CLOCK_OFF();            // the clock should already be off
            MAKE_CAMERA_CLOCK_PIN_OUTPUT();
            
            state=CAMERA_NOT_POWERED;
                        
            call cpldControl.init();
            call imagerCommStdControl.init();
            call StdControlExposure.init();
            call StdControlFormat.init();
            call StdControlPatch.init();
            call StdControlPattern.init();
            call StdControlRun.init();
            call StdControlWindowSize.init();

            // default image parameters  (used during init)
            image.type          = CYCLOPS_IMAGE_TYPE_Y;
            image.size.x        = 0x40;     // 64x64 pixels        
            image.size.y        = 0x40;
            image.nFrames       = 0x01;
            pImg = &image;                  // initialize pointer 

            // default capture parameters
            capture.offset.x           = 0;
            capture.offset.y           = 0;
            capture.inputSize.x        = 0x120;
            capture.inputSize.y        = 0x120;
            capture.testMode           = CYCLOPS_TEST_MODE_NONE; // *** DEBUG ***
            capture.exposurePeriod     = 0x0000; // AE
            capture.analogGain.red     = 0x00;   
            capture.analogGain.green   = 0x00;
            capture.analogGain.blue    = 0x00;
            capture.digitalGain.red    = 0x0000;  // AWB
            capture.digitalGain.green  = 0x0000;  
            capture.digitalGain.blue   = 0x0000;  
            capture.runTime            = 0; 

            return SUCCESS;
        }

    command result_t control.start() 
        {
            currentCommand = CINIT;
            state=CAMERA_NOT_POWERED;
            call cpldControl.start();
            call imagerCommStdControl.start();
            call StdControlExposure.start();
            call StdControlFormat.start();
            call StdControlPatch.start();
            call StdControlPattern.start();
            call StdControlRun.start();
            call StdControlWindowSize.start();

            TURN_CAMERA_POWER_OFF();
            TURN_CAMERA_CLOCK_OFF();

            call Timer.start(TIMER_ONE_SHOT, 2000);    // make sure camera Vcc goes off !!!

            return SUCCESS;
        }



    command result_t control.stop() 
        {
            TURN_CAMERA_CLOCK_OFF();     // it should ALREADY be off!
            TURN_CAMERA_POWER_OFF();
            state=CAMERA_NOT_POWERED;
            // Do not call cpldControl.stop(): the interface may be used elsewhere
            call imagerCommStdControl.stop(); 
            call StdControlExposure.stop();
            call StdControlFormat.stop();                   
            call StdControlPatch.stop();
            call StdControlRun.stop();
            call StdControlWindowSize.stop();
            return SUCCESS;
        }
    //********************The main control interface that adcm1700Control provides******************************************//
   
    // capture an image and store it in SRAM             
    command result_t imager.snapImage(CYCLOPS_ImagePtr myImg)
        {
            // in case the init routine failed or the camera is busy
            if (state != CAMERA_READY)
              {
                signal imager.snapImageDone(myImg, FAIL);
                return FAIL;
              }

            currentCommand = CSNAP;

            // Set camera busy
            state = CAMERA_BUSY;

            pImg    = myImg;   // save image pointer
            sPage   = 17; // Always start at the first sector for now
            nFrames = (pImg->nFrames & 0x0F); // limit capture to 15 frames
        
            //TURN_CAMERA_CLOCK_ON();     // activate MCLK

            call format.setFormat(pImg->type);   // jump into the rabbit hole!

            return SUCCESS;
        } 

    // set new capture parameters
    // (These values are not communicated to the module until the next capture is performed)
    command result_t imager.setCaptureParameters(CYCLOPS_CapturePtr myCap)
    {
        currentCommand = CSET;

        // update all capture parameters
        // (value checking is performed inside the individual components)
        capture.offset.x           = myCap->offset.x;
        capture.offset.y           = myCap->offset.y;
        capture.inputSize.x        = myCap->inputSize.x;
        capture.inputSize.y        = myCap->inputSize.y;
        capture.testMode           = myCap->testMode;
        capture.exposurePeriod     = myCap->exposurePeriod;
        capture.analogGain.red     = myCap->analogGain.red;     // zero for auto exposure mode
        capture.analogGain.green   = myCap->analogGain.green;  
        capture.analogGain.blue    = myCap->analogGain.blue;   
        capture.digitalGain.red    = myCap->digitalGain.red;    // zero for AWB mode    
        capture.digitalGain.green  = myCap->digitalGain.green;    
        capture.digitalGain.blue   = myCap->digitalGain.blue;    
        capture.runTime            = myCap->runTime;

        signal imager.setCaptureParametersDone(SUCCESS);
        return SUCCESS; 
    }

    // Get the average pixel values
    command result_t imager.getPixelAverages()
    {
        currentCommand = CSTAT;

        call stat.getSums();
        return SUCCESS; 
    }

    // run the imager for the specified period
    command result_t imager.run(uint16_t rTime)
    {
      // Make sure camera is not busy
      if (state != CAMERA_READY) {
        signal imager.runDone(FAIL);
        return FAIL;
      }
      
      // Lock camera while busy
      state = CAMERA_BUSY;
      
      currentCommand = CRUN;
      
      runTime = rTime;
      
      if (runTime >= 10)
        {
          TURN_CAMERA_CLOCK_ON();     // activate MCLK
          call run.camera(CYCLOPS_RUN);
        }
      else
        signal imager.runDone(SUCCESS);  // event may missed if runtime is short
      
      return SUCCESS;
    }
  
    //************************* timer  callback ************************************//
    // ensures power-up delays before clock is applied, and before I2C communication begins
    event result_t Timer.fired()   
    {
        switch(currentCommand)
            {
            case CINIT:
                switch (state)
                    {
                    case CAMERA_NOT_POWERED:
                      state=CAMERA_POWERED;
                      TURN_CAMERA_POWER_ON();
                      call Timer.start(TIMER_ONE_SHOT, 100);   // DC power should be provided for > 20 mS before MCLK is activated
                      break;
                    case CAMERA_POWERED:      // MCLK should be provided > 200 mS before the first I2C transaction
                      state = CAMERA_CLOCKED;
                      TURN_CAMERA_CLOCK_ON();
                      call Timer.start(TIMER_ONE_SHOT, 400);  // Clock should run for 200 mS before I2C communication
                      break;
                    case CAMERA_CLOCKED:     // end of MCLK on delay
                      call patch.setPatch();
                      break;
                    default:
                      break;
                    } 
                break;
            case CSNAP:   // perform capture
                set_CPLD_run_mode(CPLD_OPCODE_CAPTURE_IMAGE,sPage,nFrames);
                break;
            case CRUN:
                call run.camera(CYCLOPS_STOP);
                break;
            default:
                break;
            }

        return SUCCESS;
    }


    //*************************cpld callback ************************************//
    event result_t cpld.setCpldModeDone(cpldCommand_t *cpldC)
        {
	  switch (cpldC->opcode & 0x0f)  // RLB 7/21/05 masked out repeat field
                {
                case CPLD_OPCODE_CAPTURE_IMAGE:            // capture is complete, restore memory access
                    call run.camera(CYCLOPS_STOP);
                    break;
                default:     // shouldn't ever get here
                    break;
                }         
 
            return SUCCESS; 
        }
    
    //*************************control modules callback ***********************************//        
    // Patch
    event result_t patch.setPatchDone(result_t status)
        {
            if (status != SUCCESS)
                {
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                }

            state=CAMERA_PATCHED;

            call format.setFormat(pImg->type);

            return SUCCESS;
        }

    // Format
    event result_t format.setFormatDone(result_t status)
    {
      if (status != SUCCESS) {
              // Camera no longer busy
              state = CAMERA_READY;
                switch (currentCommand)
                {
                case CINIT:
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                    break;
                case CSNAP:
                    signal imager.snapImageDone(pImg, FAIL);
                    return FAIL;
                    break;
                default:
                    break;
                }
      }

      call pattern.setPattern(capture.testMode);
      
      return SUCCESS;
    }

    // Pattern
    event result_t pattern.setPatternDone(result_t status)
        {            
          if (status != SUCCESS) {
              // Camera no longer busy
              state = CAMERA_READY;
                switch (currentCommand)
                {
                case CINIT:
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                    break;
                case CSNAP:
                    signal imager.snapImageDone(pImg, FAIL);
                    return FAIL;
                    break;
                default:
                    break;
                }
          }

            call exposure.setExposureTime(capture.exposurePeriod);
            return SUCCESS;          
        }
   
    // exposure
    event result_t exposure.setExposureTimeDone(result_t status)
        {
          if (status != SUCCESS) {
              // Camera no longer busy
              state = CAMERA_READY;
                switch (currentCommand)
                {
                case CINIT:
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                    break;
                case CSNAP:
                    signal imager.snapImageDone(pImg, FAIL);
                    return FAIL;
                    break;
                default:
                    break;
                }
          }

            call exposure.setAnalogGain(capture.analogGain); 
            return SUCCESS;
        }

    // set analog gain
    event result_t exposure.setAnalogGainDone(result_t status)
        {
          if (status != SUCCESS) {
              // Camera no longer busy
              state = CAMERA_READY;
                switch (currentCommand)
                {
                case CINIT:
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                    break;
                case CSNAP:
                    signal imager.snapImageDone(pImg, FAIL);
                    return FAIL;
                    break;
                default:
                    break;
                }
          }

            call exposure.setDigitalGain(capture.digitalGain); 
            return SUCCESS;
        }

    // set digital gain
    event result_t exposure.setDigitalGainDone(result_t status)
        {
          if (status != SUCCESS) {
              // Camera no longer busy
              state = CAMERA_READY;
                switch (currentCommand)
                {
                case CINIT:
                    signal imager.imagerReady(FAIL);
                    return FAIL;
                    break;
                case CSNAP:
                    signal imager.snapImageDone(pImg, FAIL);
                    return FAIL;
                    break;
                default:
                    break;
                }
          }

          call windowSize.setInputSize(capture.inputSize);

          return SUCCESS;
        }

    // input window size
    event result_t windowSize.setInputSizeDone(result_t status)
    {
      if (status != SUCCESS) {
         // Camera no longer busy
         state = CAMERA_READY;
            switch (currentCommand)
            {
            case CINIT:
                signal imager.imagerReady(FAIL);
                return FAIL;
                break;
            case CSNAP:
                signal imager.snapImageDone(pImg, FAIL);
                return FAIL;
                break;
            default:
                break;
            }
      }

        call windowSize.setOutputSize(pImg->size); 
        return SUCCESS;    
    }    

    // output window size
    event result_t windowSize.setOutputSizeDone(result_t status)
    {
      if (status != SUCCESS) {
          // Camera no longer busy
          state = CAMERA_READY;
            switch (currentCommand)
            {
            case CINIT:
                signal imager.imagerReady(FAIL);
                return FAIL;
                break;
            case CSNAP:
                signal imager.snapImageDone(pImg, FAIL);
                return FAIL;
                break;
            default:
                break;
            }
      }

        
        switch (currentCommand)
            {
            case CINIT:
              call run.camera(CYCLOPS_STOP);     // enter low-power standby mode
              break;
            case CSNAP:
              // Camera no longer busy
              state = CAMERA_READY;
              call run.camera(CYCLOPS_RUN);      // start module running for capture
              break;
            default:
                break;
            }

        return SUCCESS;
    }

    // window pan position
    event result_t windowSize.setInputPanDone(result_t status)
    {        
        if (status != SUCCESS)
            {
                signal imager.snapImageDone(pImg, FAIL);
                return FAIL;
            }

        call run.sensor(CYCLOPS_RUN);
        return SUCCESS;
    }

    //Run module
    event result_t run.cameraDone(uint8_t run_stop, result_t status)
    {
      if (status != SUCCESS) {
          // Camera no longer busy
          state = CAMERA_READY;
            switch(currentCommand)
            {
            case CINIT:
                signal imager.imagerReady(FAIL);
                return FAIL;
                break;
            case CSNAP:
              signal imager.snapImageDone(pImg, FAIL);
                return FAIL;
                break;
            case CRUN:
                signal imager.runDone(FAIL);
                return FAIL;
            default:
                break;
            }
      }

        switch (currentCommand)
            {
            case CINIT:
                //TURN_CAMERA_CLOCK_OFF();        // end of init operation
                state = CAMERA_READY;
                signal imager.imagerReady(SUCCESS);
                break;
            case CSNAP:
                if (run_stop == CYCLOPS_RUN)    // beginning of pan operation
                    call run.sensor(CYCLOPS_STOP);
                else // end of capture operation: CPLD is already in SRAM access mode
                  signal imager.snapImageDone(pImg, SUCCESS);  // DONE with capture
                      // Camera no longer busy
                state = CAMERA_READY;
                break;
            case CRUN:
                if (run_stop == CYCLOPS_RUN)
                    call Timer.start(TIMER_ONE_SHOT, runTime);
                else
                    {
                        // if we learn how to stop the clock, we will do something else here
                        signal imager.runDone(SUCCESS);
                        // camera no longer busy
                        state = CAMERA_READY;
                    }
                break;
            default:
                break;
            }

        return SUCCESS;
    }

    // run sensor
    event result_t run.sensorDone(uint8_t run_stop, result_t status)
    {
        if (status != SUCCESS)
            {
              state = CAMERA_READY;
                signal imager.snapImageDone(pImg, FAIL);
                return FAIL;
            }

        if (run_stop == CYCLOPS_STOP)
	    call windowSize.setInputPan(capture.offset);        // perform input pan
        else
            {
                if (capture.runTime >= 10)   // if the run time is too short, the event can be missed
                    call Timer.start(TIMER_ONE_SHOT, capture.runTime);  // let auto-functions converge before capture
                else
                    set_CPLD_run_mode(CPLD_OPCODE_CAPTURE_IMAGE,sPage,nFrames);
            }

        return SUCCESS;
    }


    // ***************** pixel average callbacks ***************************************

    //statistics
    event result_t stat.getSumsDone(color16_t values, result_t status)
    {
        color16_t averages;
        uint16_t scaleFactor; 

        if (status != SUCCESS)
            {
                averages.red = 0;
                averages.green = 0;
                averages.blue = 0;
                
                signal imager.getPixelAveragesDone(averages, FAIL);
            }
        else
            {
                // The scale factor is 4*16384/Nx/Ny.
                // window size         scale factor
                //  280 * 280          0.86
                //  128 * 128          4
                //   64 *  64          16
                //   32 *  32          64
                // [note: minimum window size is 24 * 24]
                // scale factor * 128 (to avoid round-off errors)
                scaleFactor = 0x8000 / pImg->size.x;
                scaleFactor = (256 * scaleFactor) / pImg->size.y;  
                averages.red   = values.red   * scaleFactor >> 7;
                averages.green = values.green * scaleFactor >> 7;
                averages.blue  = values.blue  * scaleFactor >> 7;
 
                signal imager.getPixelAveragesDone(averages, SUCCESS);
            }
        return SUCCESS;
    }
    
    //*************************Communication callback ************************************//
    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            return SUCCESS;
        }
    
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            return SUCCESS;
        }
    
    event result_t imagerComm.writeBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status)
        {
            return SUCCESS;
        }
    
    event result_t imagerComm.readBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status) 
        {              
            return SUCCESS;
        }

    //************************ default callback from small components *****************************//
    
    default event result_t imager.imagerReady(result_t status) { return SUCCESS; }

    default event void imager.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) { }

    default event result_t imager.setCaptureParametersDone(result_t status) { return SUCCESS; }

    default event result_t imager.getPixelAveragesDone(color16_t stat_Vals, result_t status) { return SUCCESS; }

    default event result_t imager.runDone(result_t status) { return SUCCESS; }

}

