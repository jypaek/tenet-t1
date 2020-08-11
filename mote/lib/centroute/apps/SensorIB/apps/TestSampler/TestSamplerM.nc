/*
 * This module runs a series of tests on the UartCommM module.  Be sure to
 * attach an mda2400 to the mote or the tests will fail.
 *
 * The overall test scheme is to send a stream of commands to the DAQ and
 * count the number of bytes in response.  If we ever receive a FAIL from
 * UartComm or a byte is lost, the red LED will light permanently indicating
 * a failure.
 *
 * A green LED toggle indicates a test has started.
 * A yellow LED toggle indicates a byte has been received from the DAQ.
 * The red LED indicates a problem was encountered.
 */

module TestSamplerM {
  provides interface StdControl;

  uses interface Leds;
  uses interface Timer;
  uses interface StdControl as SamplerControl;
  uses interface Sample;
}
implementation {
  uint16_t response_counter;
  uint16_t expected_responses;

  void start_test();

  command result_t StdControl.init() {
    call Leds.init();
    call SamplerControl.init();
    
    response_counter = 0;
    expected_responses = 0;

    return SUCCESS;
  }

  // Start UartComm and test timer
  command result_t StdControl.start() {
    call SamplerControl.start();
    start_test();

    return SUCCESS;
  }

  command result_t StdControl.stop() {
    call Timer.stop();
    call SamplerControl.stop();

    return SUCCESS;
  }

  // Sends data aqcuisition commands and LED toggle commands to DAQ.
  // 
  // NOTE that the UART_BUFFER_SIZE in UartComm.h needs to be as large as the
  // ..number of commands you send in a row.  The below test works with a buffer
  // ..size of 8, but drops the final LED toggle with a buffer size of 7.
  void start_test() {
    // Toggle green LED to indicate start of test
    call Leds.greenToggle();

    // Tell the sampler to take a reading every 10 seconds
    call Sample.getSample(0, 0, 100, 0);

    expected_responses = 1;

    // give half a second for a response to come
    //call Timer.start(TIMER_ONE_SHOT, 2000);
  }

  // Return of data
  event result_t Sample.dataReady(int8_t samplerID, uint8_t channel, uint8_t channelType, uint16_t data) {
    if (data == 0)
      call Leds.redOn();
    
    // Toggle yellow LED to indicate a response
    call Leds.yellowToggle();

    response_counter++;

    return SUCCESS;
  }

  event result_t Timer.fired() {
    // Make sure we received the correct number of responses
    if (response_counter != expected_responses)
      call Leds.redOn();

    // Reset test conditions
    response_counter = 0;

    // restart test
    //start_test();

    return SUCCESS;
  }
}
