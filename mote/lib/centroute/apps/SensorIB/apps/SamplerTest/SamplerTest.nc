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
 *
 *
 */

includes Msg;

configuration SamplerTest { }
implementation {
    components Main, SamplerTestM, GenericComm as Comm,LedsC,SamplerC,TimerC,UARTNoCRCPacket as UARTPacket;

    Main.StdControl -> SamplerTestM;
    Main.StdControl -> TimerC;
    Main.StdControl -> Comm;

    SamplerTestM.Leds -> LedsC;
    SamplerTestM.Timer -> TimerC.Timer[unique("Timer")];

    //Sampler Communication
    SamplerTestM.SamplerControl -> SamplerC.SamplerControl;
    SamplerTestM.Sample -> SamplerC.Sample;

    //RF communication facility
    SamplerTestM.CommControl -> Comm;
    SamplerTestM.SendMsg -> Comm.SendMsg[Sample_Packet];
    SamplerTestM.ReceiveMsg -> Comm.ReceiveMsg[Sample_Packet];    

    //UART communication facility
    SamplerTestM.UARTControl -> UARTPacket.Control;
    SamplerTestM.UARTSendMsg -> UARTPacket.Send;
    SamplerTestM.UARTReceiveMsg -> UARTPacket.Receive;
    
    //support for plug and play.
    SamplerTestM.PlugPlay -> SamplerC.PlugPlay;
}
