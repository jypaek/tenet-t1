
interface mDTNSendI{

  command result_t mDTNSend(uint8_t* data, uint8_t datasize, uint16_t address, uint8_t cost, uint8_t reliable);
  event result_t mDTNSendDone(result_t success);

}
