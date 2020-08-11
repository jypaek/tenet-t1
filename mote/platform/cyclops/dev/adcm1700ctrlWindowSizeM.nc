// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

//   This component sizes the window. It uses the built-in "sizer" function of the camera module
// image processing pipeline. The sizer is invoked whenever the output window size is programmed.
//   In RAW mode the input window size will equal the output window size, because the sizer is
// bypassed. No attempt is made to detect that condition inside this component.
// The imager operates in "video" mode during capture. The "still" mode registers are not
// used.
//   The input window coordinates will be overwritten by the sizer input values (with zero offset)
// when the module is placed in run mode. This can be avoided by stopping the sensor, but not 
// thi i-pipe (as done in adcm1700ControlM.nc). 

includes adcm1700Const;
includes memConst;

// diagnostics
/*
#define MAKE_TELEGRAPH_CLOCK_PIN_OUTPUT()         sbi(DDRB, 2)  // scope TP1
#define TURN_TELEGRAPH_CLOCK_ON()                 sbi(PORTB, 2)
#define TURN_TELEGRAPH_CLOCK_OFF()                cbi(PORTB, 2)
#define MAKE_TELEGRAPH_DATA_PIN_OUTPUT()          sbi(DDRB, 4)  // scope TP2
#define TURN_TELEGRAPH_DATA_ON()                  sbi(PORTB, 4)
#define TURN_TELEGRAPH_DATA_OFF()                 cbi(PORTB, 4)
*/

