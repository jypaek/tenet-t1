/**
 *
 */
module FSQueueM 
{
  provides interface FSQueue [volume_t volume];
  uses interface FSQueueUtil;
}
implementation
{
#include <FileList.h>
#include <Flash.h>
#include <PXAFlash.h>

    #define DBUFF_SIZE 0x8000
    uint8_t DataBuffer [DBUFF_SIZE];
    uint32_t BuffPtr;

    typedef struct
    {
      PendingRequest Request;
      list_ptr metaList;
    } FSTaskList;

    FSTaskList fsList;
    bool QueueInit = FALSE;

    command result_t FSQueue.queueInit[volume_t caller] ()
    {
      if (!(QueueInit))
      {
        INIT_LIST (&fsList.metaList);
        BuffPtr = 0;
        QueueInit = TRUE;
      }
      return SUCCESS;
    }

    result_t AddRequestToQ (PendingRequest* pr)
    {
      result_t res = SUCCESS;
      FSTaskList* tmpList;
      FSTaskList* tskList;

      tmpList = (FSTaskList*) malloc (sizeof(FSTaskList));
      if (tmpList != NULL)
      {
        MALLOC_DBG(__FILE__,"AddRequestToQ", tmpList, sizeof(FSTaskList));
        memcpy (&tmpList->Request, pr, sizeof(PendingRequest));
        atomic tskList = &fsList;
        add_node_to_tail (&(tmpList->metaList),&(tskList->metaList));
      }
      else
      {
        trace (DBG_USR1, " FS FATAL ERROR : Cannot allocate memory for FSQueue.\r\n");
        res = FAIL;
      }
      return res;
    }

    command result_t FSQueue.queueWrite[volume_t caller] (uint16_t blockId, uint16_t volId, void* data, uint32_t len)
    {
      PendingRequest pr;
      uint32_t buffOffset = 0x0;
      result_t res = SUCCESS;

      atomic buffOffset = BuffPtr;

      if ((buffOffset + len) >= DBUFF_SIZE)
      {
        trace (DBG_USR1,"FS ERROR: Cannot Queue Write Request, Data Buffer is full\r\n");
        return FAIL;
      }

      memcpy ((DataBuffer + buffOffset), data, len);
      atomic BuffPtr += len;

      pr.ReqType = WRITE_REQUEST;
      pr.BufferOffset = buffOffset;
      pr.CallerId = caller;
      pr.preq.wreq.ClientVolume = volId;
      pr.preq.wreq.ClientBlock = blockId;
      pr.preq.wreq.WrtAddr = 0x0;
      pr.preq.wreq.DataLen = len;

      res = AddRequestToQ (&pr);
      return res;
    }

    command result_t FSQueue.queueDelete[volume_t caller] (const uint8_t* filename)
    {
      PendingRequest pr;
      result_t res = SUCCESS;

      trace (DBG_USR1,"Queued DELETE, FileName %s.\r\n", filename);
      pr.ReqType = DELETE_REQUEST;
      pr.BufferOffset = 0x0;
      pr.CallerId = caller;
      memcpy (pr.preq.dreq.FileName, filename, FILE_NAME_SIZE);

      res = AddRequestToQ (&pr);
      return res;
    }

    command result_t FSQueue.queueOpen[volume_t caller] (uint16_t volId, const uint8_t* filename)
    {
      PendingRequest pr;
      result_t res = SUCCESS;

      trace (DBG_USR1,"Queued FILE OPEN, FileName %s.\r\n", filename);
      pr.ReqType = FOPEN_REQUEST;
      pr.BufferOffset = 0x0;
      pr.CallerId = caller;
      pr.preq.ocreq.ClientVolume = volId;
      memcpy (pr.preq.ocreq.FileName, filename, FILE_NAME_SIZE);

      res = AddRequestToQ (&pr);
      return res;
    }

    command result_t FSQueue.queueClose[volume_t caller] (uint16_t volId, const uint8_t* filename)
    {
      PendingRequest pr;
      result_t res = SUCCESS;

      trace (DBG_USR1,"Queued FILE CLOSE, FileName %s.\r\n", filename);
      pr.ReqType = FCLOSE_REQUEST;
      pr.BufferOffset = 0x0;
      pr.CallerId = caller;
      pr.preq.ocreq.ClientVolume = volId;
      memcpy (pr.preq.ocreq.FileName, filename, FILE_NAME_SIZE);

      res = AddRequestToQ (&pr);
      return res;
    }


    command result_t FSQueue.queueCreate[volume_t caller] (const uint8_t* filename, uint32_t size)
    {
      PendingRequest pr;
      result_t res = SUCCESS;

      trace (DBG_USR1,"Queued CREATE, FileName %s.\r\n", filename);
      pr.ReqType = CREATE_REQUEST;
      pr.BufferOffset = 0x0;
      pr.CallerId = caller;

      pr.preq.creq.FileSize = size;
      memcpy (pr.preq.creq.FileName, filename, FILE_NAME_SIZE);

      res = AddRequestToQ (&pr);
      return res;
    }

    result_t HandlePendingTasks (FSTaskList* aTask)
    {
      result_t res = SUCCESS;
      switch (aTask->Request.ReqType)
      {
        case WRITE_REQUEST:
        {
          uint8_t* SendBuff;
          if ((SendBuff = (uint8_t*) malloc(aTask->Request.preq.wreq.DataLen)) == NULL)
          {
            trace (DBG_USR1,"** FS ERROR **: Cannot Allocate memory for Write Request\r\n");
            return FAIL;
          }
          memcpy (SendBuff, (DataBuffer + (aTask->Request.BufferOffset)), aTask->Request.preq.wreq.DataLen);
          trace (DBG_USR1,"FS MSG: Handling Pending Write Request %d\r\n",aTask->Request.preq.wreq.ClientVolume);
          signal FSQueue.pendingReq[aTask->Request.CallerId] (aTask->Request.ReqType, SendBuff, &aTask->Request);
          free (SendBuff);
        }
        break;
        case CREATE_REQUEST:
          trace (DBG_USR1,"FS MSG: Handling Pending Create Request %d\r\n",aTask->Request.preq.wreq.ClientVolume);
          signal FSQueue.pendingReq[aTask->Request.CallerId] (aTask->Request.ReqType, NULL, &aTask->Request);
        break;
        case DELETE_REQUEST:
          trace (DBG_USR1,"FS MSG: Handling Pending Delete Request %s\r\n",aTask->Request.preq.dreq.FileName);
          signal FSQueue.pendingReq[aTask->Request.CallerId] (aTask->Request.ReqType, NULL, &aTask->Request);
        break;
        case FOPEN_REQUEST:
          trace (DBG_USR1,"FS MSG: Handling Pending FOPEN Request %s\r\n",aTask->Request.preq.dreq.FileName);
          signal FSQueue.pendingReq[aTask->Request.CallerId] (aTask->Request.ReqType, NULL, &aTask->Request);
        break;
        case FCLOSE_REQUEST:
          trace (DBG_USR1,"FS MSG: Handling Pending FCLOSE Request %s\r\n",aTask->Request.preq.dreq.FileName);
          signal FSQueue.pendingReq[aTask->Request.CallerId] (aTask->Request.ReqType, NULL, &aTask->Request);
        break;
        default:
          trace (DBG_USR1,"FS WARNING: Unknown task in the QUEUE %d\r\n",aTask->Request.ReqType);
          res = FAIL;
        break;
      }
      return res;
    }

    event void FSQueueUtil.eraseCompleted()
    {
      FSTaskList* tmpTask;
      FSTaskList* actTask;
      list_ptr *pos, *tmp;
      tmpTask = &fsList;
      if (!is_list_empty(&(tmpTask->metaList)))
      {
        for_each_node_in_list(pos, tmp, &(tmpTask->metaList))
        {
          trace (DBG_USR1,"FS MSG: Erase Completed, Performing Task \r\n");
          actTask = get_list_entry(pos, FSTaskList, metaList);
          HandlePendingTasks (actTask);
          FREE_DBG(__FILE__,"FSQueueUtil.eraseCompleted",actTask);
          delete_node(pos);
          free(actTask);
        }

        if (is_list_empty(&(tmpTask->metaList)))
        {
          trace (DBG_USR1,"FS Msg: FSTASKList is empty \r\n");
          atomic BuffPtr = 0x0;
        }
      }
    }

    default event void FSQueue.pendingReq[volume_t caller] (uint8_t request,void* data, PendingRequest* req){}
}
