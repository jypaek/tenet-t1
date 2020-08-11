#ifndef __SSP_H__
#define __SSP_H__


typedef enum 
  {
    SSP_TxFifo=0,
    SSP_RxFifo
  }SSPTestModeFIFO_t;

typedef enum
  {
    SSP_8bitCommands=0,
    SSP_16bitCommands
  }SSPMicrowireTxSize_t;

typedef enum
  {
    SSP_1cyclestart=0,
    SSP_1_2cyclestart
  }SSPSCLKPhase_t;

typedef enum
  {
    SSP_holdlow=0,
    SSP_holdhigh
  }SSPSCLKPolarity_t;

typedef enum
  {
    SSP_normalmode=0,
    SSP_networkmode
  }SSPClkMode_t;

typedef enum
  {
    SSP_SPI=0,
    SSP_SSP,
    SSP_Microwire,
    SSP_PSP
  }SSPFrameFormat_t;

typedef enum
  {
    SSP_4bits = 3,
    SSP_5bits,
    SSP_6bits,
    SSP_7bits,
    SSP_8bits,
    SSP_9bits,
    SSP_10bits,
    SSP_11bits,
    SSP_12bits,
    SSP_13bits,
    SSP_14bits,
    SSP_15bits,
    SSP_16bits,
    SSP_17bits,
    SSP_18bits,
    SSP_19bits,
    SSP_20bits,
    SSP_21bits,
    SSP_22bits,
    SSP_23bits,
    SSP_24bits,
    SSP_25bits,
    SSP_26bits,
    SSP_27bits,
    SSP_28bits,
    SSP_29bits,
    SSP_30bits,
    SSP_31bits,
    SSP_32bits
  }SSPDataWidth_t;

typedef enum
  {
    SSP_1Sample = 0,
    SSP_2Samples,
    SSP_3Samples,
    SSP_4Samples,
    SSP_5Samples,
    SSP_6Samples,
    SSP_7Samples,
    SSP_8Samples,
    SSP_9Samples,
    SSP_10Samples,
    SSP_11Samples,
    SSP_12Samples,
    SSP_13Samples,
    SSP_14Samples,
    SSP_15Samples
  }SSPFifoLevel_t;

#endif
