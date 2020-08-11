/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 08/14/2003
 *
 * driver for ADS7828EB on mda300ca
 *
 */

 configuration IBADC
{
  provides {
    interface StdControl;
    interface ADConvert[uint8_t port];
    interface SetParam[uint8_t port];
    interface Power as EXCITATION25;
    interface Power as EXCITATION33;
    interface Power as EXCITATION50;

    interface ADCReset;
  }
}
implementation
{
    components Main,I2CPacketC,IBADCM,
    MyLedsC,
#ifdef EMSTAR_NO_KERNEL
    EmTimerC,
#else
    TimerC,
#endif
    SwitchC;

    ADCReset = IBADCM;
    StdControl = IBADCM;
    ADConvert = IBADCM;
    SetParam = IBADCM;
    IBADCM.Leds -> MyLedsC;
    IBADCM.I2CPacket -> I2CPacketC.I2CPacket[74];
    IBADCM.I2CPacketControl -> I2CPacketC.StdControl; 
#ifdef EMSTAR_NO_KERNEL
    Main.StdControl -> EmTimerC;
    IBADCM.PowerStabalizingTimer -> EmTimerC.EmTimerI[unique("Timer")];
    IBADCM.TimeoutTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
    Main.StdControl -> TimerC;
    IBADCM.PowerStabalizingTimer -> TimerC.Timer[unique("Timer")];
    IBADCM.TimeoutTimer -> TimerC.Timer[unique("Timer")];
#endif
    
    IBADCM.SwitchControl -> SwitchC.SwitchControl;
    IBADCM.Switch -> SwitchC.Switch;
    EXCITATION25 = IBADCM.EXCITATION25;
    EXCITATION33 = IBADCM.EXCITATION33;
    EXCITATION50 = IBADCM.EXCITATION50;    
}
