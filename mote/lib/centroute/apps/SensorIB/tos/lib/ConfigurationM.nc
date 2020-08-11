/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 01/06/2004
 *
 *
 *
 */

includes avr_eeprom;

module ConfigurationM
{
  provides {
    interface StdControl as ConfigControl;
    interface ChAcceptCmdI;
  }
  uses interface StdControl as DataMapControl;
  uses interface DmUpdateTableI;
  uses interface Leds;
  uses interface ADCReset;
}
implementation
{

#include "ConfigConst.h"
#include "internalEEprom.h"

  char GetMeasurementbuf[sizeof(sensorConfig_t)];
  
  /***********************Initialization function*********************************/
  command result_t ConfigControl.init() {
    call DataMapControl.init();
    return SUCCESS;
  }
  
  command result_t ConfigControl.start() {
    int i;
    sensorConfig_eprom_t myEpromRecord;  
    
    call DataMapControl.start();
    //reading from eepromg and updating datamap buffer.
    for( i=0; i < NUMBER_OF_HARDWARE_ADDRESSES ; i++)
      {
        myEpromRecord = eepromRead(i);
        if(myEpromRecord.sensor_Attached_Flag == VALID_SENSOR_RECORD) 
          {
            call DmUpdateTableI.updateTable(
                                            myEpromRecord.sensorConfig.measurementName,  
                                            myEpromRecord.sensorConfig.sensorType,  
                                            myEpromRecord.sensorConfig.hardwareAddress,
                                            myEpromRecord.sensorConfig.channelParameter);
          }  
      }
    return SUCCESS;
  }
  
  command result_t ConfigControl.stop() {
    call DataMapControl.stop();
    return SUCCESS;
  }
  
  /***********************Configuration function*********************************/
  default event result_t ChAcceptCmdI.acceptCmdDone(char *buf) {     
    return SUCCESS;
  }  
  
  command result_t ChAcceptCmdI.acceptCmd(char *buf,uint8_t lenght)
    {
      char i;
      char numberRecords;
      uint8_t myMeasurementName;
      sensorConfig_eprom_t myEpromRecord;
      ConfigHeader_t header;
      sensorConfig_t myConfigRecord;

      /*      
      dbg(DBG_USR3, "acceptCmd:\n");
      for( i = 0; i < lenght; i++ )
        {
          dbg(DBG_USR3, "0x%x\n", ((uint8_t*)(buf))[i]);
        }
      */

      memcpy(&header,buf,sizeof(ConfigHeader_t));
      
      switch (header.ConfigType)
        {
          // Use the ADCReset interface to reset the ADC back into
          // ..a valid state.  This is linked through dspSampler, then Sampler,
          // ..and finally to IBADC.
        case CONFIG_RESET_ADC_COMMAND:
          call ADCReset.reset();
          return SUCCESS;
          
        case CONFIG_PUT_COMMAND:
          //assuming header+ some number of sensorConfig_t to be set
          numberRecords = (lenght - sizeof(ConfigHeader_t) ) / sizeof(sensorConfig_t);      
          for(i=0; i<numberRecords ; i++) {
            memcpy(&myConfigRecord,buf + sizeof(ConfigHeader_t) + i * sizeof(sensorConfig_t),sizeof(sensorConfig_t));
            myEpromRecord.sensorConfig = myConfigRecord;        
            myEpromRecord.sensor_Attached_Flag = VALID_SENSOR_RECORD;
            //updating content of the datamap record
            /*
            dbg(DBG_USR3, "Updating table with\n");
            dbg(DBG_USR3, "MN = 0x%x\n", myEpromRecord.sensorConfig.measurementName);
            dbg(DBG_USR3, "ST = 0x%x\n", myEpromRecord.sensorConfig.sensorType);
            dbg(DBG_USR3, "HA = 0x%x\n", myEpromRecord.sensorConfig.hardwareAddress);
            dbg(DBG_USR3, "CP = 0x%x\n", myEpromRecord.sensorConfig.channelParameter);
            */

            call DmUpdateTableI.updateTable(
                                            myEpromRecord.sensorConfig.measurementName,  
                                            myEpromRecord.sensorConfig.sensorType,  
                                            myEpromRecord.sensorConfig.hardwareAddress,
                                            myEpromRecord.sensorConfig.channelParameter);        
            //updating content of the eeprom
            eepromWrite(myEpromRecord);
          }
          signal ChAcceptCmdI.acceptCmdDone(buf);
          return SUCCESS;
          break;
        case CONFIG_GET_COMMAND: //The format is only one measurement name after the command/
          memcpy(&myMeasurementName,buf + sizeof(ConfigHeader_t) + 1,SIZE_OF_MEASUREMENT_NAME);
          //dbg(DBG_USR3, "MN = 0x%x\n", myMeasurementName);
          myEpromRecord = eepromGetMeasurementName(myMeasurementName);
          memcpy(GetMeasurementbuf,&myEpromRecord.sensorConfig,sizeof(sensorConfig_t));
          signal ChAcceptCmdI.acceptCmdDone(GetMeasurementbuf);
          break;
        case CONFIG_GET_HWADDR_COMMAND: //The format is only one measurement name after the command/
          memcpy(&myMeasurementName,buf + sizeof(ConfigHeader_t),SIZE_OF_MEASUREMENT_NAME);
          myEpromRecord = eepromGetMeasurementName(myMeasurementName);
          memcpy(GetMeasurementbuf,&myEpromRecord.sensorConfig,sizeof(sensorConfig_t));
          signal ChAcceptCmdI.acceptCmdDone(GetMeasurementbuf);
          break;
        case CONFIG_ERASE_COMMAND:  //erasing EEPROM records based on the measurement names
          //assuming header+ some number of measurement names to be removed
          numberRecords = (lenght - sizeof(ConfigHeader_t) );      
          for(i=0; i<numberRecords ; i++) {
            //uint8_t myMeasurementName;
            memcpy(&myMeasurementName,buf + sizeof(ConfigHeader_t)+i,SIZE_OF_MEASUREMENT_NAME);
            //deleting content of the datamap record
            call DmUpdateTableI.deleteTable(myMeasurementName);          
            //deleting content of EEPROM permanently
            eepromErasemyMeasurementName(myMeasurementName);
          }
          signal ChAcceptCmdI.acceptCmdDone(buf);      
          return SUCCESS;
          break;
        default:
          return FAIL;       
        }
      return FAIL;     //never should reach here.  
    }
  
}
