#ifndef MEASUREMENTNAMES_H
#define MEASUREMENTNAMES_H

enum
  {
    unknown = 32,
    humidity,
    temperature,
    dewPoint,
    windSpeed,
    solarRadiation,
    leafWetness,
    windDirection,
    barometer,
    rain,
    lightning,
    enclosureHumidity,
    gust,
    messageLossAtCH1,
    messageSent,
    hopsToCH1,
    moteBattery,
    insideTemperature,
    insideHumidity,
    parCurrent,
    insideThermopile,
    analog0,
    analog1,
    soilMoistureAt15cm,
    soilMoistureAt50cm,
    soilTemperatureAt100cm,
    soilTemperatureAt30cm,
    enclosureTemperature,
    soilTemperatureAt15cm,
    soilTemperatureAt50cm,
    analog2,
    analog3,
    analog4,
    analog5,
    analog6,
    analog7,

    // Added for Nims
    // Traditionally used for indoor par because it has more sensitivity
    // Also used for JR PAR sensor
    parL11905A = 128,
    // Traditionally used for outdoor
    parNT53373,
    parNT53373_2,
    thermister,
    humidity_1500_33_JR,
    thermistor_NTC_25_JR,

    // Added for Bangladesh
    calcium = 134,
    nitrate = 135,
    chloride = 136,
    carbonate = 137,
    pH = 138,
    ORP = 139,
    ammonium = 140,
    soilMoisture1 = 141,
    soilMoisture2 = 142,
    soilMoisture3 = 143,
    soilTemp1 = 144,
    soilTemp2 = 145,
    soilTemp3 = 146,

    // Added for connectivity transect to read car battery voltage
    carBattery = 147,
    ammonium2=148,
    nitrate2=149,
  };

#endif
