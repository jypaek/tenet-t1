/**
 * @author Robbie Adler
 **/

includes mmu;
module SSP1M {
  provides {
    interface BulkTxRx;
    interface SSP;
  }	
  uses {
    interface PXA27XDMAChannel as RxDMAChannel;
    interface PXA27XDMAChannel as TxDMAChannel;
    interface PXA27XInterrupt as SSPInterrupt;
  }
}

implementation {

  #define _SSCR0 SSCR0_1
  #define _SSCR1 SSCR1_1
  #define _SSPSP SSPSP_1
  #define _SSTO SSTO_1
  #define _SSITR SSITR_1
  #define _SSSR SSSR_1
  #define _SSDR SSDR_1
  #define _SSACD SSACD_1

#define MYCKEN  (CKEN_CKEN23)
#define MYFIFOADDR (0x41000010)

#define MYSSP_RXD SSP1_RXD
#define MYSSP_RXD_ALTFN SSP1_RXD_ALTFN

#define MYSSP_TXD SSP1_TXD
#define MYSSP_TXD_ALTFN SSP1_TXD_ALTFN

#define MYSSP_SCLK SSP1_SCLK
#define MYSSP_SCLK_ALTFN SSP1_SCLK_ALTFN

#define MYSSP_SFRM SSP1_SFRM
#define MYSSP_SFRM_ALTFN SSP1_SFRM_ALTFN

#define DMAID_MYSSP_TX DMAID_SSP1_TX
#define DMAID_MYSSP_RX DMAID_SSP1_RX

  
  //change this value to change the default priority requst for the DMA channel
#define  DEFAULTDMARXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)
#define  DEFAULTDMATXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)
 
  #include "SSP.c"
 
 }


