includes queue;
includes bufferManagement;


module BufferedSTUARTM {
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
#define NUMBUFFERS (30)

ptrqueue_t outgoingQueue __attribute__ ((C));

#include "BufferedUART.c"

}

  
