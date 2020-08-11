#ifndef __I2S_H__
#define __I2S_H__

typedef enum
  {
    I2S_1Sample = 0,
    I2S_2Samples,
    I2S_3Samples,
    I2S_4Samples,
    I2S_5Samples,
    I2S_6Samples,
    I2S_7Samples,
    I2S_8Samples,
    I2S_9Samples,
    I2S_10Samples,
    I2S_11Samples,
    I2S_12Samples,
    I2S_13Samples,
    I2S_14Samples,
    I2S_15Samples,
    I2S_16Samples
  }I2SFifoLevel_t;

typedef enum
  {
    I2S_SYSCLK_12p235M = 0xC,
    I2S_SYSCLK_11p346M = 0xD,
    I2S_SYSCLK_5p622M = 0x1A,
    I2S_SYSCLK_4p105M = 0x24,
    I2S_SYSCLK_2p811M = 0x34,
    I2S_SYSCLK_2p053M = 0x48
  }I2SAudioDivider_t;

#endif
