interface UartCommI {
  /**
   * Send the specified one byte command out over UART1.  The commands will be
   * placed in a FIFO buffer of size UART_COMMAND_BUFFER_SIZE.  Call sendCommand
   * twice to send a two byte command.
   *
   * @param command a one byte command sent out over UART1
   *
   * @return SUCCESS if the command is successfully scheduled, FAIL if there is
   * no room
   */
  command result_t sendCommand(uint8_t data);


  /**
   * Indicates the sensorboard has replied to a command.  Commands are replied
   * to in a FIFO order.  Some commands have no replies and so no response will
   * be given.
   */
  event void dataResponse(uint8_t data, result_t result);
}
