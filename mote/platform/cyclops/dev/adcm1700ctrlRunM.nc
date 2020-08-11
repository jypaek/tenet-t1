// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 

// This interface is used to control the operation of the camera module.
// The RUN bit of the primary CONFIG (ADCM_REG_CONTROL) register is used to switch the 
// entire module (sensor and image processor) between RUN and STBY modes. The RUN bit 
// of the secondary CONTROL register (ADCM_REG_SENSOR_CTRL) is used to switch the sensor 
// on and off in order to pan the ROI. 
//
// Module control:
//  If the module is already in the desired mode, no further operation is performed.
//  
// Sensor control:
//  If the module is already in the desired mode, no further operation is performed.
//
//  The module must continue running while the sensor is stopped and started in order
// to accomplish a pan operation. This component does not include any checks to make sure
// the correct sequence is used. Caveat emptor!
// 
//  Once the module has been stopped, programming should not be attempted until the 
// processing of the current frame is complete. The run.camera(STOP) procedure checks the 
// status of the module to ensure this condition before it posts a cameraDone event. 

//  

//includes imagerConst;
includes adcm1700Const;
includes memConst;

#define POLL_DELAY 50    // delay between polling attempts
#define POLL_MAX 16      // maximum number of polling attempts

#define SENSOR_RUN_BIT 0x02
#define PROC_RUN_BITS 0x70

