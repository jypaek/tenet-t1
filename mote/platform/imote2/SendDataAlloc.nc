/*
 * Authors:		Robbie Adler
 * Date last modified:  8/25/06
 * based on SendData.nc written by Jason Hill, David Gay, Philip Levis
 * 
 *
 */
/**
 * Interface for sending arbitrary streams of bytes based on a buffer that allocated by the module itself.
 *
 * @author Robbie Adler
 */

interface SendDataAlloc
{
  /**
   * Function to allocate a buffer that is compatible with this interface.
   *
   * @return a non-NULL pointer to a buffer that is compatible with this interface if there is memory available to allocate.  Is no memory is available, NULL will be returned

   */
  command uint8_t *alloc(size_t numBytes);

 /**
   * Function to free a buffer that was allocated by this function's alloc interface
   *
   * @return void

   */
  command void free(uint8_t *ptr);

 /**
   * Send <code>numBytes</code> of the buffer <code>data</code>.
   *
   * @return SUCCESS if send request accepted, FAIL otherwise. SUCCCES
   * means that a sendDone should be expected, FAIL means it should
   * not.  This command assumes that the pointer passed in via the packet parameter was allocated using the interface's alloc function
   */
  command result_t send(uint8_t* packet, uint32_t numBytes);

  /**
   * Send request completed. The buffer sent and whether the send was
   * successful are passed.
   *
   * @return SUCCESS always.
   */
  event result_t sendDone(uint8_t* packet, uint32_t numBytes, result_t success);
}



