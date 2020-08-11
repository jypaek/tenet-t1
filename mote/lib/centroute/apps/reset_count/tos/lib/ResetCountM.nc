includes ResetCount;
includes avr_eeprom;

module ResetCountM {
  provides {
    interface StdControl;
    interface ResetCountI;
  }
  uses {
    interface Leds;
  }
}
implementation {
#include "ResetCount.h"


  // Eeprom entry on the eeprom                                                       
  static reset_entry_t eeprom_entry __attribute__((section(".eeprom")));

  // Stores the eeprom entry in memory.                                                   
  reset_entry_t my_entry;

  /*********************************************************************
   * Functions
   *********************************************************************/
  
  result_t load_count() {
    // Load the reset counter page from flash into memory.  
    my_entry.key = eeprom_read_byte(&(eeprom_entry.key));
    my_entry.reset_count = eeprom_read_byte(&(eeprom_entry.reset_count));

    // Check its validity.  If valid, update count in memory and in flash.  If
    // ..invalid, set to zero in memory and flash.
    if (my_entry.key == UNIQUE_KEY) {
      my_entry.reset_count++;
    }
    else {
      my_entry.key = UNIQUE_KEY;
      my_entry.reset_count = 0;
    }

    // Write it back to flash.
    eeprom_write_byte(&(eeprom_entry.key), my_entry.key);
    eeprom_write_byte(&(eeprom_entry.reset_count), my_entry.reset_count);

    return SUCCESS;
  }

  /*********************************************************************
   * StdControl Interface
   *********************************************************************/
  command result_t StdControl.init() {
    return SUCCESS;
  }
  
  command result_t StdControl.start() {
    // Load the current count from flash.  As we will increment the flash,
    // ..this function should only be called once per boot.
    if (load_count() == FAIL)
      return FAIL;
    
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

  /*********************************************************************
   * Interface calls
   *********************************************************************/

  /*
   * Simply return the count stored in memory.
   */
  command uint16_t ResetCountI.get_count() {
    return my_entry.reset_count;
  }

  /*
   * Resets the count both in memory and in flash.  Added in case a user needs
   * to remotely reset the mote count, but you can also reset just be erasing
   * the flash.
   */
  command result_t ResetCountI.reset() {
    // Reset to 0.
    my_entry.key = UNIQUE_KEY;
    my_entry.reset_count = 0;

    // Write to flash.
    eeprom_write_byte(&(eeprom_entry.key), my_entry.key);
    eeprom_write_byte(&(eeprom_entry.reset_count), my_entry.reset_count);

    return SUCCESS;
  }

}
