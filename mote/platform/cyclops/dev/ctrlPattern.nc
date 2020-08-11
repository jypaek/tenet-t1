// Authors : 
//           Rick Baer       rick_baer@agilent.com 
//           Mohammad Rahimi mhr@cens.ucla.edu 

includes adcm1700Const;

interface ctrlPattern
{
  command result_t setPattern(uint8_t myPattern);
  event result_t setPatternDone(result_t status);
}
