includes QueryTypes;

module QueryTableM {
  provides {
    interface StdControl;
    interface QueryTableI;
  }
}

implementation {
#include "QueryConstants.h"
#include "StdDbg.h"

  typedef struct MemoryHeader_s {
    uint8_t* nextBlk;
    uint8_t freeSpace;

    // Let inUse use the entire byte since length isn't ever used.
    //uint8_t length :7;
    uint8_t inUse; // : 1;
  } __attribute__((packed)) MemoryHeader_t;

  // Correct operation of this module depends upon the fact that
  // the memory size is 256 bytes.
#define QT_MEMORY_TOTAL 128

  // This is a flag used to make sure memoryAccesses don't
  // corrupt memory.
  uint8_t memoryBusy;
  uint8_t memory[ QT_MEMORY_TOTAL ];

  uint8_t samplingIdCnt( MemoryHeader_t* idx );

  ////////////////////////////////////////////////////////////////////////////
  //
  // Command: StdControl.init( )
  //
  // Purpose: The purpose of this command is to init this component.
  //
  ////////////////////////////////////////////////////////////////////////////

  command result_t StdControl.init( ) {
    // Setup header.
    MemoryHeader_t* pt = (MemoryHeader_t*)(memory);
    pt->nextBlk = &memory[sizeof(MemoryHeader_t)];
    pt->freeSpace = 0;
    pt->inUse = 0;

    // Setup single large amount of free memory.
    pt = (MemoryHeader_t*)(&memory[sizeof(MemoryHeader_t)]);
    pt->nextBlk = &memory[QT_MEMORY_TOTAL - sizeof(MemoryHeader_t)];
    pt->freeSpace = QT_MEMORY_TOTAL - 3*sizeof(MemoryHeader_t);
    pt->inUse = 0;

    // Setup tail.
    pt = (MemoryHeader_t*)(&memory[QT_MEMORY_TOTAL
	- sizeof(MemoryHeader_t)]);
    pt->nextBlk = NULL;
    pt->freeSpace = 0;
    pt->inUse = 0;

    memoryBusy = 0;

    return SUCCESS;
  }

  ////////////////////////////////////////////////////////////////////////////
  //
  // Command: StdControl.start( )
  //
  // Purpose: The purpose of this command is to init this component.
  //
  ////////////////////////////////////////////////////////////////////////////

  command result_t StdControl.start( ) {
    return SUCCESS;
  }

  ////////////////////////////////////////////////////////////////////////////
  //
  // Command: StdControl.stop( )
  //
  // Purpose: The purpose of this command is to init this component.
  //
  ////////////////////////////////////////////////////////////////////////////

  command result_t StdControl.stop( ) {
    return SUCCESS;
  }


  // What about duplicate insertion?
  // Two queries with the same ID?
  command uint8_t* QueryTableI.insert(uint8_t* buff, uint8_t length, uint8_t extraSpace ) {
    uint8_t retVal = SUCCESS;
    MemoryHeader_t* curBlk;
    MemoryHeader_t* prvBlk;
    MemoryHeader_t* nxtBlk;

    QueryHeader_t* qHdr;
    QueryHeader_t* buffQHdr;

    uint8_t i;

    uint16_t totalSize;


    totalSize = (uint16_t)(length) + (uint16_t)(extraSpace);
    buffQHdr = (QueryHeader_t*)(buff);

    curBlk = (MemoryHeader_t*)(memory);
    // Search for duplicate query ID.
    // Since we're only reading there is no need to
    // disable interrupts.
    for( curBlk = (MemoryHeader_t*)(curBlk->nextBlk); curBlk->nextBlk != NULL;
	curBlk = (MemoryHeader_t*)(curBlk->nextBlk) ) {
      qHdr = (QueryHeader_t*)(((uint8_t*)(curBlk)) + sizeof(MemoryHeader_t));

      if( (qHdr->queryID == buffQHdr->queryID) && (curBlk->inUse != 0) ) {
	dbg( DBG_USR3, "QT: insert failed due to duplicate query ID\n");
	return NULL;
      }
    }


    atomic {
      if( memoryBusy == 0 )
	memoryBusy = 1;
      else
	retVal = FAIL;
    }

    if( retVal == FAIL )
      return NULL;

    // Find a block large enough in a first-fit manner.
    // Block should not be in use.
    prvBlk = (MemoryHeader_t*)(memory);
    curBlk = (MemoryHeader_t*)(prvBlk->nextBlk);

    i= 0;

    while( curBlk->nextBlk != NULL ) {
      if( (totalSize <= curBlk->freeSpace) && (curBlk->inUse == 0) ) {
	// A large enough block has been found.
	// The index is idx.  See if we can chop it up into smaller pieces
	// or whether the entire block must be allocated.
	if( curBlk->freeSpace > (totalSize + sizeof(MemoryHeader_t)) ) {
	  // Block can be chopped up.
	  nxtBlk = (MemoryHeader_t*)((uint8_t*)(curBlk) + totalSize + sizeof(MemoryHeader_t));
	  nxtBlk->freeSpace = curBlk->freeSpace - totalSize - sizeof(MemoryHeader_t);
	  nxtBlk->nextBlk = curBlk->nextBlk;
	  nxtBlk->inUse = 0;
	  curBlk->nextBlk = (uint8_t*)(nxtBlk);
	  curBlk->freeSpace = totalSize;
	}

	curBlk->inUse = 1;

	/*
	// No where is MemroyHeader_t.length actually used.
	curBlk->length = length;
	*/

	// At this point all the necessary stuff has been set in
	// the memory header, so interrupts can be turned back on.
	// Especially since the next piece of code is copying
	// and zeroing.
	atomic { memoryBusy = 0; }
	stddbg( "this is the %d th slot in QT\n", ++i);

	// Now store the query, and zero the rest.
	for( i = 0; i < length; i++ )
	  ((uint8_t*)(curBlk))[ sizeof(MemoryHeader_t) + i ] = buff[i];

	for( i = 0; i < extraSpace; i++ )
	  ((uint8_t*)(curBlk))[ sizeof(MemoryHeader_t) + length + i ] = 0;

	dbg( DBG_USR3, "QT: insert succeeded\n");
	stddbg("curIdx pointer = %p", curBlk);
	return ( ((uint8_t*)(curBlk)) + sizeof(MemoryHeader_t) );
      } else {
	i++;
	prvBlk = curBlk;
	curBlk = (MemoryHeader_t*)(curBlk->nextBlk);
      }
    }

    atomic { memoryBusy = 0; }

    dbg( DBG_USR3, "QT: insert failed; not enough memory\n");
    return NULL;
  }



  command result_t QueryTableI.deleteQueryID(uint8_t qID) {
    uint8_t retVal = SUCCESS;
    MemoryHeader_t *nxtIdx, *prvIdx, *curIdx;
    QueryHeader_t* curHdr;

    atomic {
      if( memoryBusy == 0 )
	memoryBusy = 1;
      else
	retVal = FAIL;
    }

    if( retVal == FAIL )
      return FAIL;

    // Find the query with query ID qID and then find
    // the index of that query.
    prvIdx = (MemoryHeader_t*)memory;
    curIdx = (MemoryHeader_t*)(prvIdx->nextBlk);
    nxtIdx = (MemoryHeader_t*)(curIdx->nextBlk);

    curHdr = (QueryHeader_t*)((uint8_t*)(curIdx) + sizeof(MemoryHeader_t));

    stddbg("curIdx pointer = %p", curIdx);

    while( ((curHdr->queryID != qID) || (curIdx->inUse == 0))
	&& (nxtIdx->nextBlk != NULL) ) {
      stddbg("QT.delete: query ID is %d", curHdr->queryID);
      stddbg("curIdx pointer = %p", curIdx);

      prvIdx = curIdx;
      curIdx = nxtIdx;
      nxtIdx = (MemoryHeader_t*)(nxtIdx->nextBlk);

      curHdr = (QueryHeader_t*)((uint8_t*)(curIdx) + sizeof(MemoryHeader_t));
    }

    // No query found.
    //curHdr = (QueryHeader_t*)((uint8_t*)(curIdx)+sizeof(MemoryHeader_t));
    if( (curIdx->inUse == 0) || (curHdr->queryID != qID) ) {
      dbg( DBG_USR3, "QT: delete failed; no such query ID\n");
      atomic { memoryBusy = 0; }

      return FAIL;
    }

    // Normally you should check that curBlk lies within
    // the memory space that Qt manages, but since this
    // is an internal function I assume that I will call
    // it with a valid index.

    // Mark the block as no longer in use.
    curIdx->inUse = 0;

    // Defrag.
    if( ((uint8_t*)(nxtIdx) != &memory[QT_MEMORY_TOTAL - sizeof(MemoryHeader_t)])
	&& (nxtIdx->inUse == 0)
	&& ((uint8_t*)(curIdx) + curIdx->freeSpace + sizeof(MemoryHeader_t)
	  == (uint8_t*)(nxtIdx)) ) {
      curIdx->freeSpace += nxtIdx->freeSpace + sizeof(MemoryHeader_t);
      curIdx->nextBlk = nxtIdx->nextBlk;
    }

    if( ((uint8_t*)(prvIdx) != memory  ) && (prvIdx->inUse == 0)
	&& ((uint8_t*)(prvIdx) + prvIdx->freeSpace + sizeof(MemoryHeader_t)
	  == (uint8_t*)(curIdx)) ) {
      // prv block size increases by the size of cur's free
      // memory plus the 2 words that make cur's header.
      prvIdx->freeSpace += curIdx->freeSpace + sizeof(MemoryHeader_t);
      prvIdx->nextBlk = curIdx->nextBlk;
    }

    dbg( DBG_USR3, "QT: successful delete\n");

    // Defrag needs to keep interrupts off, so this is the earliest
    // they can be turned back on.
    atomic { memoryBusy = 0; }

    return SUCCESS;
  }


  command uint8_t* QueryTableI.requestByID(uint8_t qID) {
    uint8_t retVal = SUCCESS;
    MemoryHeader_t *curIdx, *nxtIdx;
    QueryHeader_t* curHdr;

    atomic {
      if( memoryBusy == 0 )
	memoryBusy = 1;
      else
	retVal = FAIL;
    }

    if( retVal == FAIL )
      return NULL;

    curIdx = (MemoryHeader_t*)(memory);
    nxtIdx = (MemoryHeader_t*)curIdx->nextBlk;
    curHdr = (QueryHeader_t*)( (uint8_t*)(curIdx) + sizeof(MemoryHeader_t) );
    while( ((curHdr->queryID != qID) || (curIdx->inUse == 0)) && (nxtIdx->nextBlk != 0) ) {
      curIdx = nxtIdx;
      curHdr = (QueryHeader_t*)( (uint8_t*)(curIdx) + sizeof(MemoryHeader_t) );
      nxtIdx = (MemoryHeader_t*)(nxtIdx->nextBlk);
    }

    // No query found.
    curHdr = (QueryHeader_t*)( (uint8_t*)(curIdx) + sizeof(MemoryHeader_t) );
    if( (curIdx->inUse == 0) || (curHdr->queryID != qID) ) {
      dbg( DBG_USR3, "QT: delete failed; no such query ID\n");
      atomic { memoryBusy = 0; }

      return NULL;
    }

    atomic { memoryBusy = 0; }

    return (uint8_t*)curHdr;
  }


  command uint8_t* QueryTableI.request(uint8_t sampID) {
    uint8_t retVal = SUCCESS;
    MemoryHeader_t* curIdx;
    QueryHeader_t* curHdr;
    QueryState_t* curSt;
    uint8_t sampIdCnt, i;

    atomic {
      if( memoryBusy == 0 )
	memoryBusy = 1;
      else
	retVal = FAIL;
    }

    if( retVal == FAIL )
      return NULL;

    // Find the query with sampling ID sampID and then find
    // the index of that query.
    stddbg("Memory = %p", memory);
    curIdx = (MemoryHeader_t*)(memory);
    for( curIdx = (MemoryHeader_t*)(curIdx->nextBlk); curIdx->nextBlk != NULL;
	curIdx = (MemoryHeader_t*)(curIdx->nextBlk) ) {
      stddbg("curidx = %p", curIdx);

      sampIdCnt = samplingIdCnt( curIdx );

      dbg( DBG_USR3,
	  "%s [%d] - curIdx = %p\n",
	  __FILE__,
	  __LINE__, curIdx );

      curHdr = (QueryHeader_t*)( ((uint8_t*)(curIdx)) + sizeof(MemoryHeader_t) );
      curSt = (QueryState_t*)( ((uint8_t*)(curHdr))
	  + curHdr->mnCnt + sizeof(QueryHeader_t));

      stddbg("QueryID = %d\n", curHdr->queryID);
      stddbg("QueryFlags = %d\n", curHdr->queryFlags);
      stddbg("mnCnt = %d\n", curHdr->mnCnt);

      stddbg("MasterBitMask = %d", curSt->masterBitMask);
      stddbg("SlaveBitMask = %d", curSt->slaveBitMask);

      stddbg("Sampling ID Cnt = %d, sampID = %d, compared to %d", sampIdCnt, sampID, curSt->samplingIDs[0]);


      for( i = 0; i < sampIdCnt; i++ ) {
	if( curSt->samplingIDs[i] == sampID ) {
	  atomic { memoryBusy = 0; }
	  return ((uint8_t*)(curHdr));
	}
      } // for( i = 1 to sampIdCnt )
    } // for( curIdx ... )

    atomic { memoryBusy = 0; }
    return NULL;
  }

  uint8_t samplingIdCnt( MemoryHeader_t* idx ) {
    uint8_t i, cnt;
    uint16_t mem;
    QueryHeader_t* qHdr;
    QueryState_t* qSt;

    qHdr = (QueryHeader_t*)( ((uint8_t*)(idx)) + sizeof(MemoryHeader_t) );
    qSt = (QueryState_t*)( ((uint8_t*)(qHdr))
	+ qHdr->mnCnt + sizeof(QueryHeader_t));

    // Make idx point to the list of available
    // measurement names. (the master bitmask).
    cnt = 0;

    mem = qSt->masterBitMask;
    // 16 is the maximum number of MNs.
    for( i = 0; i < 16; i++ ) {
      if( (mem & 0x0001) != 0 )
	cnt++;

      mem >>= 1;
    }
    return cnt;
  }

  command uint8_t QueryTableI.memread( uint8_t loc ) {
    if( loc < QT_MEMORY_TOTAL )
      return memory[ loc ];

    return 0;
  }
}
