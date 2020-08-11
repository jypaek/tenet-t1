includes queue;
includes bufferManagement;

module BufferedFFUARTM {
  provides {
    interface StdControl;
    interface SendData;
    interface SendDataAlloc;
    interface ReceiveData;
  }
  uses {
    interface BulkTxRx;
  }
}


implementation
{
#define RXLINELEN 32
#define NUMBUFFERS (30)

  ptrqueue_t outgoingQueue;
  
#include "BufferedUART.c"

}

  
