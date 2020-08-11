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

module TestUartCommM {
  provides interface StdControl;

  uses interface Leds;
  uses interface Timer;
  uses interface StdControl as UartControl;
  uses interface UartCommI as UartComm;
}
implementation {
  uint16_t response_counter;
  uint8_t expected_responses;

  void start_test();

  // Init UartComm
  command result_t StdControl.init() {
    call Leds.init();
    call UartControl.init();
    
    response_counter = 0;
    expected_responses = 0;

    return SUCCESS;
  }

  // Start UartComm and test timer
  command result_t StdControl.start() {
    call UartControl.start();
    
    start_test();

    return SUCCESS;
  }

  command result_t StdControl.stop() {
    call Timer.stop();
    call UartControl.stop();

    return SUCCESS;
  }

  // Sends data aqcuisition commands and LED toggle commands to DAQ.
  // 
  // NOTE that the UART_BUFFER_SIZE in UartComm.h needs to be as large as the
  // ..number of commands you send in a row.  The below test works with a buffer
  // ..size of 8, but drops the final LED toggle with a buffer size of 7.
  void start_test() {
    // Toggle all green and red  LEDs on DAQ (no response)
    if (call UartComm.sendCommand(12) == FAIL)
      call Leds.redOn();
    if (call UartComm.sendCommand(15) == FAIL)
      call Leds.redOn();

    // Ask DAQ for five readings in a row
    if (call UartComm.sendCommand(30) == FAIL)
      call Leds.redOn();
    if (call UartComm.sendCommand(31) == FAIL)
      call Leds.redOn();
    if (call UartComm.sendCommand(32) == FAIL)
      call Leds.redOn();
    if (call UartComm.sendCommand(33) == FAIL)
      call Leds.redOn();
    if (call UartComm.sendCommand(34) == FAIL)
      call Leds.redOn();

    // Toggle blue LED on DAQ
    if (call UartComm.sendCommand(18) == FAIL)
      call Leds.redOn();

    // BE SURE TO SET THIS CORRECTLY!
    // 4 bytes per reading x 5 readings = 20 bytes
    expected_responses = 20;

    // Green LED indicates test is running
    call Leds.greenToggle();

    // give half a second for a response to come
    call Timer.start(TIMER_ONE_SHOT, 512);
  }

  event result_t Timer.fired() {
    // Make sure we received the correct number of responses
    if (response_counter != expected_responses)
      call Leds.redOn();

    // Reset test conditions
    response_counter = 0;

    // restart test
    start_test();

    return SUCCESS;
  }

  event void UartComm.dataResponse(uint8_t data, result_t result) {
    if (result == FAIL)
      call Leds.redOn();

    response_counter++;

    // Toggle yellow to indicate a byte has been received
    call Leds.yellowToggle();
  }
}
