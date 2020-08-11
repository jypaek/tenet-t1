includes queue;

module BufferedBTUARTM {
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
#define RXLINELEN 10
#define NUMBUFFERS (4)

  ptrqueue_t outgoingQueue;

#include "BufferedUART.c"

}

  
