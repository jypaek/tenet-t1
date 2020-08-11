// $Id: HALPXA27XC.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 */

/*
 * @author: Jonathan Hui <jwhui@cs.berkeley.edu>
 *
 * ported to Imote2 - Junaith Ahemed
 */

includes crc;
includes PXAFlash;

configuration HALPXA27XC 
{
  provides 
  {
    interface StdControl;
    interface HALPXA27X[volume_t volume];
    interface FSQueueUtil;
  }
}

implementation 
{
  components HALPXA27XM, FlashC, LedsC as Leds, TimerC; 

  StdControl = HALPXA27XM;
  StdControl = TimerC;
  HALPXA27X = HALPXA27XM;
  FSQueueUtil = HALPXA27XM;

  HALPXA27XM.Flash -> FlashC;
  HALPXA27XM.Leds -> Leds;
  HALPXA27XM.Timer -> TimerC.Timer[unique("Timer")];
}
