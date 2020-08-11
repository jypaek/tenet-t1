#ifndef UTILITY_H
#define UTILITY_H

#include "sensorboard.h"
#include "ConfigConst.h"


/****************************definitions and data structures***********************/
#define NUMBER_TEST_RECORDS 24
#define SENSOR_TYPE_NOT_DEFINED 0
#define INVALID_SAMPLER_ID -1
#define EEPROM_RUN_NUMBER_LOCATION 200
    struct testRecord {
      uint8_t hardwareAddress;
      uint8_t measurementName;
      uint8_t sensorType;
      uint8_t channelParameter;
      int8_t SamplerID;
    }myTestRecord[NUMBER_TEST_RECORDS];

    enum {
      mnADC0=0,mnADC1=1,mnADC2,mnADC3,mnADC4,mnADC5,mnADC6,mnADC7,mnADC8,mnADC9,mnADC10,
      mnADC11,mnADC12,mnADC13=13,mnCOUNTER=14,mnTEMP=15,mnHUM=16,mnBATTEREY=17,mnDIG0=18,
      mnDIG1=19,mnDIG2=20,mnDIG3=21,mnDIG4=22,mnDIG5=23,mnError
    };


/********************************function definitions*****************************/
result_t SamplerEventByName(int8_t myRecord,uint16_t data);
result_t SamplerEventByChannel(uint8_t channel,uint8_t channelType,uint16_t data);
result_t SamplerEventBySamplerID(uint8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data);

result_t startByMeasurementName();
result_t startSameMeasurementName();
result_t startByChannel();
void fillup_dataMap_directly_for_test();
void fillup_records();
void run_config_test_function();

/**************************Filling up Test Records***********************************/
void fillup_records()
{
  myTestRecord[0].measurementName=mnADC0;
  myTestRecord[0].hardwareAddress=ADC0_HARDWARE_ADDRESS;
  myTestRecord[0].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[0].channelParameter= EXCITATION_25 |EXCITATION_33 | EXCITATION_50;
  myTestRecord[0].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[1].measurementName=mnADC1;
  myTestRecord[1].hardwareAddress=ADC1_HARDWARE_ADDRESS;
  myTestRecord[1].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[1].channelParameter= SAMPLER_DEFAULT;
  myTestRecord[1].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[2].measurementName=mnADC2;
  myTestRecord[2].hardwareAddress=ADC2_HARDWARE_ADDRESS;
  myTestRecord[2].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[2].channelParameter=  SAMPLER_DEFAULT; 
  myTestRecord[2].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[3].measurementName=mnADC3;
  myTestRecord[3].hardwareAddress=ADC3_HARDWARE_ADDRESS;
  myTestRecord[3].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[3].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[3].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[4].measurementName=mnADC4;
  myTestRecord[4].hardwareAddress=ADC4_HARDWARE_ADDRESS;
  myTestRecord[4].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[4].channelParameter= SAMPLER_DEFAULT;
  myTestRecord[4].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[5].measurementName=mnADC5;
  myTestRecord[5].hardwareAddress=ADC5_HARDWARE_ADDRESS;
  myTestRecord[5].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[5].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[5].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[6].measurementName=mnADC6;
  myTestRecord[6].hardwareAddress=ADC6_HARDWARE_ADDRESS;
  myTestRecord[6].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[6].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[6].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[7].measurementName=mnADC7;
  myTestRecord[7].hardwareAddress=ADC7_HARDWARE_ADDRESS;
  myTestRecord[7].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[7].channelParameter= AVERAGE_FOUR | EXCITATION_25;
  myTestRecord[7].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[8].measurementName=mnADC8;
  myTestRecord[8].hardwareAddress=ADC8_HARDWARE_ADDRESS;
  myTestRecord[8].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[8].channelParameter= AVERAGE_FOUR | EXCITATION_25;
  myTestRecord[8].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[9].measurementName=mnADC9;
  myTestRecord[9].hardwareAddress=ADC9_HARDWARE_ADDRESS;
  myTestRecord[9].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[9].channelParameter= AVERAGE_FOUR | EXCITATION_25;
  myTestRecord[9].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[10].measurementName=mnADC10;
  myTestRecord[10].hardwareAddress=ADC10_HARDWARE_ADDRESS;
  myTestRecord[10].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[10].channelParameter= AVERAGE_FOUR | EXCITATION_25;
  myTestRecord[10].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[11].measurementName=mnADC11;
  myTestRecord[11].hardwareAddress=ADC11_HARDWARE_ADDRESS;
  myTestRecord[11].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[11].channelParameter= SAMPLER_DEFAULT;
  myTestRecord[11].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[12].measurementName= mnADC12;
  myTestRecord[12].hardwareAddress= ADC12_HARDWARE_ADDRESS;
  myTestRecord[12].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[12].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[12].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[13].measurementName= mnADC13;
  myTestRecord[13].hardwareAddress= ADC13_HARDWARE_ADDRESS;
  myTestRecord[13].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[13].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[13].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[14].measurementName= mnCOUNTER;
  myTestRecord[14].hardwareAddress= COUNTER_HARDWARE_ADDRESS;
  myTestRecord[14].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[14].channelParameter= RESET_ZERO_AFTER_READ | RISING_EDGE;
  myTestRecord[14].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[15].measurementName= mnTEMP;
  myTestRecord[15].hardwareAddress= TEMP_HARDWARE_ADDRESS;
  myTestRecord[15].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[15].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[15].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[16].measurementName= mnHUM;
  myTestRecord[16].hardwareAddress= HUM_HARDWARE_ADDRESS;
  myTestRecord[16].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[16].channelParameter= SAMPLER_DEFAULT; 
  myTestRecord[16].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[17].measurementName= mnBATTEREY;
  myTestRecord[17].hardwareAddress= BATTEREY_HARDWARE_ADDRESS;
  myTestRecord[17].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[17].channelParameter= SAMPLER_DEFAULT;
  myTestRecord[17].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[18].measurementName= mnDIG0;
  myTestRecord[18].hardwareAddress= DIG0_HARDWARE_ADDRESS;
  myTestRecord[18].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[18].channelParameter= RESET_ZERO_AFTER_READ | FALLING_EDGE;  
  myTestRecord[18].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[19].measurementName= mnDIG1;
  myTestRecord[19].hardwareAddress= DIG1_HARDWARE_ADDRESS;
  myTestRecord[19].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[19].channelParameter= RISING_EDGE | EVENT;
  myTestRecord[19].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[20].measurementName= mnDIG2;
  myTestRecord[20].hardwareAddress= DIG2_HARDWARE_ADDRESS;
  myTestRecord[20].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[20].channelParameter= SAMPLER_DEFAULT | EVENT;
  myTestRecord[20].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[21].measurementName= mnDIG3;
  myTestRecord[21].hardwareAddress= DIG3_HARDWARE_ADDRESS;
  myTestRecord[21].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[21].channelParameter= FALLING_EDGE;
  myTestRecord[21].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[22].measurementName= mnDIG4;
  myTestRecord[22].hardwareAddress= DIG4_HARDWARE_ADDRESS;
  myTestRecord[22].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[22].channelParameter= RISING_EDGE;
  myTestRecord[22].SamplerID = INVALID_SAMPLER_ID;

  myTestRecord[23].measurementName= mnDIG5;
  myTestRecord[23].hardwareAddress= DIG5_HARDWARE_ADDRESS;
  myTestRecord[23].sensorType=SENSOR_TYPE_NOT_DEFINED;
  myTestRecord[23].channelParameter= RISING_EDGE;  
  myTestRecord[23].SamplerID = INVALID_SAMPLER_ID;
}

