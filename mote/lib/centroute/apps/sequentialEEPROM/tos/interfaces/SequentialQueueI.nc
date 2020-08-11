includes eeprom_logger;
interface SequentialQueueI{

  //QUEUE INTERFACE
  command result_t readHead();
  event result_t readHeadDone(uint8_t* data, uint8_t datasize, result_t success);
  command result_t unreadHead();
  event result_t unreadHeadDone(result_t success);

  command result_t writeTail(uint8_t* data, uint8_t datasize);
  event result_t writeTailDone(result_t success);

  command uint8_t isQueueEmpty();

}
