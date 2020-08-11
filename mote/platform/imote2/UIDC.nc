/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */
module UIDC {
  provides interface UID;
}

implementation {
  async command uint32_t UID.getUID(){
    return *((uint32_t *)0x01FE0000);
  }
}
