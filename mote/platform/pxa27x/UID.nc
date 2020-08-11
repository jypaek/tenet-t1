  /* 
   * Author:	Josh Herbach
   * Revision:	1.0
   * Date:		09/02/2005
   */


  /*
   *
   * Routine to abstract retreiving the device's Unique Identifier
   *
   */

interface UID{
  /*
   *
   * @returns UID
   */

  async command uint32_t getUID();
}
