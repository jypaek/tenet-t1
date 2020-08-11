/**
 * 
 */
includes PXAFlash;
configuration FSQueueC
{
  provides interface FSQueue [volume_t volume];
}
implementation
{
  components FSQueueM;
  components HALPXA27XC;

  FSQueue = FSQueueM;
  FSQueueM.FSQueueUtil -> HALPXA27XC;
}
