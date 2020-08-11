
enum {
    I2CSLAVE_LAST = 0x100,

/* this packet size should be large enough so that
   any packet sent(written) from master to slave
   can fit in */
    I2CSLAVE_PACKETSIZE = TOSH_DATA_LENGTH,
    
    I2C_MAX_PACKETSIZE = TOSH_DATA_LENGTH
};

