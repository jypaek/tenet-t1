/**
 * @author Robbie Adler
 **/

includes mmu;
module FFUARTM {
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
  
#define _RBR FFRBR	
#define	_THR FFTHR	
#define	_DLL FFDLL	
#define	_IER FFIER	
#define	_DLH FFDLH	
#define	_IIR FFIIR	
#define	_FCR FFFCR
#define	_LCR FFLCR
#define	_MCR FFMCR
#define	_LSR FFLSR
#define	_MSR FFMSR
#define	_SPR FFSPR
#define	_ISR FFISR
#define	_FOR FFFOR
#define	_ABR FFABR
#define	_ACR FFACR

#define FF_UART
  
  //change this value to change the default priority requst for the DMA channel
#define  DEFAULTDMARXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)
#define  DEFAULTDMATXPRIORITY (DMA_Priority1|DMA_Priority2|DMA_Priority3|DMA_Priority4)

  #include "UART.c"
 
 }


