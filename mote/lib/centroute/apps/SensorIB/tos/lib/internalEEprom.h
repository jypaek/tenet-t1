#ifndef INTERNALEEPROM_H
#define INTERNALEEPROM_H

static sensorConfig_eprom_t epromRecords[NUMBER_OF_HARDWARE_ADDRESSES]  __attribute__((section(".eeprom")));  

  sensorConfig_eprom_t eepromRead(int myAddress)
    {
      sensorConfig_eprom_t myRecord;
      myRecord.sensorConfig.hardwareAddress = 
        eeprom_read_byte(&(epromRecords[myAddress].sensorConfig.hardwareAddress));
      myRecord.sensorConfig.measurementName = 
        eeprom_read_byte(&(epromRecords[myAddress].sensorConfig.measurementName)); 
      myRecord.sensorConfig.sensorType = 
        eeprom_read_byte(&(epromRecords[myAddress].sensorConfig.sensorType)); 
      myRecord.sensorConfig.channelParameter = 
        eeprom_read_byte(&(epromRecords[myAddress].sensorConfig.channelParameter));
      myRecord.sensor_Attached_Flag = 
        eeprom_read_byte(&(epromRecords[myAddress].sensor_Attached_Flag)); 
      return myRecord;
    }

  result_t eepromWrite(sensorConfig_eprom_t myRecord)
    {
      uint8_t myIndex;
      myIndex = myRecord.sensorConfig.hardwareAddress;
      eeprom_write_byte(&(epromRecords[myIndex].sensorConfig.hardwareAddress),myRecord.sensorConfig.hardwareAddress); 
      eeprom_write_byte(&(epromRecords[myIndex].sensorConfig.measurementName),myRecord.sensorConfig.measurementName);
      eeprom_write_byte(&(epromRecords[myIndex].sensorConfig.sensorType),myRecord.sensorConfig.sensorType);
      eeprom_write_byte(&(epromRecords[myIndex].sensorConfig.channelParameter),myRecord.sensorConfig.channelParameter);
      eeprom_write_byte(&(epromRecords[myIndex].sensor_Attached_Flag),myRecord.sensor_Attached_Flag);
      return SUCCESS;
    }

  result_t eepromErasemyMeasurementName(uint8_t myMeasurementName)
    {
      uint8_t i;
      for( i=0; i < NUMBER_OF_HARDWARE_ADDRESSES ; i++)
        {
          if(eeprom_read_byte(&(epromRecords[i].sensorConfig.measurementName))== myMeasurementName)
            eeprom_write_byte(&(epromRecords[i].sensor_Attached_Flag),INVALID_SENSOR_RECORD);
        }
      return SUCCESS;
    }

sensorConfig_eprom_t eepromGetMeasurementName(uint8_t myMeasurementName)
{
  uint8_t i;
  sensorConfig_eprom_t myRecord;
  
  //setting void in the return if in the loop nothing found.
  myRecord.sensorConfig.measurementName = myMeasurementName;
  myRecord.sensorConfig.channelParameter = 0x00;
  myRecord.sensorConfig.sensorType = 0x00;
  myRecord.sensorConfig.hardwareAddress =  NO_HARDWARE_ADDRESS;
  myRecord.sensor_Attached_Flag = INVALID_SENSOR_RECORD;

  for( i=0; i < NUMBER_OF_HARDWARE_ADDRESSES ; i++)    {
    if( ((eeprom_read_byte(&(epromRecords[i].sensorConfig.measurementName)))== myMeasurementName) &
        ((eeprom_read_byte(&(epromRecords[i].sensor_Attached_Flag))==VALID_SENSOR_RECORD)))
      {
        myRecord.sensorConfig.hardwareAddress = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.hardwareAddress));
        myRecord.sensorConfig.measurementName = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.measurementName)); 
        myRecord.sensorConfig.sensorType = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.sensorType)); 
        myRecord.sensorConfig.channelParameter = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.channelParameter));
        myRecord.sensor_Attached_Flag = 
          eeprom_read_byte(&(epromRecords[i].sensor_Attached_Flag)); 
        return myRecord;
      }
  }
  return myRecord;
}

sensorConfig_eprom_t eepromGetHardwareAddress(uint8_t hardwareAddress)
{
  uint8_t i = hardwareAddress;
  sensorConfig_eprom_t myRecord;
  
  //setting void in the return if in the loop nothing found.
  myRecord.sensorConfig.measurementName = 0;
  myRecord.sensorConfig.channelParameter = 0x00;
  myRecord.sensorConfig.sensorType = 0x00;
  myRecord.sensorConfig.hardwareAddress =  hardwareAddress;
  myRecord.sensor_Attached_Flag = INVALID_SENSOR_RECORD;

  if( eeprom_read_byte(&(epromRecords[i].sensor_Attached_Flag))==VALID_SENSOR_RECORD )
    {
        myRecord.sensorConfig.hardwareAddress = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.hardwareAddress));
        myRecord.sensorConfig.measurementName = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.measurementName)); 
        myRecord.sensorConfig.sensorType = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.sensorType)); 
        myRecord.sensorConfig.channelParameter = 
          eeprom_read_byte(&(epromRecords[i].sensorConfig.channelParameter));
        myRecord.sensor_Attached_Flag = 
          eeprom_read_byte(&(epromRecords[i].sensor_Attached_Flag)); 
    }

  return myRecord;

}
  
#endif
