#include "MeasurementNames.h"
#include "SensorTypes.h"
#include "QueryConstants.h"

task void sensorInit()
{
  int8_t q[5];

  // These are all put commands.
  // No need to modify q[0] after this point.
  q[0] = CONFIG_PUT_COMMAND;
  q[3] = 1; // Sensor type (see SensorTypes.h)
  q[4] = 128; // Sensor parameters.  No params needed.

  q[1] = ADC11_HARDWARE_ADDRESS; 
  q[2] = ammonium; // Measurement name (see MeasurementNames.h) 
  // q[2] = nitrate; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC12_HARDWARE_ADDRESS; 
  q[2] = chloride; // Measurement name (see MeasurementNames.h) 
  // q[2] = carbonate; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC13_HARDWARE_ADDRESS; 
  q[2] = calcium; // Measurement name (see MeasurementNames.h) 
  // q[2] = pH; // Measurement name (see MeasurementNames.h) 
  // q[2] = ORP; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = TEMP_HARDWARE_ADDRESS; // Onboard temperature.
  q[2] = temperature; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_sht15_temperature; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = HUM_HARDWARE_ADDRESS; // Onboard humidity.
  q[2] = humidity; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_sht15_humidity; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = BATTEREY_HARDWARE_ADDRESS; // Onboard battery voltage.
  q[2] = moteBattery; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_unknown; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );
  return;
}

#ifdef LONELY_MOTE
task void queryInit() {
  uint8_t buf[sizeof(QueryHeader_t) + sizeof(uint8_t) * 8];
  QueryHeader_t* qh = (QueryHeader_t *)buf;

  // first query has battery data only
  qh->queryID = 1;
  qh->queryFlags = periodic_sample;
  qh->maxEpoch = 1;
  qh->samplingPeriod = 300;
  qh->mnCnt = 1;
  qh->mn[0] = 48;
  call QeAcceptQueryI.passQuery((void*)qh);
   
  // 2nd query returns other sensor data 
  qh->queryID = 2;
  qh->queryFlags = periodic_sample;
  qh->maxEpoch = 1;
  qh->samplingPeriod = 300;
  qh->mnCnt = 4;
  qh->mn[0] = 131;
  qh->mn[1] = 132;
  qh->mn[2] = 34;
  qh->mn[3] = 33;


  call QeAcceptQueryI.passQuery((void*)qh);
  return;
}
#endif

#ifdef ROUTER_MOTE
task void queryInit() {
  uint8_t buf[sizeof(QueryHeader_t) + sizeof(uint8_t) * 8];
  QueryHeader_t* qh = (QueryHeader_t *)buf;

  

  qh->queryID = 1;
  qh->queryFlags = periodic_sample;
  qh->maxEpoch = 1;
  qh->samplingPeriod = 300;
  qh->mnCnt = 1;
  qh->mn[0] = 48;
  call QeAcceptQueryI.passQuery((void*)qh);

  return;
}
#endif // ROUTER_MOTE

task void sensorInit_ISE()
{
  uint8_t q[5];

  // These are all put commands.
  // No need to modify q[0] after this point.
  q[0] = CONFIG_PUT_COMMAND;
  q[3] = 1; // Sensor type (see SensorTypes.h)
  q[4] = 128; // Sensor parameters.  No params needed.

  q[1] = ADC0_HARDWARE_ADDRESS; 
  q[2] = ammonium; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC1_HARDWARE_ADDRESS; 
  q[2] = calcium; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC2_HARDWARE_ADDRESS; 
  q[2] = nitrate; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC3_HARDWARE_ADDRESS; 
  q[2] = chloride; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC4_HARDWARE_ADDRESS; 
  q[2] = carbonate; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC5_HARDWARE_ADDRESS; 
  q[2] = pH; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = ADC6_HARDWARE_ADDRESS; 
  q[2] = ORP; // Measurement name (see MeasurementNames.h) 
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = TEMP_HARDWARE_ADDRESS; // Onboard temperature.
  q[2] = temperature; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_sht15_temperature; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = HUM_HARDWARE_ADDRESS; // Onboard humidity.
  q[2] = humidity; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_sht15_humidity; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );

  q[1] = BATTEREY_HARDWARE_ADDRESS; // Onboard battery voltage.
  q[2] = moteBattery; // Measurement name (see MeasurementNames.h) 
  q[3] = sensor_unknown; // Sensor type (see SensorTypes.h)
  q[4] = 0; // Sensor parameters.  No params needed.
  call ChAcceptCmdI.acceptCmd( q, 5 );
  return;
}

task void queryInit_ISE() {
  uint8_t buf[sizeof(QueryHeader_t) + sizeof(uint8_t) * 8];
  QueryHeader_t* qh = (QueryHeader_t *)buf;

  qh->queryID = 35;
  qh->queryFlags = periodic_sample|NOISE_WINDOW_SAMPLING;
  qh->samplingPeriod = 600;
  qh->maxEpoch = 15;
  qh->noiseWindow = 15;
  
  qh->mnCnt = 2;
  qh->mn[0] = ammonium;
  qh->mn[1] = moteBattery;

//  qh->mn[0] = calcium;
//  qh->mn[1] = nitrate;
//  qh->mn[2] = chloride;
//  qh->mn[3] = carbonate;
//  qh->mn[4] = pH;
//  qh->mn[5] = ORP;
//  qh->mn[6] = ammonium;
//  qh->mn[7] = moteBattery;
  call QeAcceptQueryI.passQuery((void*)qh);
  return;
}
