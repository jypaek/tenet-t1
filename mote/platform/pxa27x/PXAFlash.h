// $Id: PXAFlash.h,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 */

/*
 * @author: Jonathan Hui <jwhui@cs.berkeley.edu>
 */

#ifndef __PXA_FLASH_H__
#define __PXA_FLASH_H__

#include "Storage.h"

enum 
{
  FLASH_PAGE_SIZE = 1024,
  FLASH_BLOCK_SIZE_LOG2 = 18, 
  /*Flash Block size is 128k*/
  FLASH_BLOCK_SIZE = 0x20000,
  //FLASH_BLOCK_SIZE = 1L << FLASH_BLOCK_SIZE_LOG2,
  /*Number of blocks allocated for Flash Logger.*/
  FLASH_NUM_BLOCKS = 200,
  FLASH_NUM_BLOCKS_SECTOR = 16,
  FLASH_FS_NUM_SECTORS = 14,
};

enum
{
  /* Start address for flash fs. The rest of the blocks
   * below the given address is used by the app code
   * and the boot loader.
   */
  FLASH_LOGGER_START_ADDR = 0x240000,
  
  
  /* The meta data and the sector table is stored in the
   * end two blocks of the files system.
   *
   * CAUTION; There is an assumption in the system that the
   * system tables are continuous. Modify EraseTimer in
   * FormatStorageM if things change here.
   */
  FILE_META_DATA_START_ADDR = 0x1B80000,
  SECTOR_TABLE_START_ADDR = 0x1BC0000,
  NUM_ST_BLOCKS = 2,
  NUM_MD_BLOCKS = 2,
  NUM_SYS_BLOCKS = 4, 
};

enum 
{
  FLASH_INVALID_SIG = 0xff,
  FLASH_INVALID_VOLUME_ID = 0xff,
  /*This means that the flash block has to be erased*/
  FLASH_UNALLOCED_BLOCK = 0xFE,	   
  FLASH_INVALID_BLOCK = 0xff,
  INVALID_PTR = 0xffffffff,
  MD_ST_ERASE = 0xFE,
  MD_ST_NO_ERASE = 0xFF,

  /**
   * Values are completely random, but its chosen in such
   * a way that its easier to switch a valid table to invalid.
   */
  VALID_SECTOR_TABLE = 0xADAD,
  INVALID_SECTOR_TABLE = 0xA9A9, 

  VALID_META_DATA = 0xADAD,
  INVALID_META_DATA = 0xA9A9, 
};

enum 
{
  FLASH_CMD_SIZE        = 1,
  FLASH_ADDR_SIZE       = 3,
  FLASH_FR_DUMMY_BYTES  = 1,
  FLASH_RES_DUMMY_BYTES = 3,
};


volatile bool ERASING_FLASH = FALSE;

enum
{
  FLASH_NOOP = 1,
  FLASH_WRITE_BUSY = 2,
  FLASH_ERASE_BUSY  = 3,
};

enum {                  // I, A, D, T, R
  FLASH_WREN      = 0,  // 1, 0, 0, 0, 0
  FLASH_WRDI      = 1,  // 1, 0, 0, 0, 0
  FLASH_RDSR      = 2,  // 1, 0, 0, 0, 1
  FLASH_WRSR      = 3,  // 1, 0, 0, 1, 0
  FLASH_READ      = 4,  // 1, 3, 0, 0, N
  FLASH_FAST_READ = 5,  // 1, 3, 1, 0, N
  FLASH_PP        = 6,  // 1, 3, 0, N, 0
  FLASH_SE        = 7,  // 1, 3, 0, 0, 0
  FLASH_BE        = 8,  // 1, 0, 0, 0, 0
  FLASH_DP        = 9,  // 1, 0, 0, 0, 0
  FLASH_RES       = 10, // 1, 0, 3, 0, 1
  FLASH_CRC       = 11, // 1, 3, 0, 0, 1
};

typedef enum
{
  WRITE_REQUEST = 1,
  CREATE_REQUEST = 2,
  DELETE_REQUEST = 3,
  FOPEN_REQUEST = 4,
  FCLOSE_REQUEST = 5,
} FLASH_COMMANDS_Q ;

typedef uint8_t  stm25p_status_t;
typedef uint32_t stm25p_addr_t;
typedef uint8_t  stm25p_sig_t;

#define FILE_NAME_SIZE 32

typedef struct
{
  uint16_t ClientVolume;
  uint16_t ClientBlock;
  uint32_t WrtAddr;
  uint32_t DataLen;
} WriteRequest;

typedef struct
{
  uint16_t ClientVolume;
  uint8_t FileName [FILE_NAME_SIZE];
} OpenCloseRequest;

typedef struct
{
  uint8_t FileName [FILE_NAME_SIZE];
} DeleteRequest;

typedef struct
{
  uint8_t FileName [FILE_NAME_SIZE];
  uint32_t FileSize;
} CreateRequest;

typedef union 
{
  WriteRequest wreq;
  DeleteRequest dreq;
  CreateRequest creq;
  OpenCloseRequest ocreq;
} FRequest;

typedef struct
{
  uint8_t ReqType;
  uint16_t BufferOffset;
  uint16_t CallerId;
  //WriteRequest preq;
  FRequest preq;
} PendingRequest;

typedef struct
{
  uint16_t validity;
  volume_id_t volumeId;
  uint8_t NumBlocks;
  bool IsMounted;
  uint8_t fileName [FILE_NAME_SIZE];
  uint32_t CurrWritePtr;
  uint32_t CurrReadPtr;
  uint32_t CurrLoc;
} FileMetadata;

typedef struct
{
  volume_id_t volumeId;
} BlockMetadata;

typedef struct 
{
  uint16_t validity;
  uint16_t numfiles;
  BlockMetadata block[FLASH_NUM_BLOCKS];
  uint16_t crc;
} SectorTable;

enum {
  FLASH_INVALID_VERSION = 0xffff,
};

enum {
  FLASH_INVALID_ADDR = 0xffffffff,
};

enum {
  STORAGE_BLOCK_SIZE = FLASH_BLOCK_SIZE,
};

typedef stm25p_addr_t storage_addr_t;

#endif
