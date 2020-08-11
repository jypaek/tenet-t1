
/*
 * Configuration file for the MDA400 driver. (Triaxis)
 *
 * Authors: Jeongyeup Paek, Sumit Rangwala
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @author Sumit Rangwala
 * @modified 3/21/2005
 */

#ifndef MDA400
    # You should define 'MDA400' in the Makefile
      to make sure that correct components are included
#endif

configuration MDA400C { 
    provides {
        interface StdControl;
        interface MDA400I;
        interface VBSRControl;
        interface VBTimeSync;
    }
}

implementation {
    components MDA400M, 
               HPLVBOARDC;

    StdControl = MDA400M;
    MDA400I = MDA400M; 
    VBSRControl = MDA400M; 
    VBTimeSync = MDA400M;

    MDA400M.HPLVBOARD -> HPLVBOARDC;
}

