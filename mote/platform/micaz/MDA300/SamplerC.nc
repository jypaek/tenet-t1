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
 * history:   modified 11/14/2003
 *
 *
 */

includes sensorboard;
configuration SamplerC
{
  provides {      
      interface StdControl as SamplerControl;
      interface Sampler;
      interface Relay as relay_normally_closed;
      interface Relay as relay_normally_open;
      interface Power as EXCITATION25;
      interface Power as EXCITATION33;
      interface Power as EXCITATION50;      
      command result_t PlugPlay();
 }
}
implementation
{
    components Main,
               SamplerM,
               LedsC,
               DioC,
               IBADC,
               CounterC,
               TempHumM,
               BatteryC,
               PowerC,
               RelayC;

    SamplerM.SamplerControl = SamplerControl;

    SamplerM.Sampler = Sampler;
    SamplerM.Leds -> LedsC;
    TempHumM.Leds -> LedsC;

    // to control relays.
    relay_normally_closed = RelayC.relay_normally_closed;
    relay_normally_open = RelayC.relay_normally_open;
    
    // To individualy Turn on/off Power 
    EXCITATION25 = PowerC.EXCITATION25;
    EXCITATION33 = PowerC.EXCITATION33;
    EXCITATION50 = PowerC.EXCITATION50;    

    // analog channels
    SamplerM.IBADCcontrol -> IBADC.StdControl;
    SamplerM.ADC0 -> IBADC.ADConvert[0];
    SamplerM.ADC1 -> IBADC.ADConvert[1];
    SamplerM.ADC2 -> IBADC.ADConvert[2];
    SamplerM.ADC3 -> IBADC.ADConvert[3];
    SamplerM.ADC4 -> IBADC.ADConvert[4];
    SamplerM.ADC5 -> IBADC.ADConvert[5];
    SamplerM.ADC6 -> IBADC.ADConvert[6];
    SamplerM.ADC7 -> IBADC.ADConvert[7];
    SamplerM.ADC8 -> IBADC.ADConvert[8];
    SamplerM.ADC9 -> IBADC.ADConvert[9];
    SamplerM.ADC10 -> IBADC.ADConvert[10];
    SamplerM.ADC11 -> IBADC.ADConvert[11];
    SamplerM.ADC12 -> IBADC.ADConvert[12];
    SamplerM.ADC13 -> IBADC.ADConvert[13];
    // analog channel parameters
    SamplerM.SetParam0 -> IBADC.SetParam[0];
    SamplerM.SetParam1 -> IBADC.SetParam[1];
    SamplerM.SetParam2 -> IBADC.SetParam[2];
    SamplerM.SetParam3 -> IBADC.SetParam[3];
    SamplerM.SetParam4 -> IBADC.SetParam[4];
    SamplerM.SetParam5 -> IBADC.SetParam[5];
    SamplerM.SetParam6 -> IBADC.SetParam[6];
    SamplerM.SetParam7 -> IBADC.SetParam[7];
    SamplerM.SetParam8 -> IBADC.SetParam[8];
    SamplerM.SetParam9 -> IBADC.SetParam[9];
    SamplerM.SetParam10 -> IBADC.SetParam[10];
    SamplerM.SetParam11 -> IBADC.SetParam[11];
    SamplerM.SetParam12 -> IBADC.SetParam[12];
    SamplerM.SetParam13 -> IBADC.SetParam[13];

    // health channels
    SamplerM.BatteryControl -> BatteryC.StdControl;
    SamplerM.Battery -> BatteryC.Battery;
    SamplerM.TempHumControl -> TempHumM.StdControl;
    SamplerM.Temp -> TempHumM.TempSensor;
    SamplerM.Hum -> TempHumM.HumSensor;
 
    // Digital input channels
    SamplerM.DioControl -> DioC.StdControl;
    SamplerM.Dio0 -> DioC.Dio[0];
    SamplerM.Dio1 -> DioC.Dio[1];
    SamplerM.Dio2 -> DioC.Dio[2];
    SamplerM.Dio3 -> DioC.Dio[3];
    SamplerM.Dio4 -> DioC.Dio[4];
    SamplerM.Dio5 -> DioC.Dio[5];

    // counter channels
    SamplerM.CounterControl -> CounterC.CounterControl;    
    SamplerM.Counter -> CounterC.Counter;
    SamplerM.Plugged -> CounterC.Plugged;

    PlugPlay = SamplerM.PlugPlay;
  }