module adcm1700ctrlRunM
{
    provides {
        interface StdControl as StdControlRun;
        interface ctrlRun as run;
    }
    uses {
        interface imagerComm;
        interface Timer;   // used to reduce energy consumption in polling loop
        interface Leds;    // *** DIAGNOSTIC ***
 }
}
implementation
{

    // register values for commands
    enum {
        MODULE_RUN=0x0001,
        MODULE_STOP=0x0000,
        SENSOR_RUN=0x24,         // low-power mode remains enabled
        SENSOR_STOP=0x20
    };
    
    uint8_t currentModuleState;   // current state
    uint8_t currentSensorState;

    uint8_t currentTarget;        // target of run/stop operation
    enum
        {
            TARGET_MODULE,
            TARGET_SENSOR
        };

    uint16_t currentRegister;    // used in polling

    uint8_t pollCount;           // abort after polling MAX_POLL times
    

    //*******************Inititialization and Termination*********************/
    command result_t StdControlRun.init() 
        {
            return SUCCESS;
        }
    
    command result_t StdControlRun.start() 
        {
            currentModuleState = CYCLOPS_RUN;   // the module will begin to run when it is powered up
            currentSensorState = CYCLOPS_RUN;
            return SUCCESS;
        }
    
    command result_t StdControlRun.stop() 
        {
            return SUCCESS;
        }

    //***********************Run Control*********************/
    command result_t run.camera(uint8_t run_stop)
        {  
            currentTarget = TARGET_MODULE;
            pollCount = 0;

            // *** REMOVED 4/14/05 by RLB ***
            // *** Causes timing problems on the first capture ***
            //if (run_stop == currentModuleState)   // no action required
            //    {
            //        signal run.cameraDone(run_stop, SUCCESS);
            //        return SUCCESS;
            //    }

            currentModuleState = run_stop;
            currentSensorState = run_stop;       // sensor is slave to module


            if (run_stop == CYCLOPS_RUN)
                call imagerComm.writeRegister(ADCM_REG_CONTROL, MODULE_RUN);
            else
                call imagerComm.writeRegister(ADCM_REG_CONTROL, MODULE_STOP);

            return SUCCESS;
        }

    default event result_t run.cameraDone(uint8_t run_stop, result_t status)
        {
            return SUCCESS;
        }

  command result_t run.sensor(uint8_t run_stop)
        {  
            currentTarget = TARGET_SENSOR;
            pollCount = 0;

            if (run_stop == currentSensorState)
                {
                    signal run.sensorDone(run_stop, SUCCESS);
                    return SUCCESS;
                }

            currentSensorState = run_stop;
            
            if (run_stop == CYCLOPS_RUN)
                call imagerComm.writeRegister(ADCM_REG_SENSOR_CTRL, SENSOR_RUN);
            else
                call imagerComm.writeRegister(ADCM_REG_SENSOR_CTRL, SENSOR_STOP);

            return SUCCESS;
        }

    default event result_t run.sensorDone(uint8_t run_stop, result_t status)
        {
            return SUCCESS;
        }
 
    //***********************Writing and Reading individual Bytes*********************/
    event result_t imagerComm.readRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {
            if (status != SUCCESS)  // failure clause
                {
                    switch(currentTarget)
                        {
                        case TARGET_MODULE:
                            signal run.cameraDone(currentModuleState, FAIL);
                            break;
                        case TARGET_SENSOR:
                            signal run.sensorDone(currentSensorState, FAIL);
                            break;
                        default:
                            break;
                        }
                    return FAIL;
                }
            
            switch (addr)
                {
                case ADCM_REG_SENSOR_CTRL:
                    if (data & SENSOR_RUN_BIT)
                        {
                            if (pollCount >= POLL_MAX)
                                {
                                    switch(currentTarget)
                                        {
                                        case TARGET_MODULE:
                                            signal run.cameraDone(currentModuleState, FAIL);
                                            break;
                                        case TARGET_SENSOR:
                                            signal run.sensorDone(currentSensorState, FAIL);
                                            break;
                                        default:
                                            break;
                                        }
                                    return FAIL;
                                }
                            currentRegister = ADCM_REG_SENSOR_CTRL;    // polling loop: check every 50 mS
                            call Timer.start(TIMER_ONE_SHOT, POLL_DELAY);
                            pollCount++;
                        }
                    else
                        {
                            if (currentTarget == TARGET_MODULE)
                                call imagerComm.readRegister(ADCM_REG_STATUS_FLAGS);  // make sure processor is empty
                            else
                              signal run.sensorDone(currentSensorState, status);    // end of the line!
                        }  
                    break;
                case ADCM_REG_STATUS_FLAGS:
                    if ((data & PROC_RUN_BITS) == PROC_RUN_BITS)
                        signal run.cameraDone(currentModuleState, status);
                    else
                        {
                            if (pollCount >= POLL_MAX)
                                {
                                    switch(currentTarget)
                                        {
                                        case TARGET_MODULE:
                                            signal run.cameraDone(currentModuleState, FAIL);
                                            break;
                                        case TARGET_SENSOR:
                                            signal run.sensorDone(currentSensorState, FAIL);
                                            break;
                                        default:
                                            break;
                                        }
                                    return FAIL;
                                }
                            currentRegister = ADCM_REG_STATUS_FLAGS;    // polling loop: check every 50 mS
                            call Timer.start(TIMER_ONE_SHOT, POLL_DELAY);
                            pollCount++;
                        }
                    break;
                }

            return SUCCESS;
        }
    
    event result_t imagerComm.writeRegisterDone (uint16_t addr, uint16_t data,result_t status)
        {                        
            if (status != SUCCESS)  // failure clause
                {
                    switch(currentTarget)
                        {
                        case TARGET_MODULE:
                            signal run.cameraDone(currentModuleState, FAIL);
                            break;
                        case TARGET_SENSOR:
                            signal run.sensorDone(currentSensorState, FAIL);
                            break;
                        default:
                            break;
                        }
                    return FAIL;
                }

            switch (addr) 
                {
                case ADCM_REG_CONTROL: // module
                    if (data == MODULE_STOP)
                        call imagerComm.readRegister(ADCM_REG_SENSOR_CTRL);  // make sure sensor has stopped
                    else
                        signal run.cameraDone(currentModuleState, status);
                    break;
                case ADCM_REG_SENSOR_CTRL:  // sensor
                    if (data == SENSOR_STOP)
                       call imagerComm.readRegister(ADCM_REG_SENSOR_CTRL);  // make sure sensor has stopped 
                    else
                        signal run.sensorDone(currentSensorState, status);    // end of the line!
                    break;
                default:   // we shouldn't get here
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
    
    // ******************** Timer (used in polling loop) *******************
    event result_t Timer.fired()
    {
        call imagerComm.readRegister(currentRegister);

        return SUCCESS;
    }
}

