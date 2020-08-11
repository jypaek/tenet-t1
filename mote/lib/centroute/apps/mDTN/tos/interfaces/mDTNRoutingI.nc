
interface mDTNRoutingI{

  command result_t routeAvailable();
  event result_t routeAvailableDone(result_t success);

  command result_t send(uint8_t *data, uint8_t datasize,uint16_t address, uint8_t cost, uint8_t type);
  event result_t sendDone(result_t success);

  event result_t recv(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address, uint8_t type);


}
