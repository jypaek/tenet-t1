// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

// This component sets the image type (e.g. monochrome, color, etc.) 


includes adcm1700Const;
includes memConst;

module adcm1700ctrlFormatM
{
    provides {
        interface StdControl as StdControlFormat;
        interface ctrlFormat as format;
    }
    uses {
        interface imagerComm;   

        // diagnostic
        interface Leds;
    }
}
implementation
{
    // current state of component (and camera module)
    uint8_t currentFormat;

        
    //*******************Inititialization and Termination*********************/
    command result_t StdControlFormat.init() 
        {
            currentFormat = CYCLOPS_IMAGE_TYPE_UNSET;   // force initialization
            return SUCCESS;
        }
    
    command result_t StdControlFormat.start() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlFormat.stop() 
        {
            return SUCCESS;
        }

    //***********************Format Control*********************/
    command result_t format.setFormat(uint8_t myType)
        {
            // force update
            if (myType != currentFormat)
                {
                    currentFormat = myType;  // save format for subsequent use
                    call imagerComm.readRegister (ADCM_REG_OUTPUT_CTRL_V);    // everything else happens in the call backs
                }
            else
                signal format.setFormatDone(SUCCESS);

            return SUCCESS;
        }

    default event result_t format.setFormatDone(result_t status)
        {
            return SUCCESS;
        }
    
    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status != SUCCESS)
                {
                    signal format.setFormatDone (FAIL);
                    return FAIL;
                }

            signal format.setFormatDone (SUCCESS);
            return SUCCESS;
        }


    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status != SUCCESS)    // need current register value to proceed
                {
                    signal format.setFormatDone (FAIL);
                    return FAIL;
                }

            switch(currentFormat)       // set the new video format
                {
                case CYCLOPS_IMAGE_TYPE_RGB:
                    call imagerComm.writeRegister (ADCM_REG_OUTPUT_CTRL_V, ((data & 0xFFF0) | ADCM_OUTPUT_FORMAT_RGB));
                    break;
                case CYCLOPS_IMAGE_TYPE_YCbCr:
                    call imagerComm.writeRegister (ADCM_REG_OUTPUT_CTRL_V, ((data & 0xFFF0) | ADCM_OUTPUT_FORMAT_YCbCr));
                    break;
                case CYCLOPS_IMAGE_TYPE_RAW:
                    call imagerComm.writeRegister (ADCM_REG_OUTPUT_CTRL_V, ((data & 0xFFF0) | ADCM_OUTPUT_FORMAT_RAW));
                    break;
                case CYCLOPS_IMAGE_TYPE_Y:
                    call imagerComm.writeRegister (ADCM_REG_OUTPUT_CTRL_V, ((data & 0xFFF0) | ADCM_OUTPUT_FORMAT_Y));
                    break;
                default:
                    signal format.setFormatDone (FAIL);
                    return FAIL;
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
