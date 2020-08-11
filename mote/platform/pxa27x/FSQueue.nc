/**
 * @file FSQueue.nc
 * @author Junaith Ahemed
 */
includes PXAFlash;

interface FSQueue
{
  command result_t queueInit ();
  command result_t queueWrite (uint16_t blockID, uint16_t volId, void* data, uint32_t len);
  command result_t queueDelete (const uint8_t* filename);
  command result_t queueOpen (uint16_t volId, const uint8_t* filename);
  command result_t queueClose (uint16_t volId, const uint8_t* filename);
  command result_t queueCreate (const uint8_t* filename, uint32_t size);
  event void pendingReq (uint8_t request, void* data, PendingRequest* req);
}
