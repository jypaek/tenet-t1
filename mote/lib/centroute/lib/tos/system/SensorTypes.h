#ifndef SENSORTYPES_H
#define SENSORTYPES_H

enum moo
{
  sensor_unknown = 1,
  sensor_mpxa6115a, 
  sensor_windSpeedDavis,
  sensor_windSpeedCsMett034B,
  sensor_windDirectionDavis,
  sensor_windDirectionCsMett034B,
  sensor_echo20_2_5V,
  sensor_echo10_2_5V,
  sensor_echo20_5V,
  sensor_echo10_5V,
  sensor_parCurrent,
  sensor_adcVoltage,
  sensor_instAmpVoltage,
  sensor_thermopile,
  sensor_irTemperatureMelexisMlx90601KzaBka,
  sensor_humirelHm1500_3_3V,
  sensor_humirelHm1500_5V,
  sensor_temperatureBcThermistor,
  sensor_leafWetnessDavis,
  sensor_rainGaugeDavis,
  sensor_sht15_humidity,
  sensor_sht15_temperature,

  // Added for Nims
  sensor_parL11905A, //Outdoor, vertical node
  sensor_parNT53373, //Indoor, sensor strands
  sensor_parNT53373_2, //Indoor sensor strands
  sensor_thermister,
  sensor_humidity_1500_33_JR,
  sensor_thermistor_NTC_25_JR
};

#endif
