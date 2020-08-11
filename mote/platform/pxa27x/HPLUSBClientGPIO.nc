/*
 *
 * Routines that abstract the necessary GPIO operations for USBClient
 * controllers.
 *
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

interface HPLUSBClientGPIO {

  /**
   * Initialization
   *
   * @return SUCCESS always.
   */

  async command result_t init();

  /**
   * Disable
   *
   * @return SUCCESS always.
   */

  async command result_t stop();

  /**
   * Checks whether the device is connected to a USB host
   *
   * @return SUCCESS if connected, FAIL otherwise
   */

  async command result_t checkConnection();

}
