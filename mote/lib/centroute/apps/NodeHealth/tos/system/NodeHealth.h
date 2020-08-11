/* Constants for use with the NodeHealth module */

#ifndef NODE_HEALTH_H
#define NODE_HEALTH_H

// default time to use for processes that execute linearly
// in units of ms
#define DEFAULT_PROCESSING_TIME 1000

/* 
 * The different subsystems that this module monitors
 */
typedef enum _NodeHealthSubsystem_t
  {
    TRANSMIT,
    RECEIVE,
    DATA_STORAGE,
    DATA_GENERATION,
    CYCLOPS_QUERY,
    MAX_SUBSYSTEM_COUNT,
  } NodeHealthSubsystem_t;

/* 
 * Whether monitoring for a sub-system is enabled or disabled
 */
typedef enum _NodeHealthEnable_t
  {
    DISABLE = 0,
    ENABLE = 1,
  } NodeHealthEnable_t;

/*
 * Set the flag field to one of these values
 * to modify the behaviour
 */
typedef enum _NodeHealthFlags_t
  {
    FLAG_RESERVED,
    MIRROR_BETWEEN_TRANSMIT,
    MIRROR_BETWEEN_RECEIVE,
    MIRROR_BETWEEN_DATA_STORAGE,
    MIRROR_BETWEEN_DATA_GENERATION
  } NodeHealthFlags_t;

#endif
