
/**
 * @modified 8/3/2007
 * @author Jeongyeup Paek
 **/
 
#include "camera_state.h"

#define MAKE_FLASH_PIN_OUTPUT()  sbi(DDRD, 4)

#ifdef CYCLOPS_FLASH_ON_IS_CBI
#define FLASH_OFF()              sbi(PORTD, 4)
#define FLASH_ON()               cbi(PORTD, 4)
#else
#define FLASH_OFF()              cbi(PORTD, 4)
#define FLASH_ON()               sbi(PORTD, 4)
#endif


module imagerM
{
    provides {
        interface StdControl;
        interface imagerSnap;
        interface imagerConfig;
        interface CameraState[uint8_t neuron_id];
    }
    uses {
        interface imager;
        interface StdControl as ImagerControl;
    }
}
implementation
{

    /* global state variables */
    camera_state_t c_state;
    uint8_t        n_module;    // last neuron module that set the state
    uint8_t        flashOn;     // is flash on?
    
    command result_t StdControl.init() {
        //Set pin for flash to be output
        MAKE_FLASH_PIN_OUTPUT();
        FLASH_OFF();
        flashOn = FALSE;
        return call ImagerControl.init();
    }

    //ActiveEye started and set to default parameters
    command result_t StdControl.start() {
        return call ImagerControl.start();
    }

    command result_t StdControl.stop() {
        return call ImagerControl.stop();
    }
    
/*************** CameraState ***************/
    command camera_state_t CameraState.get[uint8_t neuron_id]() {
        return c_state;
    }

    command result_t CameraState.set[uint8_t neuron_id](camera_state_t new_state) {
        c_state = new_state;
        n_module = neuron_id;
        return SUCCESS;
    }
    
    command uint8_t CameraState.who[uint8_t neuron_id]() {
        return n_module;
    }

/*************** imagerSnap ***************/
    command result_t imagerSnap.snapImage(CYCLOPS_ImagePtr myImg, uint8_t useFlash) {
        if (useFlash) {// If we are to use the IR Leds then turn on the flash;
            FLASH_ON();
            flashOn = TRUE;
        }
        return call imager.snapImage(myImg);
    } 

    event void imager.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) {
        //If we were using the flash, turn it off.
        if (flashOn) {
            FLASH_OFF();
            flashOn = FALSE;
        }
        signal imagerSnap.snapImageDone(myImg, status);
    }

/*************** imagerConfig ***************/
    command result_t imagerConfig.setCaptureParameters(CYCLOPS_CapturePtr myCap) {
        return call imager.setCaptureParameters(myCap);
    }

    command result_t imagerConfig.getPixelAverages() {
        return call imager.getPixelAverages();
    }

    command result_t imagerConfig.run(uint16_t rTime) {
        return call imager.run(rTime);
    }

    event result_t imager.imagerReady(result_t status) {
        return signal imagerConfig.imagerReady(status);
    }

    event result_t imager.setCaptureParametersDone(result_t status) {                   
        return signal imagerConfig.setCaptureParametersDone(status);
    }

    event result_t imager.getPixelAveragesDone(color16_t stat_Vals, result_t status) {
        return signal imagerConfig.getPixelAveragesDone(stat_Vals, status);
    }

    event result_t imager.runDone(result_t status) {
        return signal imagerConfig.runDone(status);
    }
}

