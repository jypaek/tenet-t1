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
 * History:   created  08/14/2003
 * history:   modified 11/14/2003
 *
 *
 */

module SamplerM
{
    provides {
        interface StdControl as SamplerControl;
        interface Sampler;
        command result_t PlugPlay();
    }
    uses {
        interface Leds;
        
        // analog channels
        interface StdControl as IBADCcontrol;
        interface ADConvert as ADC0;
        interface ADConvert as ADC1;
        interface ADConvert as ADC2;
        interface ADConvert as ADC3;
        interface ADConvert as ADC4;
        interface ADConvert as ADC5;
        interface ADConvert as ADC6;
        interface ADConvert as ADC7;
        interface ADConvert as ADC8;
        interface ADConvert as ADC9;
        interface ADConvert as ADC10;
        interface ADConvert as ADC11;
        interface ADConvert as ADC12;
        interface ADConvert as ADC13;

        // ADC parameters
        interface SetParam as SetParam0;
        interface SetParam as SetParam1;
        interface SetParam as SetParam2;
        interface SetParam as SetParam3;
        interface SetParam as SetParam4;
        interface SetParam as SetParam5;
        interface SetParam as SetParam6;
        interface SetParam as SetParam7;
        interface SetParam as SetParam8;
        interface SetParam as SetParam9;
        interface SetParam as SetParam10;
        interface SetParam as SetParam11;
        interface SetParam as SetParam12;
        interface SetParam as SetParam13;
        
        // health channels temp,humidity,voltage
        interface StdControl as BatteryControl;
        interface ADConvert as Battery;
        interface StdControl as TempHumControl;
        interface ADConvert as Temp;
        interface ADConvert as Hum;
        
        // digital and relay channels
        interface StdControl as DioControl;
        interface Dio as Dio0;
        interface Dio as Dio1;
        interface Dio as Dio2;
        interface Dio as Dio3;
        interface Dio as Dio4;
        interface Dio as Dio5;
        
        // counter channels
        interface StdControl as CounterControl;
        interface Dio as Counter;
        
        command result_t Plugged();
    }
}
implementation {
#include "sensorboard.h"
    
    void next_schedule();
    
    /*********************************************Parameter Setting Utility*************************************************/
#define SAMPLER_CHANNEL_ACTIVE_MARKER 0x01
#define CHANNEL_EVENT_MARKER 0x02
    
    /***********************************************Parameter Setting*******************************************************/        
    // analog channels
    static inline void setparam_analog(uint8_t channel, uint8_t param) {
        switch(channel) {
        case 0:  call SetParam0.setParam(param);  break;
        case 1:  call SetParam1.setParam(param);  break;
        case 2:  call SetParam2.setParam(param);  break;
        case 3:  call SetParam3.setParam(param);  break;
        case 4:  call SetParam4.setParam(param);  break;
        case 5:  call SetParam5.setParam(param);  break;
        case 6:  call SetParam6.setParam(param);  break;
        case 7:  call SetParam7.setParam(param);  break;
        case 8:  call SetParam8.setParam(param);  break;
        case 9:  call SetParam9.setParam(param);  break;
        case 10: call SetParam10.setParam(param); break;
        case 11: call SetParam11.setParam(param); break;
        case 12: call SetParam12.setParam(param); break;
      case 13: call SetParam13.setParam(param); break;
        default:
        }
        return;
    }
    // digital channels
    static inline void setparam_digital(uint8_t channel, uint8_t param) {
        switch(channel) {
        case 0:  call Dio0.setparam(param);  break;
        case 1:  call Dio1.setparam(param);  break;
        case 2:  call Dio2.setparam(param);  break;
        case 3:  call Dio3.setparam(param);  break;
        case 4:  call Dio4.setparam(param);  break;
        case 5:  call Dio5.setparam(param);  break;
        default:
        }
        return;
    }
    // counter channel
    static inline void setparam_counter(uint8_t param) {
        call Counter.setparam(param);
        return;
    }
    
    /*************************************Init, Start , Stop ***********************************************************/
    command result_t SamplerControl.init() {
        call CounterControl.init();
        call DioControl.init();
        call IBADCcontrol.init();
        call BatteryControl.init();
        call TempHumControl.init();
        
        return SUCCESS;
    }
    
    command result_t SamplerControl.start() {
        call CounterControl.start();
        call DioControl.start();
        call IBADCcontrol.start();
        call BatteryControl.start();
        call TempHumControl.start();
        call CounterControl.start();
        
        return SUCCESS;
    }
    
    command result_t SamplerControl.stop() {
        call CounterControl.stop();
        call DioControl.stop();
        call IBADCcontrol.stop();
        call BatteryControl.stop();
        call TempHumControl.stop();
        
        return SUCCESS;
    }
    
    /***************************************************Sampler Interface Implementation****************************************/
    command result_t Sampler.set_digital_output(uint8_t channel, uint8_t state) { }
    
    command int8_t Sampler.getSample(uint8_t channel, uint8_t channelType, uint16_t interval, uint8_t param) {
        switch (channelType) {
        case MDA300_ANALOG:
            setparam_analog(channel, param);
            
            switch (channel) {
            case 0:  call ADC0.getData();  break;
            case 1:  call ADC1.getData();  break;
            case 2:  call ADC2.getData();  break;
            case 3:  call ADC3.getData();  break;
            case 4:  call ADC4.getData();  break;
            case 5:  call ADC5.getData();  break;
            case 6:  call ADC6.getData();  break;
            case 7:  call ADC7.getData();  break;
            case 8:  call ADC8.getData();  break;
            case 9:  call ADC9.getData();  break;
            case 10: call ADC10.getData(); break;
            case 11: call ADC11.getData(); break;
            case 12: call ADC12.getData(); break;
            case 13: call ADC13.getData(); break;
            default:
            }
            break;
        case MDA300_DIGITAL:
            setparam_digital(channel, param);

            switch (channel) {
            case 0: call Dio0.getData(); break;
            case 1: call Dio1.getData(); break;
            case 2: call Dio2.getData(); break;
            case 3: call Dio3.getData(); break;
            case 4: call Dio4.getData(); break;
            case 5: call Dio5.getData(); break;
            default:
            }
            break;
        case MDA300_BATTERY:
            call Battery.getData();
            break;
        case MDA300_TEMPERATURE:
            call Temp.getData();
            break;
        case MDA300_HUMIDITY:
            call Hum.getData();                
            break;
        case MDA300_COUNTER:
            setparam_counter(param);
            
            call Counter.getData();
            break;
        default:
        }

        return SUCCESS;
    }
    
    command result_t Sampler.reTask(int8_t record,uint16_t interval) {
        return SUCCESS;
    }
    
    command result_t Sampler.stop(int8_t record) {
        return SUCCESS;
    }
    
    command uint8_t Sampler.availableSamplingRecords() {
        return 0;
    }
    
    // analog channels
    event result_t ADC0.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_ANALOG, data);
        return SUCCESS;
      }

    event result_t ADC1.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 1, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC2.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 2, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC3.dataReady(uint16_t data) {
        signal Sampler.dataReady(0, 3, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC4.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 4, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC5.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 5, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC6.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 6, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC7.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 7, MDA300_ANALOG, data);
        return SUCCESS;
    }
    event result_t ADC8.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 8, MDA300_ANALOG, data);
        return SUCCESS;
      }

    event result_t ADC9.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 9, MDA300_ANALOG, data);
        return SUCCESS;
      }
    event result_t ADC10.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 10, MDA300_ANALOG, data);
        return SUCCESS;
      }
    event result_t ADC11.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 11, MDA300_ANALOG, data);
        return SUCCESS;
      }
    event result_t ADC12.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 12, MDA300_ANALOG, data);
        return SUCCESS;
      }

    event result_t ADC13.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 13, MDA300_ANALOG, data);
        return SUCCESS;
      }

    // miscelanous channels
    event result_t Battery.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_BATTERY, data);
        return SUCCESS;
      }

    event result_t Temp.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_TEMPERATURE, data);
        return SUCCESS;
      }

    event result_t Hum.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_HUMIDITY, data);
        return SUCCESS;
      }

    event result_t Counter.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_COUNTER, data);
        return SUCCESS;
      }

    // digital channels
    event result_t Dio0.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 0, MDA300_DIGITAL, data);
        return SUCCESS;
      }


    event result_t Dio1.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 1, MDA300_DIGITAL, data);
        return SUCCESS;
      }


    event result_t Dio2.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 2, MDA300_DIGITAL, data);
        return SUCCESS;
      }


    event result_t Dio3.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 3, MDA300_DIGITAL, data);
        return SUCCESS;
      }


    event result_t Dio4.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 4, MDA300_DIGITAL, data);
        return SUCCESS;
      }


    event result_t Dio5.dataReady(uint16_t data) { 
        signal Sampler.dataReady(0, 5, MDA300_DIGITAL, data);
        return SUCCESS;
      }

    /********************************************Events that are not particularly handeled**************************************/
    event result_t Dio0.dataOverflow() { return SUCCESS; }
    event result_t Dio1.dataOverflow() { return SUCCESS; }
    event result_t Dio2.dataOverflow() { return SUCCESS; }
    event result_t Dio3.dataOverflow() { return SUCCESS; }
    event result_t Dio4.dataOverflow() { return SUCCESS; }
    event result_t Dio5.dataOverflow() { return SUCCESS; }
    event result_t Dio0.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio1.valueReady(bool data) { return SUCCESS; }  
    event result_t Dio2.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio3.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio4.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio5.valueReady(bool data) { return SUCCESS; } 
    event result_t Counter.dataOverflow() { return SUCCESS; }
    event result_t Counter.valueReady(bool data) { return SUCCESS; } 
    default event result_t Sampler.dataReady(int8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data) { return SUCCESS; }

   /********************************************Automatic detection if the mda300ca present or not******************************/
    command result_t PlugPlay() { return call Plugged(); }
}
