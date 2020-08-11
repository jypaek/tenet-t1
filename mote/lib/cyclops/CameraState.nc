
/**
 * @modified 8/3/2007
 * @author Jeongyeup Paek
 **/
 
#include "camera_state.h"

interface CameraState
{
    command camera_state_t get();

    command result_t set(camera_state_t n_state);
    
    command uint8_t who();
}