module adcm1700ctrlWindowSizeM
{
    provides {
        interface StdControl as StdControlWindowSize;
        interface ctrlWindowSize as windowSize;
    }
    uses {
        interface imagerComm; 

	// Diagnostic
	interface Leds;
    }
}
implementation
{

    /* internal structure for the window sizes */
    wsize_t currentInputSize;
    wsize_t currentOutputSize;
    wpos_t  currentInputOffset;
    int16_t position;   // working variable for window position calculations

    uint8_t currentCommand;

    enum     // for current command
        {
            IN_SIZE,
            OUT_SIZE,
            IN_PAN
        };


  // ************************ DIAGNOSTIC **********************
  /*
  void telegraph16(uint16_t data)
  {
    int i; 
    uint16_t mask;

    TURN_TELEGRAPH_CLOCK_OFF();
    TURN_TELEGRAPH_DATA_OFF();
    mask = 0x8000;

    for (i = 0; i <= 15; i++)
      {
	if (mask & data)
	  TURN_TELEGRAPH_DATA_ON();
	else
	  TURN_TELEGRAPH_DATA_OFF();
	TOSH_uwait(50);
	TURN_TELEGRAPH_CLOCK_ON();
	TOSH_uwait(50);
	TURN_TELEGRAPH_CLOCK_OFF();
	TOSH_uwait(50);
	mask = mask >>1;
      }

   TURN_TELEGRAPH_DATA_OFF();
  }
  */
    //*******************Inititialization and Termination*********************/
    command result_t StdControlWindowSize.init()
        {
            // illegal values force initialization
            currentInputSize.x    = 0;  
            currentInputSize.y    = 0;
            currentOutputSize.x   = 0;  
            currentOutputSize.y   = 0;
            currentInputOffset.x  = 0;
            currentInputOffset.y  = 0;
            return SUCCESS;
        }
    
    command result_t StdControlWindowSize.start()
        {
	  /*
	    MAKE_TELEGRAPH_CLOCK_PIN_OUTPUT();
	    MAKE_TELEGRAPH_DATA_PIN_OUTPUT();
	  */
            return SUCCESS;
        }
    
    command result_t StdControlWindowSize.stop()
        {
            return SUCCESS;
        }

    // interface commands

    command result_t windowSize.setInputSize(wsize_t iwsize)
        {
            currentCommand = IN_SIZE;

            // enforce 4-byte alignment requirement
            iwsize.x = (iwsize.x >> 2) << 2;
            iwsize.y = (iwsize.y >> 2) << 2;

            // check limits 
            if (iwsize.x > ADCM_SIZE_MAX_X)
                iwsize.x = ADCM_SIZE_MAX_X;

            if (iwsize.x < ADCM_SIZE_MIN_X)
                iwsize.x = ADCM_SIZE_MIN_X;
            
            if (iwsize.y > ADCM_SIZE_MAX_Y)
                iwsize.y = ADCM_SIZE_MAX_Y;

            if (iwsize.y < ADCM_SIZE_MIN_Y)
                iwsize.y = ADCM_SIZE_MIN_Y;
            
            if ((iwsize.x != currentInputSize.x) || (iwsize.y != currentInputSize.y))
                {
                    currentInputSize.x = iwsize.x;
                    currentInputSize.y = iwsize.y;

                    // set input size register ...
                    call imagerComm.writeRegister (ADCM_REG_SZR_IN_WID_V, currentInputSize.x);
                }
            else          // no need to do anything
                signal windowSize.setInputSizeDone(SUCCESS);

            return SUCCESS;
        }

    command result_t windowSize.setOutputSize(wsize_t owsize)
        {
            currentCommand = OUT_SIZE;

            // enforce 4-byte alignment requirement
            owsize.x = (owsize.x >> 2) << 2;
            owsize.y = (owsize.y >> 2) << 2;

            // check limits 
            if (owsize.x > ADCM_SIZE_MAX_X)
                owsize.x = ADCM_SIZE_MAX_X;

            if (owsize.x < ADCM_SIZE_MIN_X)
                owsize.x = ADCM_SIZE_MIN_X;
            
            if (owsize.y > ADCM_SIZE_MAX_Y)
                owsize.y = ADCM_SIZE_MAX_Y;

            if (owsize.y < ADCM_SIZE_MIN_Y)
                owsize.y = ADCM_SIZE_MIN_Y;

            // *** DEBUG ***: for output size to be updated
            if ((owsize.x != currentOutputSize.x) || (owsize.y != currentOutputSize.y))
            {
                currentOutputSize.x = owsize.x;
                currentOutputSize.y = owsize.y;

                // set output size register ...
                call imagerComm.writeRegister (ADCM_REG_SZR_OUT_WID_V, currentOutputSize.x);
            }
            else          // no need to do anything
                signal windowSize.setOutputSizeDone(SUCCESS);

            return SUCCESS;
        }

    command result_t windowSize.setInputPan(wpos_t iwpan)
        {
            uint8_t dxMax;    // maximum permissable offset
            uint8_t dyMax;

            currentCommand = IN_PAN;

            // enforce 4-byte alignment requirement
            iwpan.x = (iwpan.x >> 2) << 2;
            iwpan.y = (iwpan.y >> 2) << 2;

            // check limits
            dxMax = (ADCM_SIZE_MAX_X - currentInputSize.x) >> 1;
            dyMax = (ADCM_SIZE_MAX_Y - currentInputSize.y) >> 1;

            if (iwpan.x < 0)  // x-offset check
                {
                    if (iwpan.x < -dxMax)
                        iwpan.x = -dxMax;
                }
            else
                {
                    if (iwpan.x > dxMax)
                        iwpan.x = dxMax;
                }

            if (iwpan.y < 0)  // y-offset check
                {
                    if (iwpan.y < -dyMax)
                        iwpan.y = -dyMax;
                }
            else
                {
                    if (iwpan.y > dyMax)
                        iwpan.y = dyMax;
                }

            // The offset position is lost when the module is stopped, so it must always
            // be reloaded.
            if ((iwpan.x != 0) || (iwpan.y != 0))
                {
                    currentInputOffset.x = iwpan.x;
                    currentInputOffset.y = iwpan.y;

                    // set input position register ...
		    //call Leds.redToggle();   // debug
                    position = (((ADCM_SIZE_MAX_X - currentInputSize.x) >> 1) + currentInputOffset.x + 4) >> 2 ;
		    //telegraph16(position);
		    call imagerComm.writeRegister (ADCM_REG_FWCOL, (uint8_t) position);
		     
                }
            else          // no need to do anything
                signal windowSize.setInputPanDone(SUCCESS);

            return SUCCESS;
        }

    // default callbacks

    default event result_t windowSize.setInputSizeDone(result_t status)
        {
            return SUCCESS;
        }

    default event result_t windowSize.setOutputSizeDone(result_t status)
        {
            return SUCCESS;
        }

    default event result_t windowSize.setInputPanDone(result_t status)
        {
            return SUCCESS;
        }

    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status == FAIL)
                {
                    switch (currentCommand)
                        {
                        case IN_SIZE:
                            signal windowSize.setInputSizeDone(FAIL);
                            break;
                        case OUT_SIZE:
                            signal windowSize.setOutputSizeDone(FAIL);
                            break;
                        case IN_PAN:
                            signal windowSize.setInputPanDone(FAIL);
                            break;
                        }

                    return FAIL;
                }

            switch (addr) 
                {
                case ADCM_REG_PROC_CTRL_V:  // make sure sizer bit is zero
                    call imagerComm.writeRegister (ADCM_REG_PROC_CTRL_V, (data & ~ADCM_PROC_CTRL_NOSIZER));
                    break;
                default:
                    // ??? some other register ???
                    break;
                }

            return SUCCESS;
        }
    
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            //if (status != SUCCESS) signal windowSize.setWindowSizeDone(FAIL);
            switch (addr) 
                {
                    
                    // sizer input window size
                case ADCM_REG_SZR_IN_WID_V:
                    call imagerComm.writeRegister (ADCM_REG_SZR_IN_HGT_V, currentInputSize.y); 
                    break;
                case ADCM_REG_SZR_IN_HGT_V:
                    signal windowSize.setInputSizeDone(status);
                    break;

                    // sizer output window size
                case ADCM_REG_SZR_OUT_WID_V:
                    call imagerComm.writeRegister (ADCM_REG_SZR_OUT_HGT_V, currentOutputSize.y); 
                    break;
                case ADCM_REG_SZR_OUT_HGT_V:
                    call imagerComm.readRegister (ADCM_REG_PROC_CTRL_V);   // activate sizer
                    break;
                case ADCM_REG_PROC_CTRL_V:
                    signal windowSize.setOutputSizeDone(status);
                    break;
                    
                    // input window coordinates (for panning)
                case ADCM_REG_FWCOL:
		    position = ( ((ADCM_SIZE_MAX_X + currentInputSize.x) >> 1) + currentInputOffset.x + 8) >> 2;  
		    //telegraph16(position);
	            call imagerComm.writeRegister (ADCM_REG_LWCOL, (uint8_t) position);
                    break;
                case ADCM_REG_LWCOL:
                    position = ( ((ADCM_SIZE_MAX_Y - currentInputSize.y) >> 1) + currentInputOffset.y + 4) >> 2;  
		    //telegraph16(position);
		    call imagerComm.writeRegister (ADCM_REG_FWROW, (uint8_t) position); 
                    break;
                case ADCM_REG_FWROW:
		    position = ( ((ADCM_SIZE_MAX_Y + currentInputSize.y) >> 1) + currentInputOffset.y + 8) >> 2;
		    //telegraph16(position);
		    call imagerComm.writeRegister (ADCM_REG_LWROW, (uint8_t) position);  
                    break;
                case ADCM_REG_LWROW:
		    signal windowSize.setInputPanDone(SUCCESS);
                    break;


                default:   // some other register ???
                    break;             
                }
            return SUCCESS;
        }

    //***********************Writing and Reading Blocks*********************/
    event result_t imagerComm.writeBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status)
        {
            return SUCCESS;
        }
    
    event result_t imagerComm.readBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status) 
        {
            return SUCCESS;
        }
    
}


