includes NodeHealth;
includes avr_eeprom;

module NodeHealthM {
  provides {
    interface StdControl;
    interface NodeHealthI;
  }
  uses {
    interface Leds;
#ifdef EMSTAR_NO_KERNEL
    interface EmTimerI as NodeHealthTimer;
#else
    interface Timer as NodeHealthTimer;
#endif
    interface EssSysTimeI;
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    interface WatchDogHWI;
#endif
  }
}
implementation {
#include "NodeHealth.h"
#include <limits.h>

// stolen from limits.h - no idea why it isn't including properly
/* Maximum value an `unsigned long long int' can hold.  (Minimum is 0.)  */
#define ULLONG_MAX	18446744073709551615ULL

// number of ms in a second
#define MS_PER_SECOND (1000)

// number of seconds in a minute
#define SECONDS_PER_MINUTE (60)

// check node health every 1 minute (by default) - 
// in units of WATCHDOG_KICK_PERIOD
#define NODE_HEALTH_TICK (SECONDS_PER_MINUTE * 1) 

// kick the watchdog every period
// NOTE: make sure this is in sync with the prescaler bits set in
// WatchDogM.nc
//#define WATCHDOG_KICK_PERIOD (10)
#define WATCHDOG_KICK_PERIOD (MS_PER_SECOND)

// since we allow applications to update their parameters while we
// are checking their health, if the last updated time is greater than
// the current time by a value less than this delta, it has been updated
// while the node health task is running, and hence the task is healthy
// in units of ms
#define NODE_HEALTH_DELTA (10 * MS_PER_SECOND)

#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
// on hardware, we stop kicking the watchdog, which will cause
// a reboot next time it expires
#define NETPROG_ACTUAL_REBOOT()  while(1);
#else
// can't really reboot a node using emstar
#define NETPROG_ACTUAL_REBOOT() 
#endif

// applications report honestly how long they think they will take to
// perform operations, the module allows a certain multiplier to allow
// applications to take some amount of time more than expected to do
// their tasks
#define NODE_HEALTH_SLACK 2

  typedef struct _subsystemParameters_t
  {
      // whether health checking for this module is enabled
      NodeHealthEnable_t enable_status;
      // expected time for this subsystem to complete a task
      uint64_t expected_time_complete;
      // expected time between when this subsystem will complete
      // consecutive tasks
      uint64_t expected_time_between;
      // set to true if this subsystem is currently processing an event,
      // 0 otherwise
      int in_progress;
      // the last time this subsystem started processing an event
      uint64_t last_time_started;
      // flags to modify behaviour
      int flag;
      // count of number of failures of this module
      int failure_count;
  } subsystemParameters_t;

  typedef enum _failureReason_t
  {
      FAIL_STUCK,
      FAIL_NOT_RUNNING
  } failureReason_t;

  // to store paramters for all subsystems that could be monitored
  static subsystemParameters_t parameters[MAX_SUBSYSTEM_COUNT]; 

  // Eeprom entry on the eeprom             
  //static reset_entry_t eeprom_entry __attribute__((section(".eeprom")));

  // count of how many times we have kicked the watchdog before we
  // need to check for task failure
  // need to kick the watchdog much more frequently than we need to 
  // check for failure
  static int watchdog_kick_count;


  /*********************************************************************
   * Functions
   *********************************************************************/
  
  uint64_t Get64Difference(uint64_t val_high, uint64_t val_low)
  {
    if ((val_low >= val_high) && 
        (val_low - val_high < NODE_HEALTH_DELTA)) 
    {
      // the subsystem has been updated as we run, no problems
      return 0;
    }
    else if (val_high > val_low)
    {
      // usual case
      return val_high - val_low;
    }
    else
    {
      // timer has overflowed
      return ((ULLONG_MAX - val_low) + val_high);
    } 

  }
  
  void HealthCheckFailed(uint64_t current_time, uint64_t difference,
                         uint64_t expected_difference, 
                         NodeHealthSubsystem_t subsystem, 
                         failureReason_t reason, subsystemParameters_t *param)
  {
    param->failure_count++;

    dbg(DBG_ERROR, "NODE PANIC - Health check failed at time %llu: Subsystem %d, %llu ms since last action, Expected time since last action %llu ms, Reason %d, Failure Count %d\n",
        current_time, subsystem, difference, expected_difference, reason,
        param->failure_count); 

    // should write this information to the on-chip eeprom here


    // restart the mote
    NETPROG_ACTUAL_REBOOT();
  }


  /*********************************************************************
   * StdControl Interface
   *********************************************************************/
  command result_t StdControl.init() {
    // clear out the array of parameters
    memset(&parameters, 0, sizeof(parameters));
    watchdog_kick_count = 0;
    dbg(DBG_ERROR, "Starting Node Health Task!\n");
    return SUCCESS;
  }
  
  command result_t StdControl.start() {
    // start the timer to kick the watchdog, and periodically
    // check node health
    call NodeHealthTimer.start(TIMER_REPEAT, WATCHDOG_KICK_PERIOD);
    
    // enable the watchdog
    // NOTE: for mica2 we don't provide a timeout here
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    call WatchDogHWI.set();
#endif
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

  /*********************************************************************
   * Interface calls
   *********************************************************************/

  // check if all the modules are still healthy
  event result_t NodeHealthTimer.fired()
  {
    int i;
    uint64_t current_time = call EssSysTimeI.getTimeMilliSeconds();
    uint64_t difference;
    uint64_t expected_time_between;

    watchdog_kick_count++;

    // kick the watchdog
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    call WatchDogHWI.kick();
#endif
    if (watchdog_kick_count <= NODE_HEALTH_TICK)
    {
        // not yet time to check the health of the node
        return SUCCESS;
    }

    watchdog_kick_count = 0;

    // cycle through all the subsystems
    for (i=0; i<MAX_SUBSYSTEM_COUNT; i++)
    {
      if (parameters[i].enable_status == DISABLE)
      {
        // no checking for this subsystem, continue
        dbg(DBG_ERROR, "Subsystem %d checking disabled, skipping\n", i);
        continue;
      }

      if (parameters[i].in_progress < 0)
      {
        dbg(DBG_ERROR, "Uh oh: an end event without a start\n");
      }

      // how long ago did this subsystem start an operation?
      difference = Get64Difference(current_time, 
                                   parameters[i].last_time_started);

      dbg(DBG_ERROR, "In progress = %d, difference = %llu, expected time = %llu, time between %llu, Failure Count %d, Current time %llu, last time started %llu\n", parameters[i].in_progress, difference, parameters[i].expected_time_complete, parameters[i].expected_time_between, 
	parameters[i].failure_count, current_time, parameters[i].last_time_started);

      if (parameters[i].in_progress >= 1)
      {
        // this subsystem is currently completing an operation -
        // has that operation stalled?
        if (difference > parameters[i].expected_time_complete)
             
        {
          HealthCheckFailed(current_time, difference, 
                            parameters[i].expected_time_complete, 
                            i, FAIL_STUCK, &parameters[i]);
          continue;
        }

      }
      else
      {
        // subsystem not doing anything - how long since it last took 
        // action?

        // do we have a flag set to mirror the between time of another
        // subsystem?
        switch (parameters[i].flag)
        {
        case MIRROR_BETWEEN_TRANSMIT:
           expected_time_between = parameters[TRANSMIT].expected_time_between;
           break;
        case MIRROR_BETWEEN_RECEIVE:
           expected_time_between = parameters[RECEIVE].expected_time_between;
           break;
        case MIRROR_BETWEEN_DATA_STORAGE:
           expected_time_between = parameters[DATA_STORAGE].expected_time_between;
           break;
        case MIRROR_BETWEEN_DATA_GENERATION:
           expected_time_between = parameters[DATA_GENERATION].expected_time_between;
           break;
        case FLAG_RESERVED:
        default:
           expected_time_between = parameters[i].expected_time_between;
           break;
        }
    
        if (difference > expected_time_between)
        {
          if ((i == TRANSMIT) && 
              (parameters[DATA_GENERATION].enable_status == DISABLE))
          {
            dbg(DBG_ERROR, "Transmit module idle, but no data generation enabled for this node... warning ignored\n");
            continue;
          }

          HealthCheckFailed(current_time, difference, 
                            expected_time_between,
                            i, FAIL_NOT_RUNNING, &parameters[i]);
          continue;
        }
      }

      dbg(DBG_ERROR, "Subsystem %d is OK\n", i);

    }

    return SUCCESS;
  }

  command void NodeHealthI.Enable(NodeHealthSubsystem_t subsystem,
                                  NodeHealthEnable_t new_state)
  { 
    if ((subsystem >= MAX_SUBSYSTEM_COUNT) || (subsystem < 0))
    {
       dbg(DBG_ERROR, "Tried to enable / disable an invalid subsystem %d\n",
           subsystem);
       return; 
    }

    if ((new_state != DISABLE) && (new_state != ENABLE))
    {
       dbg(DBG_ERROR, "Tried to enable / disable to an invalid state %d\n",
           new_state);
       return; 
    }
    parameters[subsystem].enable_status = new_state;

    dbg(DBG_ERROR, "Changing state for subsystem %d to %d\n",
        subsystem, new_state);

  }
  
  /*
   * Set the parameters to test a subsystem against
   * Note: this does not enable monitoring by default, you need
   * to use the enable funtion afterwards.
   */ 
  command void NodeHealthI.SetParameters(NodeHealthSubsystem_t subsystem,
                             uint32_t expected_time_complete,
                             uint32_t expected_time_between,
                             NodeHealthFlags_t flag)
  {
    if ((subsystem >= MAX_SUBSYSTEM_COUNT) || (subsystem < 0))
    {
       dbg(DBG_ERROR, "Tried to set parameters in an invalid subsystem %d\n",
           subsystem);
       return; 
    }

    
    parameters[subsystem].expected_time_complete = 
        expected_time_complete * NODE_HEALTH_SLACK;
    parameters[subsystem].expected_time_between = 
        expected_time_between * NODE_HEALTH_SLACK;
    parameters[subsystem].flag = flag;
  }
  

  /*
   * Notify the node health module that a subsystem action has started
   */
  command void NodeHealthI.ActionStart(NodeHealthSubsystem_t subsystem)
  {
    if ((subsystem >= MAX_SUBSYSTEM_COUNT) || (subsystem < 0))
    {
       dbg(DBG_ERROR, "Tried to notify start action for invalid subsystem %d\n",
           subsystem);
       return; 
    }
    parameters[subsystem].in_progress += 1;
    if (parameters[subsystem].in_progress == 1)
    {
        parameters[subsystem].last_time_started = call EssSysTimeI.getTimeMilliSeconds();
    }
  }

  /*
   * Notify the node health module that a subsystem action has ended
   */
  command void NodeHealthI.ActionEnd(NodeHealthSubsystem_t subsystem)
  {
    if ((subsystem >= MAX_SUBSYSTEM_COUNT) || (subsystem < 0))
    {
       dbg(DBG_ERROR, "Tried to notify end action for invalid subsystem %d\n",
           subsystem);
       return; 
    }
    parameters[subsystem].in_progress -= 1;
  }


  /*
   * Returns whether the subsystem is enabled or disabled
   */
  command NodeHealthEnable_t NodeHealthI.GetEnableState(NodeHealthSubsystem_t subsystem)
  {
    if ((subsystem >= MAX_SUBSYSTEM_COUNT) || (subsystem < 0))
    {
       dbg(DBG_ERROR, "Tried to request enable status for invalid subsystem %d\n",
           subsystem);
       return DISABLE; 
    }
    return parameters[subsystem].enable_status;
  }

  /*
   * Resets the mote immediately
   */
  command void NodeHealthI.ResetMote() {
    NETPROG_ACTUAL_REBOOT();
  }
}
