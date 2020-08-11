#ifndef __DMA_H_
#define __DMA_H_

typedef enum
  {
    DMA_ENDINTEN = 1,
    DMA_STARTINTEN = 2,
    DMA_EORINTEN = 4,
    DMA_STOPINTEN = 8
  } DMAInterruptEnable_t;

typedef enum
  {
    DMA_8ByteBurst = 1,
    DMA_16ByteBurst,
    DMA_32ByteBurst
  } DMAMaxBurstSize_t;

typedef enum
  {
    DMA_NonPeripheralWidth = 0 ,
    DMA_1ByteWidth,
    DMA_2ByteWidth,
    DMA_4ByteWidth
  } DMATransferWidth_t;

typedef enum
  {
    DMA_Priority1 = 1 ,
    DMA_Priority2 = 2,
    DMA_Priority3 = 4,
    DMA_Priority4 = 8
  } DMAPriority_t;

typedef enum
  {
    DMAID_DREQ0 = 0,  
    DMAID_DREQ1,  
    DMAID_I2S_RX,  
    DMAID_I2S_TX,  
    DMAID_BTUART_RX,  
    DMAID_BTUART_TX,  
    DMAID_FFUART_RX,  
    DMAID_FFUART_TX,  
    DMAID_AC97_MIC,  
    DMAID_AC97_MODEMRX,  
    DMAID_AC97_MODEMTX,
    DMAID_AC97_AUDIORX,  
    DMAID_AC97_AUDIOTX,  
    DMAID_SSP1_RX,  
    DMAID_SSP1_TX,
    DMAID_SSP2_RX,  
    DMAID_SSP2_TX,  
    DMAID_ICP_RX,  
    DMAID_ICP_TX,
    DMAID_STUART_RX,  
    DMAID_STUART_TX,
    DMAID_MMC_RX,  
    DMAID_MMC_TX, 
    DMAID_USB_END0 = 24,  
    DMAID_USB_ENDA,  
    DMAID_USB_ENDB,  
    DMAID_USB_ENDC,  
    DMAID_USB_ENDD,  
    DMAID_USB_ENDE,  
    DMAID_USB_ENDF,  
    DMAID_USB_ENDG,  
    DMAID_USB_ENDH,  
    DMAID_USB_ENDI,  
    DMAID_USB_ENDJ,  
    DMAID_USB_ENDK,  
    DMAID_USB_ENDL,  
    DMAID_USB_ENDM,  
    DMAID_USB_ENDN,  
    DMAID_USB_ENDP,  
    DMAID_USB_ENDQ,  
    DMAID_USB_ENDR,  
    DMAID_USB_ENDS,  
    DMAID_USB_ENDT,  
    DMAID_USB_ENDU,  
    DMAID_USB_ENDV,  
    DMAID_USB_ENDW,  
    DMAID_USB_ENDX,  
    DMAID_MSL_RX1,  
    DMAID_MSL_TX1,  
    DMAID_MSL_RX2,  
    DMAID_MSL_TX2,  
    DMAID_MSL_RX3,  
    DMAID_MSL_TX3,  
    DMAID_MSL_RX4,  
    DMAID_MSL_TX4,  
    DMAID_MSL_RX5,  
    DMAID_MSL_TX5,  
    DMAID_MSL_RX6,  
    DMAID_MSL_TX6,  
    DMAID_MSL_RX7,  
    DMAID_MSL_TX7,  
    DMAID_USIM_RX,  
    DMAID_USIM_TX,  
    DMAID_MEMSTICK_RX,  
    DMAID_MEMSTICK_TX,  
    DMAID_SSP3_RX,  
    DMAID_SSP3_TX,
    DMAID_CIF_RX0,  
    DMAID_CIF_RX1,  
    DMAID_DREQ2  
  } DMAPeripheralID_t;

#endif //__DMA_H_
