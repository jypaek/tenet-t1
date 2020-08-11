/*
 * Interface for Node Health Monitor.  
 * Allows applications to set the way they expect the node subsystems 
 * to behave under normal operating conditions.
 * Allows applications to update their own state for this task to check 
 * if they are running correctly.
 * Enable / Disable.
 */

includes NodeHealth;

interface NodeHealthI {
  /*
   * Enable or disable the node health monitor for a subsystem
   * Note: all subsystem monitors are off by default, must be enabled
   */
  command void Enable(NodeHealthSubsystem_t subsystem,
                      NodeHealthEnable_t new_state);
  
  /*
   * Set the parameters to test a subsystem against
   * Note: this does not enable monitoring by default, you need
   * to use the enable funtion afterwards.
   */ 
  command void SetParameters(NodeHealthSubsystem_t subsystem,
                             uint32_t expected_time_complete,
                             uint32_t expected_time_between,
                             NodeHealthFlags_t flag);
  

  /*
   * Notify the node health module that a subsystem action has started
   */
  command void ActionStart(NodeHealthSubsystem_t subsystem);

  /*
   * Notify the node health module that a subsystem action has ended
   */
  command void ActionEnd(NodeHealthSubsystem_t subsystem);

  /*
   * Returns whether the subsystem is enabled or disabled
   */
  command NodeHealthEnable_t GetEnableState(NodeHealthSubsystem_t subsystem);

  /*
   * Returns the expected time between events for the subsystem
   */
  //command uint32_t GetTimeBetween(NodeHealthSubsystem_t subsystem);

  /*
   * Resets the mote immediately
   */
  command void ResetMote();
}
