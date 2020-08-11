// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 

includes adcm1700Const;

interface ctrlPatch
{
  command result_t setPatch();
  event result_t setPatchDone(result_t status);
}
