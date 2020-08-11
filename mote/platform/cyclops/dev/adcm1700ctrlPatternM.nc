// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

// This component selects between normal imaging and the test pattern 
// generator. Test patterns are injected at the input to the image processing
// pipeline.
// The DATA_GEN register (0x105e) is used to select test modes. Valid values
// include:
//    0x00   normal imaging mode
//    0x03   sum of coordinates pattern
//    0x04   black field with 8-pixel wide white border
//    0x05   checkerboard test
//    0x07   color bars
// The upper 8-bits of the DATA_GEN register are reserved.

includes adcm1700Const;
includes memConst;

module adcm1700ctrlPatternM
{
    provides {
        interface StdControl as StdControlPattern;
        interface ctrlPattern as pattern;
    }
    uses {
        interface imagerComm;        
    }
}
implementation
{
    // 
    uint8_t currentPattern;           // current state of component (and module)

    //*******************Inititialization and Termination*********************/
    command result_t StdControlPattern.init() 
        {
            currentPattern = CYCLOPS_TEST_MODE_UNSET;    // default is normal imaging
            return SUCCESS;
        }
    
    command result_t StdControlPattern.start() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlPattern.stop() 
        {
            return SUCCESS;
        }

    //***********************Format Control*********************/
    command result_t pattern.setPattern(uint8_t myPattern)
        {
            // perform value checking here!
            if (myPattern != currentPattern)
                {
                    currentPattern = myPattern;
                    switch (myPattern)
                        {
                        case CYCLOPS_TEST_MODE_NONE:
                            call imagerComm.writeRegister (ADCM_REG_DATA_GEN, ADCM_TEST_MODE_NONE);
                            break;
                        case CYCLOPS_TEST_MODE_SOC:
                            call imagerComm.writeRegister (ADCM_REG_DATA_GEN, ADCM_TEST_MODE_SOC);
                            break;
                        case CYCLOPS_TEST_MODE_8PB:
                            call imagerComm.writeRegister (ADCM_REG_DATA_GEN, ADCM_TEST_MODE_8PB);
                            break;
                        case CYCLOPS_TEST_MODE_CKB:
                            call imagerComm.writeRegister (ADCM_REG_DATA_GEN, ADCM_TEST_MODE_CKB);
                            break;
                        case CYCLOPS_TEST_MODE_BAR:
                            call imagerComm.writeRegister (ADCM_REG_DATA_GEN, ADCM_TEST_MODE_BAR);
                            break;
                        default:
                            signal pattern.setPatternDone(FAIL);   // unrecognized test mode
                            break;
                        }
                }
            else
                signal pattern.setPatternDone(SUCCESS);   // no operation required

            return SUCCESS;
        }

    default event result_t pattern.setPatternDone(result_t status)
        {
            return SUCCESS;
        }

    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            signal pattern.setPatternDone(status);

            return SUCCESS;
        }

    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
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
