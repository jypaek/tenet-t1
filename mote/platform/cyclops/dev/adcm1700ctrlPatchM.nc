// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

//includes imagerConst;
includes adcm1700Const;
includes memConst;

module adcm1700ctrlPatchM
{
    provides {
        interface StdControl as StdControlPatch;
        interface ctrlPatch as patch;
    }
    uses {
        interface imagerComm; 

        interface Timer;
    }
}
implementation
{
    /*  Pseudocode of this component for writing the patches.            //controlState=CONTROL_STATE_PENDING_CONFIGURATION
     *  data=read(ADCM_REG_STATUS)                                <<<--| 
     *  if( data & ADCM_STATUS_CONFIG_MASK) read(ADCM_REG_STATUS) -----| //loop while it is not configured
     *  device = read(ADCM_REG_ID)                                       //controlState = CONTROL_STATE_SETTING_DEVICE
     *  if(device != ADCM_ID_1700) then return FAIL since we have attached wrong module 
     *  read(ADCM_REG_CONTROL)
     *  ADCM_REG_CONTROL <-- &= ~ADCM_CONTROL_RUN_MASK                    //to stop the module so that we can give the patches
     *  writeBlock(ADCM_REG_PADR1)
     *  writeBlock(ADCM_REG_PADR2)
     *  writeBlock(ADCM_REG_PADR3)
     *  writeBlock(ADCM_REG_PADR4)
     *  writeBlock(ADCM_REG_PADR5)
     *  writeBlock(ADCM_REG_PADR6)                                       //patching is done. now setting the communication protocol
     *  read(ADCM_REG_OUTPUT_CTRL_V)                                   //??
     *  ADCM_REG_OUTPUT_CTRL_V <--- |= ADCM_OUTPUT_CTRL_FRVCLK_MASK | ADCM_OUTPUT_CTRL_FR_OUT_MASK | ADCM_OUTPUT_CTRL_JUST_MASK | ADCM_OUTPUT_FORMAT_YV  
     *  read(ADCM_REG_OUTPUT_CTRL_S)                                     //??
     *  ADCM_REG_OUTPUT_CTRL_S <-- |= ADCM_OUTPUT_CTRL_FRVCLK_MASK | ADCM_OUTPUT_CTRL_FR_OUT_MASK | ADCM_OUTPUT_CTRL_JUST_MASK | ADCM_OUTPUT_FORMAT_YV
     *  read(ADCM_REG_OUTPUT_FORMAT)                                     //??
     *  ADCM_REG_OUTPUT_FORMAT <-- |= ADCM_OUTPUT_FORMAT_YV | ADCM_OUTPUT_FORMAT_YS
       
     *  if(SET_SIZE_USING_SIZER) //changing window size to default
     *    ADCM_REG_SZR_IN_WID_V <-- ADCM_SIZE_1700DEFAULT_W                 //step 1:8
     *    ADCM_REG_SZR_IN_HGT_V <-- ADCM_SIZE_1700DEFAULT_H                 //step 2:8
     *    ADCM_REG_SZR_IN_WID_S <-- ADCM_SIZE_1700DEFAULT_W                 //step 3:8
     *    ADCM_REG_SZR_IN_HGT_S <-- ADCM_SIZE_1700DEFAULT_H                 //step 4:8
     *    ADCM_REG_SZR_OUT_WID_V <-- ADCM_SIZE_API_DEFAULT_W                //step 5:8
     *    ADCM_REG_SZR_OUT_HGT_V <-- ADCM_SIZE_API_DEFAULT_H                //step 6:8
     *    ADCM_REG_SZR_OUT_WID_S <-- ADCM_SIZE_API_DEFAULT_W                //step 7:8
     *    ADCM_REG_SZR_OUT_HGT_S <-- ADCM_SIZE_API_DEFAULT_H                //step 8:8
     *    signal patch.setPatchDone (SUCCESS)                               //controlState = CONTROL_STATE_READY;

     *  else                     //Change the window size to the API default
     *    ADCM_REG_FWROW <--- FWROW_1700 (ADCM_SIZE_API_DEFAULT_H)
     *    ADCM_REG_LWROW <--- LWROW_1700 (ADCM_SIZE_API_DEFAULT_H)
     *    ADCM_REG_FWCOL <--- FWCOL_1700 (ADCM_SIZE_API_DEFAULT_W)
     *    ADCM_REG_LWCOL <--- LWCOL_1700 (ADCM_SIZE_API_DEFAULT_W)
     *    read(ADCM_REG_PROC_CTRL_V)                                          //Turn off the SIZER - otherwise, must also write to all of the video and STILL SZR_IN and SZR_OUT registers (8 registers).
     *    ADCM_REG_PROC_CTRL_V <---- |= ADCM_PROC_CTRL_NOSIZER
     *    read(ADCM_REG_PROC_CTRL_S)
     *    ADCM_REG_PROC_CTRL_S <---- |= ADCM_PROC_CTRL_NOSIZER               //controlState = CONTROL_STATE_END
     *    ADCM_REG_CONTROL <--- ADCM_CONTROL_CONFIG_MASK
     *    read(ADCM_REG_CONTROL)                                             //controlState = CONTROL_STATE_START_CFG
     *    ADCM_REG_CONTROL <--- |= ADCM_CONTROL_CONFIG_MASK
     *    data=read(ADCM_REG_CONTROL)                       <<<--|     
     *    if ( (data & ADCM_CONTROL_CONFIG_MASK) == 0)           |           // CONFIG bit has cleared, we are done 
     *         signal patch.setPatchDone (SUCCESS);              |           //controlState = CONTROL_STATE_READY  
     *    else  // re-read and check bit again                   |             
     *         read ADCM_REG_CONTROL                        -----|          // loop here till it is set 
     */

    uint16_t controlState;
    /* patch code, statically initialized */
    uint16_t patchNumber = 0;       /* index into the arrays below */
    static uint16_t patch1700addr[]= {0x0186, 0x4808, 0x4820, 0x4860, 0x486C, 0x4880, 0};
    static uint16_t patch1700len[] = {4, 4, 4, 4, 4, (2*(8*12+2)), 0};
    uint16_t patchdata_index = 0;       /* index into the array below */
    static char patch1700data[] = 
    {
    0x01, 0x04, 0x09, 0x00,
    0x00, 0x02, 0x42, 0x20,
    0x00, 0x02, 0x42, 0x28,
    0x00, 0x02, 0x42, 0x24,
    0x00, 0x02, 0x42, 0x2E,
    0x00, 0x0F, 0x01, 0x60, 0x00, 0x00, 0x7E, 0x80, 0x00, 0x00, 0x7E, 0x90, 0x00, 0x02, 0x04, 0x2F,
    0x00, 0x00, 0x8E, 0xA2, 0x00, 0x05, 0x42, 0x27, 0x00, 0x03, 0x0B, 0x50, 0x00, 0x00, 0x01, 0xFF,
    0x00, 0x00, 0x06, 0x48, 0x00, 0x05, 0x42, 0x2C, 0x00, 0x00, 0x9A, 0xA1, 0x00, 0x05, 0x08, 0x00,
    0x00, 0x00, 0x06, 0x28, 0x00, 0x02, 0x07, 0xBD, 0x00, 0x00, 0x5D, 0x3F, 0x00, 0x00, 0x59, 0x40,
    0x00, 0x00, 0x04, 0x16, 0x00, 0x00, 0x02, 0x77, 0x00, 0x00, 0x01, 0xA7, 0x00, 0x00, 0x04, 0x3F,
    0x00, 0x00, 0x06, 0x4E, 0x00, 0x04, 0x42, 0x37, 0x00, 0x00, 0x04, 0x27, 0x00, 0x00, 0x5B, 0x4C,
    0x00, 0x00, 0x01, 0x7E, 0x00, 0x07, 0x42, 0x42, 0x00, 0x00, 0x5B, 0x4D, 0x00, 0x00, 0x01, 0x7E,
    0x00, 0x07, 0x42, 0x42, 0x00, 0x00, 0x5B, 0x4E, 0x00, 0x00, 0x01, 0x7E, 0x00, 0x07, 0x42, 0x42,
    0x00, 0x00, 0x06, 0x0E, 0x00, 0x02, 0x09, 0x34, 0x00, 0x00, 0x06, 0x2E, 0x00, 0x0F, 0x00, 0x18,
    0x00, 0x00, 0x5B, 0x4D, 0x00, 0x00, 0x01, 0x7E, 0x00, 0x07, 0x42, 0x4A, 0x00, 0x00, 0x5B, 0x4E,
    0x00, 0x00, 0x01, 0x7E, 0x00, 0x06, 0x42, 0x4B, 0x00, 0x00, 0x01, 0xFF, 0x00, 0x00, 0x5E, 0xBF,
    0x00, 0x0E, 0x01, 0x00, 0x00, 0x00, 0x00, 0xF7, 0x00, 0x00, 0x04, 0x07, 0x00, 0x00, 0x00, 0x77,
    0x00, 0x02, 0x09, 0x3A
    };

    enum {
        CONTROL_STATE_PENDING_CONFIGURATION = 0,
        CONTROL_STATE_SETTING_DEVICE,
        CONTROL_STATE_END,          /* wait for config */
        CONTROL_STATE_START_CFG,    /* bring start up configuration online */
        CONTROL_STATE_READY,        /* ready for run-time commands */
    };
    
    //*******************Inititialization and Termination*********************/
    command result_t StdControlPatch.init() 
        {
            controlState = CONTROL_STATE_PENDING_CONFIGURATION;
            return SUCCESS;
        }
    
    command result_t StdControlPatch.start() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlPatch.stop() 
        {
            /* reset some of the variables */
            patchNumber = 0;
            patchdata_index = 0;
            return SUCCESS;
        }

    //***********************Patch Control*********************/
    command result_t patch.setPatch()
        {
            //mhr: This component is reentrant. There is no provision to avoid calling it while it is still running
            patchNumber = 0;
            patchdata_index = 0;
            controlState = CONTROL_STATE_PENDING_CONFIGURATION;
            call imagerComm.readRegister (ADCM_REG_STATUS);                // Most of the initialization is performed in the callback routine
            return SUCCESS;
        }
    
    default event result_t patch.setPatchDone(result_t status)
        {
            return SUCCESS;
        }

    //******************* Timer (allows enough time for module to exit run mode) ******
    event result_t Timer.fired()
    {
        call imagerComm.writeBlock (ADCM_REG_PADR1, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
        return SUCCESS;
    }
 
    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {           
            //mhr:note that it is ok if the status fails when the device is stll configuring itself since we can not communicate with it in the meantime, we retry
            if ((controlState != CONTROL_STATE_PENDING_CONFIGURATION) && (status == FAIL)) { signal patch.setPatchDone(FAIL);   return FAIL; }            
            switch (addr) 
                {
                case ADCM_REG_STATUS: //mhr:checking if the device is configured and now ready to be set.
                    if (controlState == CONTROL_STATE_PENDING_CONFIGURATION) 
                        {          // part of startup
                            if (status == SUCCESS) {
                                if (data & ADCM_STATUS_CONFIG_MASK) // still configuring, check again.  Should probably add a delay
                                    call imagerComm.readRegister (ADCM_REG_STATUS);
                                else                                // it is now configured, we officialy go the mode to set different registers of the device.
                                    {
                                        atomic controlState = CONTROL_STATE_SETTING_DEVICE;
                                        call imagerComm.readRegister (ADCM_REG_ID);
                                    }
                            } else                                  // there was an error, repeat the request                                
                                call imagerComm.readRegister (ADCM_REG_STATUS);
                        }
                    break;
                case ADCM_REG_ID:  //checking if we have the right imager
                    if (controlState == CONTROL_STATE_SETTING_DEVICE) 
                        {
                            // continue with startup intialization, stop the imager to re-configure it. CONTROL register is read first and the RUN bit is turned off
                            if ((ADCM_ID_MASK & data) == (ADCM_ID_MASK & ADCM_ID_1700)) call imagerComm.readRegister (ADCM_REG_CONTROL);                                
                            // had a failure (incorrect module ID)
                            else { signal patch.setPatchDone (FAIL); return FAIL; }
                        }
                    break;
                case ADCM_REG_CONTROL:
                    switch(controlState)
                        {
                        case CONTROL_STATE_SETTING_DEVICE:  // clear the RUN bit and write it out
                            call imagerComm.writeRegister (ADCM_REG_CONTROL, (data & ~ADCM_CONTROL_RUN_MASK));                        
                            break;
                        case CONTROL_STATE_END: // Bring the new configuration online by setting the CONFIG bit in the CONTROL register                         
                            atomic controlState = CONTROL_STATE_START_CFG;
                            // was ADCM_CONTROL_CONFIG_MASK:   RLB 3/18/05
                            call imagerComm.writeRegister (ADCM_REG_CONTROL, (data | ADCM_CONTROL_RUN_MASK));
                            break;
                        case CONTROL_STATE_START_CFG: // initializing the imager, and now bringing the configuration online. check if still configuring. 
                            if ((data & ADCM_CONTROL_CONFIG_MASK) == 0)  // CONFIG bit has cleared, we are done 
                                {
                                    atomic controlState = CONTROL_STATE_READY;
                                    signal patch.setPatchDone (SUCCESS);
                                } 
                            else  // re-read and check bit again                                
                                call imagerComm.readRegister (ADCM_REG_CONTROL);                            
                            break;
                        default:
                        }
                    break;                        
                case ADCM_REG_OUTPUT_CTRL_V:
                    call imagerComm.writeRegister (ADCM_REG_OUTPUT_CTRL_V, (data | ADCM_OUTPUT_CTRL_FRVCLK_MASK | ADCM_OUTPUT_CTRL_FR_OUT_MASK 
                                                                            | ADCM_OUTPUT_CTRL_JUST_MASK | ADCM_OUTPUT_FORMAT_Y));                    
                    break;
                case ADCM_REG_PROC_CTRL_V:
                    if (controlState == CONTROL_STATE_SETTING_DEVICE)
                        call imagerComm.writeRegister (ADCM_REG_PROC_CTRL_V, (data & ~ADCM_PROC_CTRL_NOSIZER));                    
                    break;
                default:
                    signal patch.setPatchDone(FAIL);   
                    return FAIL;
                }
            return SUCCESS;
        }
    
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status == FAIL) { signal patch.setPatchDone(FAIL);  return FAIL; } 
            
            switch (addr) {
            case ADCM_REG_CONTROL:  
                switch(controlState)
                    {
                    case CONTROL_STATE_SETTING_DEVICE: // start patching code 
                        call Timer.start(TIMER_ONE_SHOT, 500);
                        //call imagerComm.writeBlock (ADCM_REG_PADR1, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
                        break;
                    case CONTROL_STATE_END: // read the register to check for the config bit 
                        call imagerComm.readRegister (ADCM_REG_CONTROL);
                        break;
                    case CONTROL_STATE_START_CFG:
                        // just set CONFIG bit, read the register to see if it has been cleared, indicating it is done. callback for this read will check the CONFIG bit
                        call imagerComm.readRegister (ADCM_REG_CONTROL);
                        break;
                    default:
                    }
                break;
            case ADCM_REG_OUTPUT_CTRL_V:
	        //call imagerComm.writeRegister (ADCM_REG_SZR_IN_WID_V, ADCM_SIZE_1700DEFAULT_W);  // debug
	        call imagerComm.writeRegister (ADCM_REG_CLK_PER, 0x0FA0);   // 4 MHz (4,000 kHz)
	        break;
	    case ADCM_REG_CLK_PER:
	        call imagerComm.writeRegister (ADCM_REG_AE2_ETIME_MIN, 0x0001); // 10 microseconds
	        break;
	    case ADCM_REG_AE2_ETIME_MIN:
	        call imagerComm.writeRegister (ADCM_REG_AE2_ETIME_MAX, 0xC350); // 0.5 seconds
	        break;
	    case ADCM_REG_AE2_ETIME_MAX:
	        call imagerComm.writeRegister (ADCM_REG_AE_GAIN_MAX, 0x0F00);   // analog gain = 15
	        break;
	    case ADCM_REG_AE_GAIN_MAX:
	        call imagerComm.writeRegister (ADCM_REG_AF_CTRL1, 0x0013); // auto functions activated
		break;
	    case ADCM_REG_AF_CTRL1:
	        call imagerComm.writeRegister (ADCM_REG_AF_CTRL2, 0x0002); // no overexposure, 60 Hz
	        break;
	    case ADCM_REG_AF_CTRL2:
                call imagerComm.writeRegister (ADCM_REG_SZR_IN_WID_V, ADCM_SIZE_1700DEFAULT_W); 
                break;
            case ADCM_REG_SZR_IN_WID_V:  //step sizer:1:9
                call imagerComm.writeRegister (ADCM_REG_SZR_IN_HGT_V, ADCM_SIZE_1700DEFAULT_H);                 
                break;
            case ADCM_REG_SZR_IN_HGT_V:  //step sizer:2:9
                call imagerComm.writeRegister (ADCM_REG_SZR_OUT_WID_V, ADCM_SIZE_API_DEFAULT_W);                 
                break;
            case ADCM_REG_SZR_OUT_WID_V: //step sizer:5:9
                call imagerComm.writeRegister (ADCM_REG_SZR_OUT_HGT_V, ADCM_SIZE_API_DEFAULT_H); 
                break;
            case ADCM_REG_SZR_OUT_HGT_V: //step sizer:6:9
                call imagerComm.readRegister (ADCM_REG_PROC_CTRL_V);
                break;
            case ADCM_REG_PROC_CTRL_V: // set window size: step 8 of 9
                call imagerComm.writeRegister (ADCM_REG_VBLANK_V, ADCM_VBLANK_DEFAULT);
                break;
            case ADCM_REG_VBLANK_V: // set vblank interval: step 9 of 9
                atomic controlState = CONTROL_STATE_READY;
                signal patch.setPatchDone (SUCCESS);
                return SUCCESS;
                
                break;
            }
            return SUCCESS;
        }
    
    //***********************Writing and Reading Blocks*********************/
    event result_t imagerComm.writeBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status)
        {
            if (status != SUCCESS) signal patch.setPatchDone (FAIL);            
            switch (startReg) {
            case ADCM_REG_PADR1: // write the next patch block 
                patchdata_index = patchdata_index + patch1700len[patchNumber];
                ++patchNumber;
                call imagerComm.writeBlock (ADCM_REG_PADR2, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
                break;
            case ADCM_REG_PADR2: // write the next patch block 
                patchdata_index = patchdata_index + patch1700len[patchNumber];
                ++patchNumber;
                call imagerComm.writeBlock (ADCM_REG_PADR3, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
                break;
            case ADCM_REG_PADR3: // write the next patch block 
                patchdata_index = patchdata_index + patch1700len[patchNumber];
                ++patchNumber;
                call imagerComm.writeBlock (ADCM_REG_PADR4, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
                break;
            case ADCM_REG_PADR4: // write the next patch block 
                patchdata_index = patchdata_index + patch1700len[patchNumber];
                ++patchNumber;
                call imagerComm.writeBlock (ADCM_REG_PADR5, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);
                break;
            case ADCM_REG_PADR5: // write the next patch block 
                patchdata_index = patchdata_index + patch1700len[patchNumber];
                ++patchNumber;
                call imagerComm.writeBlock (ADCM_REG_PADR6, &patch1700data[patchdata_index], (uint8_t)patch1700len[patchNumber]);	// *** diagnostic ***
                break;
            case ADCM_REG_PADR6: // Patching dine, set data protocol that the CPLD expects,first read the register value and set the new data in the callback
                call imagerComm.readRegister (ADCM_REG_OUTPUT_CTRL_V);
                break;
            default:
                signal patch.setPatchDone (FAIL);
                break;
            }
            return SUCCESS;
        }
    
    event result_t imagerComm.readBlockDone(uint16_t startReg,char *data,uint8_t length,result_t status) 
        {
            return SUCCESS;
        }

}
