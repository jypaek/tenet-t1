/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

#include "HPLUSBClient.h"

module HPLUSBClientGPIOM{
  provides interface HPLUSBClientGPIO;
}
implementation{
  
  async command result_t HPLUSBClientGPIO.init(){
    GPDR(USBC_GPION_DET) &= ~GPIO_BIT(USBC_GPION_DET); 
    
    GPDR(USBC_GPIOX_EN) |= GPIO_BIT(USBC_GPIOX_EN);
    GPSR(USBC_GPIOX_EN) |= GPIO_BIT(USBC_GPIOX_EN);
    return SUCCESS;
  }
  
  async command result_t HPLUSBClientGPIO.stop(){
    GPCR(USBC_GPIOX_EN) |= GPIO_BIT(USBC_GPIOX_EN);
    return SUCCESS;
  }
  
  async command result_t HPLUSBClientGPIO.checkConnection(){
    if(isFlagged(GPLR(USBC_GPION_DET), GPIO_BIT(USBC_GPION_DET)))
      return SUCCESS;
    else
      return FAIL;
  }
}
