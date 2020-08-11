

/**
 * This file provides the structures and the functions for using a list of sequence numbers.
 * 
 * The list is specifically for the transport layer since it assumes that
 * sequence number is uint16_t, and there is another uint8_t identifier for cid.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _TR_LIST_H_
#define _TR_LIST_H_

/*
    "TR_List"
        - To use the tr_list, you must do the following.
            - Declare a tr_list:            "tr_list slist;"
            - Declare tr_listEntry array:    "tr_listEntry sle[SIZE];"
            - Call initialization function:        "tr_list_init(&slist, sle, SIZE);"
                - This allocates(links) memory:    "slist->item = sle"
        - We can make multiple instances of tr_lists using this method.
*/


    typedef struct tr_listEntry {
        uint8_t id;
        uint16_t seqno;
    } tr_listEntry;

    typedef struct tr_list {
        uint8_t headPtr;
        uint8_t tailPtr;
        uint8_t length;
        uint8_t    listSize;
        tr_listEntry *item;
    } tr_list;

    result_t tr_list_init(tr_list *slist, tr_listEntry *buf, uint8_t list_size) {
        if (list_size > 250) // cannot be 255
            return FAIL;
        slist->item = buf;
        slist->listSize = list_size;
        slist->headPtr = 0;
        slist->tailPtr = 0;
        slist->length = 0;
        return SUCCESS;
    }                                                             

    int tr_list_findIndex(tr_list *slist, uint8_t id, uint16_t seqno) {
        int i;
        if (slist->length == 0)
            return -1;
        i = (int)slist->tailPtr;
        do  {
            if ((slist->item[i].id == id) 
                && (slist->item[i].seqno == seqno))
                return i;
            i++;
            if (i == slist->listSize)
                i = 0;
        } while (i != slist->headPtr);
        return -1;
    }

    bool tr_list_isInList (tr_list *slist, uint8_t id, uint16_t seqno) {
        if (tr_list_findIndex(slist, id, seqno) < 0)
            return FALSE;
        else
            return TRUE;
    }

    void tr_list_clearID(tr_list *slist, uint8_t id) {
        int i;
        if (slist->length == 0)
            return;
        i = (int)slist->tailPtr;
        do  {
            if (slist->item[i].id == id) {
                slist->item[i].id = slist->item[slist->tailPtr].id;
                slist->item[i].seqno = slist->item[slist->tailPtr].seqno;
                slist->tailPtr++;
                if (slist->tailPtr == slist->listSize)
                    slist->tailPtr = 0;
                slist->length--;
            }
            i++;
            if (i == slist->listSize)
                i = 0;
        } while (i != slist->headPtr);
        return;
    }

    bool tr_list_isIdInList(tr_list *slist, uint8_t id) {
        int i;
        if (slist->length == 0)
            return FALSE;
        i = (int)slist->tailPtr;
        do  {
            if (slist->item[i].id == id) 
                return TRUE;
            i++;
            if (i == slist->listSize)
                i = 0;
        } while (i != slist->headPtr);
        return FALSE;
    }

    void tr_list_insert(tr_list *slist, uint8_t id, uint16_t seqno) {
        if (slist->length < slist->listSize) {
            if (tr_list_findIndex(slist, id, seqno) < 0) {
                slist->item[slist->headPtr].id = id;
                slist->item[slist->headPtr].seqno = seqno;
                slist->headPtr++;
                if (slist->headPtr == slist->listSize)
                    slist->headPtr = 0;
                slist->length++;
            }
        }
    }

    tr_listEntry* tr_list_deleteFirst(tr_list *slist) {
        tr_listEntry *sle = &slist->item[slist->tailPtr];
        if (slist->length == 0)
            return NULL;
        slist->tailPtr++;
        if (slist->tailPtr == slist->listSize)
            slist->tailPtr = 0;
        slist->length--;
        return sle;
    }

    bool tr_list_isFull(tr_list *slist) {
        if (slist->length == slist->listSize)
            return TRUE;
        else
            return FALSE;
    }

    bool tr_list_isEmpty(tr_list *slist) {
        if (slist->length == 0)
            return TRUE;
        else
            return FALSE;
    }

    tr_listEntry* tr_list_getFirst(tr_list *slist) {
        return &slist->item[slist->tailPtr];
    }

#endif // _TR_LIST_H_

