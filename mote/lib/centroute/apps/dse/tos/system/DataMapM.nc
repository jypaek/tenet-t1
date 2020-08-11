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
 */


includes sensorboard;

module DataMapM
{
  provides interface StdControl as DataMapControl;
  provides interface DmUpdateTableI;
  provides interface DmAcceptMnAndTI;
  provides interface DmMappingI;

  uses {
    interface Leds;

    // Sampler Communication
    interface StdControl as SamplerControl;
    interface SampleRequest;
    
  }
}

implementation
{
  /*
   * Prototypes.
   */
  uint8_t getChannelNumber(uint8_t myHardwareAddress);
  uint8_t getChannelType(uint8_t myHardwareAddress);
  
#include "ConfigConst.h"
#include "StdDbg.h"
  
  sensorConfig_t configTable[MAX_CONFIG];
  uint8_t numberOfSensors;
  
  command result_t DataMapControl.init() {
    // No configured sensors yet
    numberOfSensors = 0;
    return call SamplerControl.init();
    return SUCCESS;
  }
  
  command result_t DataMapControl.start() {
    call SamplerControl.start();
    return SUCCESS;
  }
  
  command result_t DataMapControl.stop() {
    call SamplerControl.stop();
    return SUCCESS;
  }
  
  command result_t DmUpdateTableI.updateTable(uint8_t msrName,
                                              uint8_t sensorName,
                                              uint8_t chanNum,
                                              uint8_t params) {
    int i;

    // Too many sensors?
    if (numberOfSensors == MAX_CONFIG)
      return FAIL;

    // Check if the measurement name already exists
    for (i = 0; i < numberOfSensors; i++)
      if(configTable[i].measurementName == msrName)
        return FAIL; 

    // Update the table, simply shoving it at the end.
    configTable[numberOfSensors].measurementName  = msrName;
    configTable[numberOfSensors].sensorType       = sensorName;
    configTable[numberOfSensors].hardwareAddress  = chanNum;
    configTable[numberOfSensors].channelParameter = params; 
    numberOfSensors++;

    stddbg("Updating table with "
           "msrname = %d  "
           "sensorName = %d  "
           "chanNum = %d  "
           "params = %d  ",
           msrName, sensorName, chanNum, params);

    // Yay
    return SUCCESS;
  }

  /*
   * More deleting FROM the table.
   */
  command result_t DmUpdateTableI.deleteTable(uint8_t  msrName) 
    {
      // Ubiquitous for loop variables.
      int i, j;

      for (i = 0; i < numberOfSensors; i++)
        {
          if (configTable[i].measurementName == msrName) 
            {
              // The problem with just storing the MN at the end of the table
              // ..rears its ugly head (we have to move all the other entries up).
              // ..Leave the last entry hanging, it won't be accessable as we decrement
              // ..numberOfSensors.
              for (j = i; j < numberOfSensors - 1; j++)
                {
                  configTable[j].measurementName  = configTable[j+1].measurementName;
                  configTable[j].sensorType       = configTable[j+1].sensorType;
                  configTable[j].hardwareAddress  = configTable[j+1].hardwareAddress;
                  configTable[j].channelParameter = configTable[j+1].channelParameter;
                }
              numberOfSensors--;
              
              stddbg("Successfully found and deleted sensor with msnName = %d", msrName);

              // Found and deleted.
              return SUCCESS;
            }
        }

      stddbg("Failed to find and deleted sensor with msnName = %d", msrName);
      return FAIL;
    }

  /*
   * Find the hardware address from a measurement name.
   * Note: To follow the other functions, return SUCCESS or FAIL, and pass
   * a place to put the hardware address by reference.
   */
    command uint8_t DmMappingI.mn2hwAddr(uint8_t msrName)
      {
        int i;
        
        for (i = 0; i < numberOfSensors; i++)
          { 
            if (configTable[i].measurementName == msrName)
              {
                // Debuggin output
                stddbg("msnName = %d mapped successfully to %d",
                       msrName,
                       configTable[i].hardwareAddress);

                return configTable[i].hardwareAddress;
              }
          }

        stddbg("msnName = %d couldn't be mapped.", msrName);

        // No match is found
        return NO_HARDWARE_ADDRESS; 
      }

    /*
     * Map from hardware address to measurement name.
     * Note: Same as above.
     */
    command uint8_t DmMappingI.hwAddr2mn(uint8_t chanName)
      {
        int i;
        for(i = 0; i < numberOfSensors; i++)
          {
            if (configTable[i].hardwareAddress == chanName) 
              {
                stddbg("chanName = %d mapped successfully to %d",
                       chanName,
                       configTable[i].measurementName);

                return configTable[i].measurementName;
              }
          }

        // no match is found
        return NO_MEASUREMENT_NAME; 
      }
    
    //****************************Code sould be double checked****************************
    uint8_t getHardwareAddress(uint8_t channelType, uint8_t channelNumber)
      {
        if (channelType == ANALOG) {
          switch (channelNumber) {
          case 0:  return ADC0_HARDWARE_ADDRESS;
          case 1:  return ADC1_HARDWARE_ADDRESS;
          case 2:  return ADC2_HARDWARE_ADDRESS;
          case 3:  return ADC3_HARDWARE_ADDRESS;
          case 4:  return ADC4_HARDWARE_ADDRESS;
          case 5:  return ADC5_HARDWARE_ADDRESS;
          case 6:  return ADC6_HARDWARE_ADDRESS;
          case 7:  return ADC7_HARDWARE_ADDRESS;
          case 8:  return ADC8_HARDWARE_ADDRESS;
          case 9:  return ADC9_HARDWARE_ADDRESS;
          case 10: return ADC10_HARDWARE_ADDRESS;
          case 11: return ADC11_HARDWARE_ADDRESS;
          case 12: return ADC12_HARDWARE_ADDRESS;
          case 13: return ADC13_HARDWARE_ADDRESS;
          default:
            break;
          }
        }
        
        if (channelType == BATTERY)     return BATTEREY_HARDWARE_ADDRESS;       
        if (channelType == HUMIDITY)    return HUM_HARDWARE_ADDRESS;          
        if (channelType == TEMPERATURE) return TEMP_HARDWARE_ADDRESS;
        if (channelType == COUNTER)     return COUNTER_HARDWARE_ADDRESS;
        
        if(channelType==DIGITAL) {
          switch (channelNumber) {
          case 0: return DIG0_HARDWARE_ADDRESS;
          case 1: return DIG1_HARDWARE_ADDRESS;
          case 2: return DIG2_HARDWARE_ADDRESS;
          case 3: return DIG3_HARDWARE_ADDRESS;
          case 4: return DIG4_HARDWARE_ADDRESS;
          case 5: return DIG5_HARDWARE_ADDRESS;
          default:
            break;
          }
        }

        // Just to get this to work for now
        if (channelType == DAQ) {
          switch (channelNumber) {
          case 0: return DAQ0_HARDWARE_ADDRESS; 
          case 1: return DAQ1_HARDWARE_ADDRESS; 
          case 2: return DAQ2_HARDWARE_ADDRESS; 
          case 3: return DAQ3_HARDWARE_ADDRESS; 
          case 4: return DAQ4_HARDWARE_ADDRESS; 
          case 5: return DAQ5_HARDWARE_ADDRESS; 
          case 6: return DAQ6_HARDWARE_ADDRESS; 
          case 7: return DAQ7_HARDWARE_ADDRESS; 
          default:
            break;
          }
        }

        // Address not found.
        return NO_HARDWARE_ADDRESS;
      }

    /*
     * Map hardware address to sensor type.
     */
    command uint8_t DmMappingI.hwAddr2sensorType(uint8_t chanType,uint8_t channelNumber)
      {
        int i;
        uint8_t chanName;
        
        chanName = getHardwareAddress(chanType, channelNumber);

        // No match is found, the value should change.
        // Note: Is this some sort of error checking?
        if (chanName == NO_HARDWARE_ADDRESS)
          return 0xff; 

        for(i = 0; i < numberOfSensors; i++)
          {
            if(configTable[i].hardwareAddress==chanName) 
              {
                stddbg("sensorType = %d mapped successfully to %d", configTable[i].sensorType, chanName);
                return configTable[i].sensorType;
              }
          }
        
        return 0xff; //no match is found, the value should change.
      }

    command uint8_t DmMappingI.channelTypeNumber2mn(uint8_t chanType,uint8_t channelNumber)
      {
        int i;
        uint8_t chanName;
        chanName = getHardwareAddress(chanType,channelNumber);
        if(chanName==NO_HARDWARE_ADDRESS) return NO_MEASUREMENT_NAME; //no match is found
        for(i=0;i<numberOfSensors;i++)
          {
            if(configTable[i].hardwareAddress==chanName) 
              {
                stddbg("chanName = %d mapped successfully to %d", chanName, configTable[i].measurementName);
                return configTable[i].measurementName;
              }
          }        
        return NO_MEASUREMENT_NAME; //no match is found
      }
    
    //****************************end of Code sould be double checked****************************

    command result_t DmAcceptMnAndTI.mnExist(uint8_t  msrName)
      {
        int i;
        for(i=0;i<numberOfSensors;i++) 
          {
            if(configTable[i].measurementName==msrName) 
            {
              stddbg("msrName = %d exists", msrName);
              return SUCCESS;
            }
          }
        
        stddbg("msrName = %d does not exists", msrName);
        return FAIL;
      }

    
    command int8_t DmAcceptMnAndTI.passMnT(uint8_t msrName,uint16_t samplePeriod)
      {
        int i;
        for(i=0;i<numberOfSensors;i++) 
          if(configTable[i].measurementName==msrName)
            {   
              stddbg("msrName = %d being passed to sampler.", msrName);
              stddbg("channelNum = %d, channType = %d, sp = %d, chanPara = %d",
                                                  getChannelNumber(configTable[i].hardwareAddress),
                                                  getChannelType(configTable[i].hardwareAddress),
                                                  samplePeriod,
                                                  configTable[i].channelParameter);
              return call SampleRequest.getSample(getChannelNumber(configTable[i].hardwareAddress),
                                                  getChannelType(configTable[i].hardwareAddress),
                                                  samplePeriod,
                                                  configTable[i].channelParameter);
            }

        stddbg("msrName = %d not being passed to sampler because it doesn't exist.", msrName);

        // SamplingIDs are unsigned, so returning -1 will be
        // interpretted as 255, which is a valid sampling ID.
        //return (-1);
        // Return 0 instead of -1.
        return 0;
      }
    
    command result_t DmAcceptMnAndTI.cancelSamplingID(uint8_t samplingID)
      {
        stddbg("samplingID = %d being canceled.", samplingID);
        return call SampleRequest.stop(samplingID);       
      }

    command uint8_t DmAcceptMnAndTI.availableSamplingRecords()
      {
        stddbg1("Returning remainging sampling IDs.");
        return call SampleRequest.availableSamplingRecords();
      }
      
    /***********************Utility Functions**************************/
    uint8_t getChannelNumber(uint8_t myHardwareAddress)
      {
        switch (myHardwareAddress)
          {
          case ADC0_HARDWARE_ADDRESS: return 0;
          case ADC1_HARDWARE_ADDRESS: return 1;
          case ADC2_HARDWARE_ADDRESS: return 2;
          case ADC3_HARDWARE_ADDRESS: return 3;
          case ADC4_HARDWARE_ADDRESS: return 4;
          case ADC5_HARDWARE_ADDRESS: return 5;
          case ADC6_HARDWARE_ADDRESS: return 6;
          case ADC7_HARDWARE_ADDRESS: return 7;
          case ADC8_HARDWARE_ADDRESS: return 8;
          case ADC9_HARDWARE_ADDRESS: return 9;
          case ADC10_HARDWARE_ADDRESS: return 10;
          case ADC11_HARDWARE_ADDRESS: return 11;
          case ADC12_HARDWARE_ADDRESS: return 12;
          case ADC13_HARDWARE_ADDRESS: return 13;
          case COUNTER_HARDWARE_ADDRESS: return 0;  //no significance
          case TEMP_HARDWARE_ADDRESS: return 0;     //no significance
          case HUM_HARDWARE_ADDRESS: return 0;      //no significance
          case BATTEREY_HARDWARE_ADDRESS: return 0; //no significance
          case DIG0_HARDWARE_ADDRESS: return 0;
          case DIG1_HARDWARE_ADDRESS: return 1;
          case DIG2_HARDWARE_ADDRESS: return 2;
          case DIG3_HARDWARE_ADDRESS: return 3;
          case DIG4_HARDWARE_ADDRESS: return 4;
          case DIG5_HARDWARE_ADDRESS: return 5;
          case DAQ0_HARDWARE_ADDRESS: return 0;
          case DAQ1_HARDWARE_ADDRESS: return 1;
          case DAQ2_HARDWARE_ADDRESS: return 2;
          case DAQ3_HARDWARE_ADDRESS: return 3;
          case DAQ4_HARDWARE_ADDRESS: return 4;
          case DAQ5_HARDWARE_ADDRESS: return 5;
          case DAQ6_HARDWARE_ADDRESS: return 6;
          case DAQ7_HARDWARE_ADDRESS: return 7;
          default: return 0; //should not be here
        }
      }
    
    uint8_t getChannelType(uint8_t myHardwareAddress)
      {
        switch (myHardwareAddress)
          {
          case ADC0_HARDWARE_ADDRESS:
          case ADC1_HARDWARE_ADDRESS:
          case ADC2_HARDWARE_ADDRESS:
          case ADC3_HARDWARE_ADDRESS:
          case ADC4_HARDWARE_ADDRESS:
          case ADC5_HARDWARE_ADDRESS:
          case ADC6_HARDWARE_ADDRESS:
          case ADC7_HARDWARE_ADDRESS:
          case ADC8_HARDWARE_ADDRESS:
          case ADC9_HARDWARE_ADDRESS:
          case ADC10_HARDWARE_ADDRESS:
          case ADC11_HARDWARE_ADDRESS:
          case ADC12_HARDWARE_ADDRESS:
          case ADC13_HARDWARE_ADDRESS: return ANALOG;
          case COUNTER_HARDWARE_ADDRESS: return COUNTER;
          case TEMP_HARDWARE_ADDRESS: return TEMPERATURE;
          case HUM_HARDWARE_ADDRESS: return HUMIDITY;
          case BATTEREY_HARDWARE_ADDRESS: return BATTERY;
          case DIG0_HARDWARE_ADDRESS:
          case DIG1_HARDWARE_ADDRESS:
          case DIG2_HARDWARE_ADDRESS:
          case DIG3_HARDWARE_ADDRESS:
          case DIG4_HARDWARE_ADDRESS:
          case DIG5_HARDWARE_ADDRESS: return DIGITAL;
          case DAQ0_HARDWARE_ADDRESS: 
          case DAQ1_HARDWARE_ADDRESS: 
          case DAQ2_HARDWARE_ADDRESS: 
          case DAQ3_HARDWARE_ADDRESS: 
          case DAQ4_HARDWARE_ADDRESS: 
          case DAQ5_HARDWARE_ADDRESS: 
          case DAQ6_HARDWARE_ADDRESS: 
          case DAQ7_HARDWARE_ADDRESS: 
            return DAQ;
          default: return NOT_USED;   //should not reach here
        }

      }
}
