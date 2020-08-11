/*
 * Platform dependant part of sampling.
 *
 * @author Marcos Vieira
 * @author August Joki
 * @author Jeongyeup Paek
*/

module SamplePlatform {
    provides {
        interface SampleADC as ADC;
    }
    uses {
        interface StdControl as ADCControl;

        interface SplitControl as HumidityControl;
        interface ADC as Humidity;
        interface ADC as Temperature;
        interface ADC as TSR;
        interface ADC as PAR;
        interface ADC as InternalTemperature;
        interface ADCError as HumidityError;
        interface ADCError as TemperatureError;
    }
}
implementation {

    command result_t ADC.getData(uint8_t channel) {
        switch(channel) {
            case HUMIDITY:
                return call Humidity.getData();
                break;
            case TEMPERATURE:
                return call Temperature.getData();
                break;
            case PHOTO:
            case TSRSENSOR:
                return call TSR.getData();
                break;
            case PARSENSOR:
                return call PAR.getData();
                break;
            case ITEMP:
                return call InternalTemperature.getData();
                break;
            default:
                return FAIL;
        }
        return SUCCESS;
    }

    command bool ADC.validChannel(uint8_t channel) {
        switch(channel) {
            case HUMIDITY:
            case TEMPERATURE:
            case PHOTO:
            case TSRSENSOR:
            case PARSENSOR:
            case ITEMP:
                break;
            default:
                return FALSE;
        }
        return TRUE;
    }
    async event result_t Humidity.dataReady(uint16_t data) {
        signal ADC.dataReady(data);
        return SUCCESS;
    }

    event result_t HumidityError.error(uint8_t token) {
        signal ADC.error(token);
        return FAIL;
    }

    async event result_t Temperature.dataReady(uint16_t data) {
        signal ADC.dataReady(data);
        return SUCCESS;
    }

    event result_t TemperatureError.error(uint8_t token) {
        signal ADC.error(token);
        return FAIL;
    }

    async event result_t TSR.dataReady(uint16_t data) {
        signal ADC.dataReady(data);
        return SUCCESS;
    }

    async event result_t PAR.dataReady(uint16_t data) {
        signal ADC.dataReady(data);
        return SUCCESS;
    }

    async event result_t InternalTemperature.dataReady(uint16_t data) {
        signal ADC.dataReady(data);
        return SUCCESS;
    }

    event result_t HumidityControl.initDone() {
        return SUCCESS;
    }

    event result_t HumidityControl.startDone() {
        call HumidityError.enable();
        call TemperatureError.enable();
        return SUCCESS;
    }

    event result_t HumidityControl.stopDone() {
        call HumidityError.disable();
        call TemperatureError.disable();
        return SUCCESS;
    }

    command void ADC.init() {
        call ADCControl.init();
        call HumidityControl.init();
    }

    command void ADC.start() {
        call ADCControl.start();
        call HumidityControl.start();
    }

    command void ADC.stop() {
        call ADCControl.stop();
        call HumidityControl.stop();
    }
}

