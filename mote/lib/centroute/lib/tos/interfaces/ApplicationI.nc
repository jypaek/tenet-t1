// Interface for connection between Routing Adaptation Layer and 
// Application Layer

interface ApplicationI{

  command result_t SendFromApplication(uint8_t* data, uint8_t datasize, uint16_t address, uint8_t cost, uint8_t reliable, uint8_t id);
  event result_t RecvToApplication(uint8_t* data,uint8_t datasize,uint16_t to_address,uint16_t from_address, uint8_t type);
  event result_t SendFromApplicationDone(result_t success);

  command result_t CheckRouteAvailable();

  event result_t CheckRouteAvailableDone(result_t success);

  event result_t RouteForwardFailed(uint8_t *data, uint8_t datasize);
}
