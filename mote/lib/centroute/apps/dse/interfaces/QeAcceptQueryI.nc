interface QeAcceptQueryI {

  command result_t passQuery(uint8_t* query);
  event result_t sendQueryResult(uint8_t* res, uint8_t length);
}