/***************************SamplerID to Measurement Name Conversion*********************/
uint8_t get_measurement_name(int8_t mySamplerID)
{
  int i;
  for(i=0;i<NUMBER_TEST_RECORDS;i++)
    if(myTestRecord[i].SamplerID==mySamplerID)
      return myTestRecord[i].measurementName;
  return mnError;
}

/*****************************Stop Utilities*********************************************/

void stop_analog_measurement_records()
{
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[0].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[1].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[2].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[3].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[4].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[5].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[6].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[7].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[8].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[9].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[10].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[11].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[12].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[13].SamplerID);
}

void stop_miscelanous_measurement_records()
{
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[14].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[15].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[16].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[17].SamplerID);
}

void stop_digital_measurement_records()
{
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[18].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[19].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[20].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[21].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[22].SamplerID);
  call DmAcceptMnAndTI.cancelSamplingID(myTestRecord[23].SamplerID);
}

/******************testing DataMap and Samplerfor Remaining SamplerID function************/
void test_DataMap_Remaining_SamplerID_Function()
{
  if(call DmAcceptMnAndTI.availableSamplingRecords() == MAX_SAMPLERECORD-24) //since we star 24 record
    {
      call Leds.greenOn();
    }
  
  stop_analog_measurement_records();
  stop_miscelanous_measurement_records();
  stop_digital_measurement_records();
  /*
  if(call DmAcceptMnAndTI.avilableSamplingRecords() == MAX_SAMPLERECORD) 
    {
      call Leds.redOn();
    }
  */
}

/*************************testing eeprom functionality*************************************/
#define ANALOG_BUFFER_LENGHT 14*4+1
#define MISC_BUFFER_LENGHT 4*4+1
#define DIGITAL_BUFFER_LENGHT 6*4+1

