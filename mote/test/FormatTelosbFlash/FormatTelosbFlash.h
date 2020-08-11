
/**
 * Define the volume ID's that are used by Tenet motes.
 *
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 **/

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)

#define VOL_SIZE STORAGE_BLOCK_SIZE

enum {
	VOL_ID0 = 0,    // used by TRD
	VOL_ID1 = 1,    // used by TRD
	VOL_ID2 = 2,    // used by StreamTransport
	VOL_ID3 = 3,    // used by StreamTransport
	VOL_ID4 = 4,    // used by StreamTransport
	VOL_ID5 = 5,    // used by StreamTransport
	VOL_ID6 = 6,
	VOL_ID7 = 7,
	VOL_ID8 = 8,
	VOL_ID9 = 9,
	VOL_ID10 = 10,
	VOL_ID11 = 11,

	BLOCK_ID0 = unique("StorageManager"),
	BLOCK_ID1 = unique("StorageManager"),
	BLOCK_ID2 = unique("StorageManager"),
	BLOCK_ID3 = unique("StorageManager"),
	BLOCK_ID4 = unique("StorageManager"),
	BLOCK_ID5 = unique("StorageManager"),
	BLOCK_ID6 = unique("StorageManager"),
	BLOCK_ID7 = unique("StorageManager"),
	BLOCK_ID8 = unique("StorageManager"),
	BLOCK_ID9 = unique("StorageManager"),
	BLOCK_ID10 = unique("StorageManager"),
	BLOCK_ID11 = unique("StorageManager"),
};

#else

enum {
	TENET_BYTE_EEPROM_ID = unique("ByteEEPROM")
};

#endif

