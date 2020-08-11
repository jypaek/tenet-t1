includes eeprom_logger;
interface SequentialPageMetaI{

  command result_t writePageMeta(uint16_t eeprompage, pagemeta_t* pm);
  event result_t writePageMetaDone(result_t success);

  command result_t readPageMeta(uint16_t eeprompage, pagemeta_t* pm);
  event result_t readPageMetaDone(result_t success);

  command result_t flushPage(uint16_t eeprompage);
  event result_t flushPageDone(result_t success);
}
