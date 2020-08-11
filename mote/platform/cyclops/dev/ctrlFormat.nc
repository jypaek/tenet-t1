// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

includes adcm1700Const;

interface ctrlFormat
{
  command result_t setFormat(uint8_t type);
  event result_t setFormatDone(result_t status);
}
