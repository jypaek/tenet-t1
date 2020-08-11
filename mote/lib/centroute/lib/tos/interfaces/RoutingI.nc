// Interface for connection between Routing Adaptation Layer and 
// Routing Layer

interface RoutingI
{

  command result_t SendToRouting(uint8_t* data, uint8_t datasize, uint16_t address, uint8_t cost, uint8_t reliable, uint8_t type);
  
  event result_t RecvFromRouting(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address, uint8_t type);
  
  event result_t SendToRoutingDone(uint8_t *data, uint8_t datasize,
	result_t success, uint8_t type);

  command result_t CheckRouteAvailable();

  event result_t CheckRouteAvailableDone(result_t success);

  event result_t RouteForwardFailed(uint8_t *data, uint8_t datasize);

}
