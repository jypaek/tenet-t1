
/**
 * Control the parent in MultihopLQI dynamic routing protocol.
 * - reset  : give-up current parent and restart as if just booted up.
 * - hold   : hold on to current parent regardless of following updates.
 * - unhold : cancel hold.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

interface ParentControl {

    command void reset();

    command void hold();

    command void unhold();
    
}

