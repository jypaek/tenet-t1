/**
 * Interface for writing and erasing in flash memory
 *
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

interface Flash
{
  /**
   * Writes numBytes of the buffer data to the address in flash specified
   * by addr. This function will only set bits low for the bytes it is 
   * supposed to write to.If addr connot be written to for any reason returns
   * FAIL, otherwise returns SUCCESS.
   *
   * @returns SUCCESS or FAIL.
   */
  command result_t write(uint32_t addr, uint8_t* data, uint32_t numBytes);

  /**
   * Erases the block of flash that contains addr, setting all bits to 1.
   * If this function fails for any reason it will return FAIL, otherwise 
   * SUCCESS.
   *
   * @returns SUCCESS or FAIL.
   */
  command result_t erase(uint32_t addr);

  command result_t eraseBlk(uint32_t addr);

  /**
   * IsBlockErased
   *
   * Checks if the block is erased and returns TRUE or FALSE
   */
  command bool isBlockErased (uint32_t addr);

  /**
   * read
   * 
   * Reads data from the flash and copies to the buffer pointer passed as
   * parameter. The starting address and the size of data required must
   * be specified by the user.
   *
   * @param addr Flash address where the read starts.
   * @param data Pointer to the buffer to which the data will be copied to.
   * @param numBytes Number of bytes to read.
   * 
   * @return SUCCESS or FAIL
   */
  command result_t read(uint32_t addr, uint8_t* data, uint32_t numBytes);
}
