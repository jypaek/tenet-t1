/*									tab:4
 *
 *
 * "Copyright (c) 2000-2002 The Regents of the University  of California.  
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
 *
 */

/*
 *
 * Authors:		Phil Buonadonna, Joe Polastre, Rob Szewczyk
 * Date last modified:  12/19/02
 *
 * Note: Modify this configuration file to choose between software or hardware
 * based I2C.
 */

/* Uncomment line below to enable Hardware based I2C on the mica128 */
//#define HARDWARE_I2C

configuration I2CC
{
  provides {
    interface StdControl;
    interface I2C;
  }
}
implementation {

#ifdef HARDWARE_I2C
  components HPLI2CM, HPLInterrupt,MyLedsC;

  StdControl = HPLI2CM;
  I2C = HPLI2CM;
  HPLI2CM.Interrupt->HPLInterrupt;
  HPLI2CM.Leds -> MyLedsC.Leds;
#else
  components I2CM,MyLedsC;

  StdControl = I2CM;
  I2C = I2CM; 
  I2CM.Leds -> MyLedsC.Leds;
#endif
}
