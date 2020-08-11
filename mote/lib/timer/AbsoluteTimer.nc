
/**
 * - This interface is almost identical to the tinyos-1.x/tos/interfaces/AbsoluteTimer
 *   but the 'time' is in uint32_t rather that tos_time_t.
 * - Also, this will be provided by 32khz clock.
 * - This is different from the 'LogicalTime' or 'SimpleTime' which sits on
 *   top of the 'Timer'. They have resolution of 32ms, which is not good enough.
 *
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

interface AbsoluteTimer {

    /**
     * Set the AbsoluteTimer (alarm) so that 'fired' event happens at 
     * localtime 'atime'.
     **/
    command result_t set(uint32_t atime);

    command result_t cancel();

    event   result_t fired();

}

