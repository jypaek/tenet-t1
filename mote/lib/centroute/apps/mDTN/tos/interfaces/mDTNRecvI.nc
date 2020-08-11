
interface mDTNRecvI{

  event result_t mDTNRecv(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address);
}
