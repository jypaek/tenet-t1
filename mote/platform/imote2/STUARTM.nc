/**
 * @author Robbie Adler
 **/

includes mmu;
module STUARTM {
  provides {
    interface BulkTxRx;
    //    interface UART;
  }	
  uses {
    interface PXA27XDMAChannel as RxDMAChannel;
    interface PXA27XDMAChannel as TxDMAChannel;
    interface StdControl as DMAControl;
    interface PXA27XInterrupt as UARTInterrupt;
  }
}

implementation {
  
#define _RBR STRBR	
#define	_THR STTHR	
#define	_DLL STDLL	
#define	_IER STIER	
#define	_DLH STDLH	
#define	_IIR STIIR	
#define	_FCR STFCR
#define	_LCR STLCR
#define	_MCR STMCR
#define	_LSR STLSR
#define	_MSR STMSR
#define	_SPR STSPR
#define	_ISR STISR
#define	_FOR STFOR
#define	_ABR STABR
#define	_ACR STACR
  
#define ST_UART
  
  //change this value to change the default priority requst for the DMA channel
#define  DEFAULTDMARXPRIORITY (DMA_Priority4)
#define  DEFAULTDMATXPRIORITY (DMA_Priority4)

#include "UART.c"
  
}