void run_config_test_function()
{
  char analogConfigBuf[ANALOG_BUFFER_LENGHT];
  char miscConfigBuf[MISC_BUFFER_LENGHT];
  char digitalConfigBuf[DIGITAL_BUFFER_LENGHT];
  
  fillup_records();

  //filling up analog buffer.
  analogConfigBuf[0]=CONFIG_PUT_COMMAND;
  
  analogConfigBuf[1]=ADC0_HARDWARE_ADDRESS;
  analogConfigBuf[2]=mnADC0;
  analogConfigBuf[3]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[4]= EXCITATION_25 |EXCITATION_33 | EXCITATION_50;
  
  analogConfigBuf[5]=ADC1_HARDWARE_ADDRESS;
  analogConfigBuf[6]=mnADC1;
  analogConfigBuf[7]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[8]= SAMPLER_DEFAULT;
  
  analogConfigBuf[9]=ADC2_HARDWARE_ADDRESS;
  analogConfigBuf[10]=mnADC2;
  analogConfigBuf[11]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[12]=  SAMPLER_DEFAULT; 
  
  analogConfigBuf[13]=ADC3_HARDWARE_ADDRESS;
  analogConfigBuf[14]=mnADC3;
  analogConfigBuf[15]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[16]= SAMPLER_DEFAULT; 
  
  analogConfigBuf[17]=ADC4_HARDWARE_ADDRESS;
  analogConfigBuf[18]=mnADC4;
  analogConfigBuf[19]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[20]= SAMPLER_DEFAULT;
  
  analogConfigBuf[21]=ADC5_HARDWARE_ADDRESS;
  analogConfigBuf[22]=mnADC5;
  analogConfigBuf[23]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[24]= SAMPLER_DEFAULT; 

  analogConfigBuf[25]=ADC6_HARDWARE_ADDRESS;
  analogConfigBuf[26]=mnADC6;
  analogConfigBuf[27]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[28]= SAMPLER_DEFAULT; 

  analogConfigBuf[29]=ADC7_HARDWARE_ADDRESS;
  analogConfigBuf[30]=mnADC7;
  analogConfigBuf[31]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[32]= AVERAGE_FOUR | EXCITATION_25;

  analogConfigBuf[33]=ADC8_HARDWARE_ADDRESS;
  analogConfigBuf[34]=mnADC8;
  analogConfigBuf[35]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[36]= AVERAGE_FOUR | EXCITATION_25;

  analogConfigBuf[37]=ADC9_HARDWARE_ADDRESS;
  analogConfigBuf[38]=mnADC9;
  analogConfigBuf[39]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[40]= AVERAGE_FOUR | EXCITATION_25;

  analogConfigBuf[41]=ADC10_HARDWARE_ADDRESS;
  analogConfigBuf[42]=mnADC10;
  analogConfigBuf[43]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[44]= AVERAGE_FOUR | EXCITATION_25;

  analogConfigBuf[45]=ADC11_HARDWARE_ADDRESS;
  analogConfigBuf[46]=mnADC11;
  analogConfigBuf[47]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[48]= SAMPLER_DEFAULT;

  analogConfigBuf[49]= ADC12_HARDWARE_ADDRESS;
  analogConfigBuf[50]= mnADC12;
  analogConfigBuf[51]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[52]= SAMPLER_DEFAULT; 

  analogConfigBuf[53]= ADC13_HARDWARE_ADDRESS;
  analogConfigBuf[54]= mnADC13;
  analogConfigBuf[55]=SENSOR_TYPE_NOT_DEFINED;
  analogConfigBuf[56]= SAMPLER_DEFAULT; 

  //actual call for analog buffer.
  call ChAcceptCmdI.acceptCmd(analogConfigBuf,ANALOG_BUFFER_LENGHT);

  //filling up misc buffer.
  miscConfigBuf[0]=CONFIG_PUT_COMMAND;

  miscConfigBuf[1]= COUNTER_HARDWARE_ADDRESS;
  miscConfigBuf[2]= mnCOUNTER;
  miscConfigBuf[3]= SENSOR_TYPE_NOT_DEFINED;
  miscConfigBuf[4]= RESET_ZERO_AFTER_READ | RISING_EDGE;

  miscConfigBuf[5]= TEMP_HARDWARE_ADDRESS;
  miscConfigBuf[6]= mnTEMP;
  miscConfigBuf[7]=SENSOR_TYPE_NOT_DEFINED;
  miscConfigBuf[8]= SAMPLER_DEFAULT; 

  miscConfigBuf[9]= HUM_HARDWARE_ADDRESS;
  miscConfigBuf[10]= mnHUM;
  miscConfigBuf[11]=SENSOR_TYPE_NOT_DEFINED;
  miscConfigBuf[12]= SAMPLER_DEFAULT; 

  miscConfigBuf[13]= BATTEREY_HARDWARE_ADDRESS;
  miscConfigBuf[14]= mnBATTEREY;
  miscConfigBuf[15]=SENSOR_TYPE_NOT_DEFINED;
  miscConfigBuf[16]= SAMPLER_DEFAULT;

  //actual call for misc buffer.
  call ChAcceptCmdI.acceptCmd(miscConfigBuf,MISC_BUFFER_LENGHT);

  //filling up digital buffer.
  digitalConfigBuf[0]=CONFIG_PUT_COMMAND;

  digitalConfigBuf[1]= DIG0_HARDWARE_ADDRESS;
  digitalConfigBuf[2]= mnDIG0;
  digitalConfigBuf[3]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[4]= RESET_ZERO_AFTER_READ | FALLING_EDGE;  

  digitalConfigBuf[5]= DIG1_HARDWARE_ADDRESS;
  digitalConfigBuf[6]= mnDIG1;
  digitalConfigBuf[7]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[8]= RISING_EDGE | EVENT;

  digitalConfigBuf[9]= DIG2_HARDWARE_ADDRESS;
  digitalConfigBuf[10]= mnDIG2;
  digitalConfigBuf[11]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[12]= SAMPLER_DEFAULT | EVENT;

  digitalConfigBuf[13]= DIG3_HARDWARE_ADDRESS;
  digitalConfigBuf[14]= mnDIG3;
  digitalConfigBuf[15]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[16]= FALLING_EDGE;

  digitalConfigBuf[17]= DIG4_HARDWARE_ADDRESS;
  digitalConfigBuf[18]= mnDIG4;
  digitalConfigBuf[19]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[20]= RISING_EDGE;

  digitalConfigBuf[21]= DIG5_HARDWARE_ADDRESS;
  digitalConfigBuf[22]= mnDIG5;
  digitalConfigBuf[23]=SENSOR_TYPE_NOT_DEFINED;
  digitalConfigBuf[24]= RISING_EDGE;  

  //actual call for misc buffer.
  call ChAcceptCmdI.acceptCmd(digitalConfigBuf,DIGITAL_BUFFER_LENGHT);

}

