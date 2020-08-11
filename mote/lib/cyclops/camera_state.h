
/**
 * @modified 6/24/2007
 * @author Jeongyeup Paek
 **/


#ifndef CAMERA_STATE_H
#define CAMERA_STATE_H

//States of camera
typedef enum {
    CAMERA_OFF,
    CAMERA_STARTING,    // bootup (run)
    CAMERA_IDLE,
    CAMERA_BUSY,        // taking imaage
    CAMERA_SETTING      // set parameters
} camera_state_t;


#endif

