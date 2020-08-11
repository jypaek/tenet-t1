/*
* "Copyright (c) 2006~2007 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * Platform dependant part of sampling for mica2dot.
 * This element is written assuming that mica2dot users will use basicsb
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @modified 7/28/2007
 **/

module SamplePlatform {
    provides {
        interface SampleADC as ADC;
    }
    uses {
        interface ADC as Photo;
        interface ADC as Temperature;
        interface StdControl as ADCControl;
        interface Timer;
    }
}
implementation {

    norace bool m_adc_busy;
    
    command result_t ADC.getData(uint8_t channel) {
        result_t result;
        
        if (m_adc_busy)
            return FAIL;
            
        switch(channel){
            case TEMPERATURE:
            case ITEMP:
                result = call Temperature.getData();
                break;
            case PHOTO:
            case TSRSENSOR:
            case PARSENSOR:
                result = call Photo.getData();
                break;
            case HUMIDITY:
            default:
                result = FAIL;
        }
        if (result == SUCCESS) {
            m_adc_busy = TRUE;
            call Timer.start(TIMER_ONE_SHOT, 50);
        }
        return result;
    }

    command bool ADC.validChannel(uint8_t channel) {
        switch(channel){
            case TEMPERATURE:
            case ITEMP:
            case PHOTO:
            case TSRSENSOR:
            case PARSENSOR:
                break;
            default:
                return FALSE;
        }
        return TRUE;
    }
    task void stopTimer() {
        call Timer.stop();
    }
    async event result_t Photo.dataReady(uint16_t data){
        if (m_adc_busy)
            signal ADC.dataReady(data);
        m_adc_busy = FALSE;
        post stopTimer();
        return SUCCESS;
    }
    async event result_t Temperature.dataReady(uint16_t data){
        if (m_adc_busy)
            signal ADC.dataReady(data);
        m_adc_busy = FALSE;
        post stopTimer();
        return SUCCESS;
    }
    event result_t Timer.fired() {
        if (m_adc_busy)
            signal ADC.error(0);
        m_adc_busy = FALSE;
        post stopTimer();
        return SUCCESS;
    }

    command void ADC.init() {
        m_adc_busy = FALSE;
        call ADCControl.init();
    }
    command void ADC.start() {
        call ADCControl.start();
    }
    command void ADC.stop() {
        call ADCControl.stop();
    }
}

