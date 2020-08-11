includes eeprom_logger;
interface SequentialRLTI{

  command result_t loadRLT(rlt_t* logger_rlt);
  event result_t loadRLTDone(result_t success);

  command result_t storeRLT(rlt_t* logger_rlt);
  event result_t storeRLTDone(result_t success);

}
