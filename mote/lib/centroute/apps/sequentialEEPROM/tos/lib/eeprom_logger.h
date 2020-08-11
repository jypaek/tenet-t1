
#ifndef _EEPROMLOGGER
#define _EEPROMLOGGER 0

#ifndef MAX_RECORD_PAYLOAD
#define MAX_RECORD_PAYLOAD (TOSH_DATA_LENGTH)
#endif

#ifndef RECORD_START_PAGE  
#define RECORD_START_PAGE 3
#endif
#ifndef RECORD_END_PAGE
#define RECORD_END_PAGE 1004 
#endif

#define  EEPROM_MAX_PAGES 2048 
#define  EEPROM_PAGE_SIZE 264

enum{
	PAGE_META = unique("PageEEPROM"),
	SEQUENTIAL_EEPROM = unique("PageEEPROM")
};

enum{
	EEPROM_FULL=100,
	NO_MORE_RECORDS=101
};

enum
{
	DIST_STORAGE_APPACK=54,
	STORAGE_BEACON=55
};

typedef struct _pagemeta{
  uint16_t head_offset;
  uint16_t tail_offset;
  uint16_t num_writes;
} __attribute__ ((packed)) pagemeta_t;

typedef struct _pagemetacomp{
	uint8_t blob[4];
} __attribute__ ((packed)) pagemetacompressed_t;


typedef struct _record{
	uint8_t length;
	uint8_t data[0];
} __attribute__ ((packed)) record_t;

typedef struct _rlt{
	uint32_t currenthead;
	uint32_t currenttail;
} __attribute__ ((packed)) rlt_t;


#define MAX_RECORD_SIZE (sizeof(record_t) + MAX_RECORD_PAYLOAD)


uint16_t getEEPROMPage(uint32_t offset);
uint16_t getEEPROMOffset(uint32_t offset);
uint32_t getByteEEPROMSize();



uint16_t getEEPROMPage(uint32_t offset){
	uint16_t p = 0;
	p = offset/(EEPROM_PAGE_SIZE - sizeof(pagemetacompressed_t));
	return p + RECORD_START_PAGE;
}

uint16_t getEEPROMOffset(uint32_t offset){
	uint16_t p = 0;
	uint16_t poff = 0;
	p = offset/(EEPROM_PAGE_SIZE - sizeof(pagemetacompressed_t));
	poff = offset - (p*(EEPROM_PAGE_SIZE-sizeof(pagemetacompressed_t)));
	return poff + sizeof(pagemetacompressed_t);

}

uint32_t getByteOffset(uint16_t eeprompage, uint16_t eepromoffset){
  uint32_t offset = (eeprompage - RECORD_START_PAGE) *
                    (EEPROM_PAGE_SIZE - sizeof(pagemetacompressed_t));
	offset = offset + (eepromoffset - sizeof(pagemetacompressed_t));
	return offset;
}

uint32_t getByteEEPROMSize(){
	uint32_t size = (EEPROM_PAGE_SIZE - sizeof(pagemetacompressed_t))*(RECORD_END_PAGE - RECORD_START_PAGE + 1);
	return size;
}

uint32_t incByteEEPROM(uint32_t offset, uint32_t val){
	uint32_t newval = offset + val;
	uint32_t eepromsize = getByteEEPROMSize();
	if(newval >= eepromsize){
		newval = newval - eepromsize;
	}
	return newval;
}

uint32_t decByteEEPROM(uint32_t offset, uint32_t val){
	uint32_t newval=0;
	uint32_t eepromsize = getByteEEPROMSize();
	int t = offset - val;
	if(t >= 0){
		newval = offset-val;
	}else{
		newval = eepromsize - (val-offset);
	}

	return newval;
}

#endif
