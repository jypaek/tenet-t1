/**
 * @author Robbie Adler
 **/

includes mmu;
module BTUARTM {
  provides {
    interface BulkTxRx;
    //    interface UART;
  }	
  uses {
    interface PXA27XDMAChannel as RxDMAChannel;
    interface PXA27XDMAChannel as TxDMAChannel;
    interface PXA27XInterrupt as UARTInterrupt;
  }
}

implementation {
  
#define _RBR BTRBR	
#define	_THR BTTHR	
#define	_DLL BTDLL	
#define	_IER BTIER	
#define	_DLH BTDLH	
#define	_IIR BTIIR	
#define	_FCR BTFCR
#define	_LCR BTLCR
#define	_MCR BTMCR
#define	_LSR BTLSR
#define	_MSR BTMSR
#define	_SPR BTSPR
#define	_ISR BTISR
#define	_FOR BTFOR
#define	_ABR BTABR
#define	_ACR BTACR

#define BT_UART
  
  //change this value to change the default priority requst for the DMA channel
#define  DEFAULTDMARXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)
#define  DEFAULTDMATXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)

#define NO_DMA
 
  #include "UART.c"
 
 }


