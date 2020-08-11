// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

includes adcm1700Const;

interface ctrlExposure
{
  command result_t setExposureTime(float eTime);
  command result_t setAnalogGain(color8_t analogGain);
  command result_t setDigitalGain(color16_t digitalGain);
  event result_t setExposureTimeDone(result_t status);
  event result_t setAnalogGainDone(result_t status);
  event result_t setDigitalGainDone(result_t status);
}
