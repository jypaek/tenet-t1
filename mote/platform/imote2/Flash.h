/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */
#ifndef __FLASH_H__
#define __FLASH_H__

#define DEBUG 0
#define ASSERT 0

#define FLASH_PARTITION_COUNT 16
#define FLASH_PARTITION_SIZE 0x200000

#define FLASH_STATE_READ_INACTIVE 0
#define FLASH_STATE_PROGRAM 1
#define FLASH_STATE_ERASE 2
#define FLASH_STATE_READ_ACTIVE 3


#define FLASH_BLOCK_COUNT 256
#define FLASH_BLOCK_SIZE 0x20000

#define FLASH_BLOCK_CLEAN 0
#define FLASH_BLOCK_USED 1


#define FLASH_PROGRAM_BUFFER_SIZE 32
#define FLASH_NOT_SUPPORTED 0x100

#define FLASH_NORMAL 0
#define FLASH_OVERWRITE 1

//anything below FLASH_PROTECTED_REGION will not be written/erased by FlashC
#define FLASH_PROTECTED_REGION 0x00200000

enum
{
  NOTHING_TO_ERASE = 3,
};

#endif
