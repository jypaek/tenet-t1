//$Id: MSP430DMAC.nc,v 1.3 2006-08-18 21:31:22 august Exp $
/* "Copyright (c) 2000-2005 The Regents of the University of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement
 * is hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY
 * OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 */

/**
 * Implementation of the HAL level component for the MSP430 DMA module.
 * This configuration provides the available DMA channels through the
 * MSP430DMA parameterized interface.  If more channels are requested
 * than available through unique("DMA"), there will be no mapping for
 * that channel and compilation will fail.
 *
 * @author Ben Greenstein <ben@cs.ucla.edu>
 * @author Joe Polastre <info@moteiv.com>
 */
configuration MSP430DMAC {
  provides {
    interface MSP430DMA[uint8_t channel];
    interface MSP430DMAControl;
  }
}
implementation {
  components MSP430DMAM, HPLDMAM;
  MSP430DMA = MSP430DMAM;
  MSP430DMAControl = MSP430DMAM;
  MSP430DMAM.HPLDMAControl -> HPLDMAM.DMAControl;
  MSP430DMAM.DMAChannelCtrl0 -> HPLDMAM.DMAChannelCtrl0;
  MSP430DMAM.DMAChannelCtrl1 -> HPLDMAM.DMAChannelCtrl1;
  MSP430DMAM.DMAChannelCtrl2 -> HPLDMAM.DMAChannelCtrl2;
}
