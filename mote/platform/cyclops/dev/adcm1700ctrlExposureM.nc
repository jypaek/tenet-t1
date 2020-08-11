// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 


includes adcm1700Const;
includes memConst;

#define MCLK 4.0e6         // sensor clock frequency

module adcm1700ctrlExposureM
{
    provides {
        interface StdControl as StdControlExposure ;
        interface ctrlExposure as exposure;
    }
    uses {
        interface imagerComm;
        interface Leds;   // for debugging
    }
}
implementation
{
    //********* current state variables *******
    float    currentExposureTime;    // Time in seconds [floating point variable]
    color8_t currentAnalogGain;      // ADCM PGA gains are 8 bits: (1 + b[6]) * (1 + 0.15 * b[5:0]/(1 + 2 * b[7]))
    color16_t currentDigitalGain;    // ADCM digital gains are 10 bits (binary 3.7 format, or gain * 128)

    // This data is used in manual exposure calculations
    uint8_t cpp;                 // sensor clocks per pixel
    uint8_t hblank;              // horizontal blanking interval (in column processing periods)
    uint8_t vblank;              // vertical blanking interval (in row processing periods)
    uint16_t rows;               // number of image rows
    uint16_t cols;               // number of columns
    uint16_t rowexp;             // exposure period (in row processing periods)
    uint8_t subrow;              // subrow exposure
    uint8_t subMAX;              // subrow exposure limit

    uint8_t currentCommand;
    enum
        {
            EXTIME,
            EAGAIN,
            EDGAIN
        };


    //*******************Inititialization and Termination*********************/
    command result_t StdControlExposure.init() 
        {
            // establish default values
            currentExposureTime       = 0.0;    
            currentAnalogGain.red     = 0;    // auto exposure
            currentAnalogGain.green   = 0;
            currentAnalogGain.blue    = 0;
            currentDigitalGain.red    = 0;    // auto white balance
            currentDigitalGain.green  = 0; 
            currentDigitalGain.blue   = 0; 

	    rowexp = 0x0070;  // default exposure values
            subrow = 0x00;

            return SUCCESS;
        }
    
    command result_t StdControlExposure.start() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlExposure.stop() 
        {
            return SUCCESS;
        }

    //***********************Exposure Control*********************/
    command result_t exposure.setExposureTime(float exposureTime)
        {
            currentCommand = EXTIME;

            // check for changes
            if (exposureTime != currentExposureTime)
                {
                    currentExposureTime = exposureTime;

                    call imagerComm.readRegister(ADCM_REG_AF_CTRL1);
                }
            else
                signal exposure.setExposureTimeDone(SUCCESS);

            return SUCCESS;
        }

    command result_t exposure.setAnalogGain(color8_t analogGain)
    {
        currentCommand = EAGAIN;
              
        if (     (analogGain.red   != currentAnalogGain.red  ) 
               | (analogGain.green != currentAnalogGain.green) 
               | (analogGain.blue  != currentAnalogGain.blue ) )
            {
                currentAnalogGain.red = analogGain.red;
                currentAnalogGain.green = analogGain.green;
                currentAnalogGain.blue = analogGain.blue;

                call imagerComm.readRegister(ADCM_REG_AF_CTRL1);                
            }
        else
            signal exposure.setAnalogGainDone(SUCCESS);
        
        return SUCCESS;
    }

    command result_t exposure.setDigitalGain(color16_t digitalGain)
    {
        currentCommand = EDGAIN;

        if (   (digitalGain.red   != currentDigitalGain.red) 
               | (digitalGain.green != currentDigitalGain.green) 
               | (digitalGain.blue  != currentDigitalGain.blue) )
            {
                currentDigitalGain.red = digitalGain.red;
                currentDigitalGain.green = digitalGain.green;
                currentDigitalGain.blue = digitalGain.blue;

                call imagerComm.readRegister(ADCM_REG_AF_CTRL1);                
            }
        else
            signal exposure.setDigitalGainDone(SUCCESS);

        return SUCCESS;
    }

    
    default event result_t exposure.setExposureTimeDone(result_t status)
        {
            return SUCCESS;
        }

    default event result_t exposure.setAnalogGainDone(result_t status)
        {
            return SUCCESS;
        }

    default event result_t exposure.setDigitalGainDone(result_t status)
        {
            return SUCCESS;
        }

    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status != SUCCESS)
                {
                    switch (currentCommand)
                        {
                        case EXTIME:
                            signal exposure.setExposureTimeDone(FAIL);
                            break;
                        case EAGAIN:
                            signal exposure.setAnalogGainDone(FAIL);
                            break;
                        case EDGAIN:
                            signal exposure.setDigitalGainDone(FAIL);
                            break;
                        }
                    return FAIL;
                }

            switch (addr)
                {
                    // auto versus manual control
                case ADCM_REG_AF_CTRL1:
                    switch (currentCommand)
                        {
                        case EXTIME:
                            if (currentExposureTime == 0)
                                signal exposure.setExposureTimeDone(SUCCESS);
                            else
                                call imagerComm.readRegister(ADCM_REG_CPP_V);
                            break;
                        case EAGAIN:
                            if (currentAnalogGain.red == 0)
                                signal exposure.setAnalogGainDone(SUCCESS);
                            else
                                call imagerComm.writeRegister(ADCM_REG_EREC_PGA, currentAnalogGain.green);
                            break;
                        case EDGAIN:
                            if (currentDigitalGain.red == 0)
                                signal exposure.setDigitalGainDone(SUCCESS);
                            else
                                call imagerComm.writeRegister(ADCM_REG_APS_COEF_BLUE,  currentDigitalGain.blue);
                            break;
                        }
                    break;

                    // set exposure
                    // *** These commands don't work if they are issued in the opposite order ??? ***
                case ADCM_REG_ROWEXP_L:
		    call imagerComm.writeRegister(ADCM_REG_ROWEXP_H, ((uint8_t) ((rowexp & 0x7F) >> 8) ));
		    break;
                case ADCM_REG_ROWEXP_H:
		    call imagerComm.writeRegister(ADCM_REG_SROWEXP, subrow); // placeholder
		    break;
		case ADCM_REG_SROWEXP:
                    signal exposure.setExposureTimeDone(SUCCESS);  // end of manual exposure adjustment
                    break;

                    // Analog gain
                case ADCM_REG_EREC_PGA:
                    call imagerComm.writeRegister(ADCM_REG_EROC_PGA, currentAnalogGain.red);
                    break;
                case ADCM_REG_EROC_PGA:
                    call imagerComm.writeRegister(ADCM_REG_OREC_PGA, currentAnalogGain.blue);
                    break;
                case ADCM_REG_OREC_PGA:
                    call imagerComm.writeRegister(ADCM_REG_OROC_PGA, currentAnalogGain.green);
                    break;
                case ADCM_REG_OROC_PGA:
                    signal exposure.setAnalogGainDone(SUCCESS);
                    break;
                    
                    // Digital gain
                case ADCM_REG_APS_COEF_BLUE:
                call imagerComm.writeRegister(ADCM_REG_APS_COEF_GRN1, currentDigitalGain.green);
                    break;
                case ADCM_REG_APS_COEF_GRN1:
                call imagerComm.writeRegister(ADCM_REG_APS_COEF_GRN2, currentDigitalGain.green);
                    break;
                case ADCM_REG_APS_COEF_GRN2:
                call imagerComm.writeRegister(ADCM_REG_APS_COEF_RED, currentDigitalGain.red);
                    break;
                case ADCM_REG_APS_COEF_RED:
                    signal exposure.setDigitalGainDone(SUCCESS);
                    break;


                default:  
                    break;
                }
 
           return SUCCESS;
        }

    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
	  uint16_t nRS, nHB, nLA, nCP, nRPT, nSUB;
	  float fRPT, fSUB;

            if (status != SUCCESS)
                {
                    switch (currentCommand)
                        {
                        case EXTIME:
                            signal exposure.setExposureTimeDone(FAIL);
                            break;
                        case EAGAIN:
                            signal exposure.setAnalogGainDone(FAIL);
                            break;
                        case EDGAIN:
                            signal exposure.setDigitalGainDone(FAIL);
                            break;
                        }
                    return FAIL;
                }

            switch (addr)
                {
                case ADCM_REG_AF_CTRL1:   // auto functions
                    switch (currentCommand)
                        {
                        case EXTIME:
                        case EAGAIN:
			    if ((currentExposureTime == 0) || (currentAnalogGain.red == 0))
			        call imagerComm.writeRegister(ADCM_REG_AF_CTRL1, (data | ADCM_AF_AE)); // activate AE
                            else
                                call imagerComm.writeRegister(ADCM_REG_AF_CTRL1, (data & ~ADCM_AF_AE)); // de-activate AE
                            break;
                        case EDGAIN:
                            if (currentDigitalGain.red == 0)
                                call imagerComm.writeRegister(ADCM_REG_AF_CTRL1, (data | ADCM_AF_AWB)); // activate AWB
                            else
                                call imagerComm.writeRegister(ADCM_REG_AF_CTRL1, (data & ~ADCM_AF_AWB)); // de-activate AWB
                            break;
                        }
                    break;
                case ADCM_REG_CPP_V:     // collect values for exposure time calculation
		    cpp = data;
                    call imagerComm.readRegister(ADCM_REG_HBLANK_V);
                    break;
		case ADCM_REG_HBLANK_V:
		    hblank = data;
		    call imagerComm.readRegister(ADCM_REG_VBLANK_V);
		    break;
		case ADCM_REG_VBLANK_V:
		    vblank = data;
		    call imagerComm.readRegister(ADCM_REG_SENSOR_WID_V);
		    break;
		case ADCM_REG_SENSOR_WID_V:
		    cols = data;
		    call imagerComm.readRegister(ADCM_REG_SENSOR_HGT_V);
		    break;
		case ADCM_REG_SENSOR_HGT_V:
		    rows = data;

		    // calculate exposure time, then program row exposure and subrow exposure
		    nRS = ceil(33/cpp);           // reset period?
                    nHB = 2 * hblank * cpp;       // horizontal blanking
                    nLA = 10 * cpp;               // column latch time?
                    nCP = cols * cpp;             // column processing
		    nRPT = nRS + nHB + nLA + nCP;     // row processing time (sensor clocks)
		    fRPT = ((float) nRPT) / MCLK; // row processing time (seconds)
		    rowexp = ((uint16_t) floor(currentExposureTime / fRPT));   // integer part of exposure (rows)
		    fSUB = currentExposureTime - rowexp * fRPT;         // fractional part of exposure
		    nSUB = ((uint16_t) (MCLK * fSUB));     // number of subrow clocks
		    subrow = (uint8_t) (1 + ( ((uint16_t)          ((float) (nRPT - nRS - nSUB -10.5))/(4 * cpp) )  & 0x00FF));  // needs work !!!
		    subMAX = (uint8_t) (1 + ( ((uint16_t)   floor( ((float) (nRPT - nRS - 24))        /(4 * cpp) )) & 0x00FF));
		    subrow =  subrow > subMAX ? subMAX : subrow;
		    call imagerComm.writeRegister(ADCM_REG_ROWEXP_L, ((uint8_t) (rowexp & 0xFF)));  // placeholder
		    break;
		default:
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
