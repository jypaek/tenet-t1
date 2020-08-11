// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

includes adcm1700Const;

interface ctrlStat
{
  command result_t getSums();
  event result_t getSumsDone(color16_t values, result_t status);
}