/*************************testing eeprom removal functionality**********************/
#define ERASE_BUFFER_LENGHT 1+18

void run_config_erase_function()
{
  char ConfigEraseBuf[ERASE_BUFFER_LENGHT];
  
  /*Removing some of the measurement names.
    mnADC0,mnADC1,mnADC2,mnADC3,mnADC4,mnADC5,mnADC6,mnADC7,mnADC8,mnADC9,mnADC10,
    mnADC11,mnADC12,mnADC13,mnCOUNTER,mnTEMP,mnHUM,mnBATTEREY,mnDIG0,
    mnDIG1,mnDIG2,mnDIG3,mnDIG4,mnDIG5*/

  ConfigEraseBuf[0]=CONFIG_ERASE_COMMAND;
  ConfigEraseBuf[1]=mnADC13;

  //filling up analog buffer.
  ConfigEraseBuf[0]=CONFIG_ERASE_COMMAND;
  ConfigEraseBuf[1]=mnADC0; //mnDIG0;
  ConfigEraseBuf[2]=mnADC1;
  ConfigEraseBuf[3]=mnADC2;
  ConfigEraseBuf[4]=mnADC3;
  ConfigEraseBuf[5]=mnADC4;
  ConfigEraseBuf[6]=mnADC5;
  ConfigEraseBuf[7]=mnADC6;
  ConfigEraseBuf[8]=mnADC7;
  ConfigEraseBuf[9]=mnADC8;
  ConfigEraseBuf[10]=mnADC9;
  ConfigEraseBuf[11]=mnADC10;
  ConfigEraseBuf[12]=mnADC11;
  ConfigEraseBuf[13]=mnADC12;
  ConfigEraseBuf[14]=mnADC13;
  ConfigEraseBuf[15]=mnCOUNTER;
  ConfigEraseBuf[16]=mnTEMP;
  ConfigEraseBuf[17]=mnHUM;
  ConfigEraseBuf[18]=mnBATTEREY;
  
  //actual call from removal.
  call ChAcceptCmdI.acceptCmd(ConfigEraseBuf,ERASE_BUFFER_LENGHT);
}

/*************************testing eeprom removal functionality**********************/
void run_config_get_function()
{
  char ConfigEraseBuf[2];
  
  ConfigEraseBuf[0]=CONFIG_GET_COMMAND;
  ConfigEraseBuf[1]= mnADC0; //mnBATTEREY; //mnDIG1;

  //actual call from removal.
  call ChAcceptCmdI.acceptCmd(ConfigEraseBuf,2);
}

#endif

