/*
 * Interface for Reset Counter.  Basic functionality is to return the number of times the
 * mote has been reset, and a call to reset this counter to zero.
 */

interface ResetCountI {
  /*
   * Return the current count in memory (0 if no count or error).
   */
  command uint16_t get_count();
  
  /*
   * Reset the current count to 0 (both in memory and in flash).
   */ 
  command result_t reset();
}
