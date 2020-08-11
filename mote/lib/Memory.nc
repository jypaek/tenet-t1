/**
 * Memory Interface
 *
 * Interface to access Dynamic Memory.
 *
 * @author Ben Greenstein
 **/

interface Memory {
  async command void *malloc(size_t size);
  async command void free(void *ptr);


  command uint16_t bytesAllocated();
  command uint16_t maxBytesAllocated();
  command uint16_t ptrsAllocated();
  command uint16_t maxPtrsAllocated();
}
