/**
 * @author Robbie Adler
 **/

includes mmu;
module SSP2M {
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

  #define _SSCR0 SSCR0_2
  #define _SSCR1 SSCR1_2
  #define _SSPSP SSPSP_2
  #define _SSTO SSTO_2
  #define _SSITR SSITR_2
  #define _SSSR SSSR_2
  #define _SSDR SSDR_2
  #define _SSACD SSACD_2

#define MYCKEN  (CKEN_CKEN3)
#define MYFIFOADDR (0x41700010)

#define MYSSP_RXD SSP2_RXD
#define MYSSP_RXD_ALTFN SSP2_RXD_ALTFN

#define MYSSP_TXD SSP2_TXD
#define MYSSP_TXD_ALTFN SSP2_TXD_ALTFN

#define MYSSP_SCLK SSP2_SCLK
#define MYSSP_SCLK_ALTFN SSP2_SCLK_ALTFN

#define MYSSP_SFRM SSP2_SFRM
#define MYSSP_SFRM_ALTFN SSP2_SFRM_ALTFN

#define DMAID_MYSSP_TX DMAID_SSP2_TX
#define DMAID_MYSSP_RX DMAID_SSP2_RX


  //change this value to change the default priority requst for the DMA channel
#define  DEFAULTDMARXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)
#define  DEFAULTDMATXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)

#include "SSP.c"  

}


