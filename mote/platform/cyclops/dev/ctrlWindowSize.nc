//Authors:
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 


includes adcm1700Const;

interface ctrlWindowSize
{
    command result_t setInputSize (wsize_t iwsize);
    command result_t setInputPan (wpos_t iwpan);
    command result_t setOutputSize (wsize_t owsize);

    event result_t setInputSizeDone (result_t status);
    event result_t setInputPanDone (result_t status);
    event result_t setOutputSizeDone (result_t status);
}
