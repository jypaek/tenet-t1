// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 


includes adcm1700Const;

interface ctrlRun
{
  command result_t camera(uint8_t run_stop);
  event result_t cameraDone(uint8_t run_stop, result_t status);
  command result_t sensor(uint8_t run_stop);
  event result_t sensorDone(uint8_t run_stop, result_t status);
}
