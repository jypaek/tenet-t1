/*
* "Copyright (c) 2006~2007 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * A simple sorted-linked-list of integers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "sortedlist.h"

struct sortedlist* sortedlist_create()
{
    struct sortedlist* slist = (struct sortedlist*) malloc(sizeof(struct sortedlist)) ;
    if (slist) {
        slist->pListHead = NULL;
        slist->nCount = 0;
    }
    return slist;
}

void sortedlist_delete(struct sortedlist* slist)
{
    while (1) {
        if (!sortedlist_pop (slist))
            break;
    }
    free(slist);
}

struct Node* sortedlist_find(struct sortedlist* slist, int nID)
{
    struct Node* pNode = NULL;
    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode) {
        if (pNode->nID == nID)
            return pNode;
    }
    return NULL;
}

int sortedlist_insert(struct sortedlist* slist, int nID, long int nValue)
{
    if (sortedlist_find(slist, nID) != NULL)
        return 0;

    struct Node *pNode = (struct Node*) malloc(sizeof (struct Node));
    struct Node *prev, *next;

    pNode->nID = nID;
    pNode->nValue = nValue;
    pNode->pNextNode = NULL;

    if (slist->pListHead == NULL) {
        slist->pListHead = pNode;
    } else if (nValue < slist->pListHead->nValue) {
        pNode->pNextNode = slist->pListHead;
        slist->pListHead = pNode;
    } else if ((nValue == slist->pListHead->nValue) && (nID < slist->pListHead->nID)) {
        pNode->pNextNode = slist->pListHead;
        slist->pListHead = pNode;
    } else {
        for (prev = slist->pListHead ; prev ; prev = prev->pNextNode) {
            next = prev->pNextNode;
            if ((next == NULL) || (nValue < next->nValue) || 
                ((nValue == next->nValue) && (nID < next->nID))) {
                prev->pNextNode = pNode;
                pNode->pNextNode = next;
                break;
            }
        }
    }
    slist->nCount++;

    return 1;
}

int sortedlist_remove(struct sortedlist* slist, int nID)
{
    struct Node* pNode = NULL;
    struct Node* pPrevNode = NULL;

    if (!slist->pListHead)
        return 0;

    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode)
    {
        if (pNode->nID == nID)
        {
            if (pPrevNode)
                pPrevNode->pNextNode = pNode->pNextNode;

            if (pNode == slist->pListHead)
                slist->pListHead = pNode->pNextNode;

            slist->nCount--;

            free (pNode);
            return 1;
        }

        pPrevNode = pNode;
    }

    return 0;
}

struct Node* sortedlist_pop(struct sortedlist* slist)
{
    static struct Node node;

    if (!slist->pListHead)
        return NULL;

    node.nID = slist->pListHead->nID;
    node.nValue = slist->pListHead->nValue;

    sortedlist_remove(slist, slist->pListHead->nID);

    return &node;
}

long int sortedlist_getValue(struct sortedlist* slist, int nID)
{
    struct Node* pNode = sortedlist_find(slist, nID);

    if (!pNode)
        return -1;

    return pNode->nValue;
}

int sortedlist_length(struct sortedlist* slist)
{
    return slist->nCount;
}

void sortedlist_print(struct sortedlist* slist)
{
    struct Node* pNode = NULL;

    printf("\n\n < Printing the sorted list > ");
    printf("  (num_nodes %d)\n\n", slist->nCount);

    printf (">> ");
    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode) {
        printf("(%d,%ld) ", pNode->nID, pNode->nValue);
    }
    printf ("\n\n");
}

void sortedlist_printMissing(struct sortedlist* slist)
{
    struct Node* pNode = NULL;
    int nextID;
    printf("\n\n < Printing the missing list > ");
    printf (">> ");
    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode) {
        if(pNode->pNextNode){
            nextID=pNode->nID+1;
            while(nextID!=pNode->pNextNode->nID){
                printf("%d ", nextID);
                nextID++;
            }
        }
    }
    printf ("\n\n");
}

void sortedlist_printValues(struct sortedlist* slist)
{
    struct Node* pNode = NULL;

    printf("\n\n < Printing the sorted list values > ");
    printf("  (num_nodes %d)\n\n", slist->nCount);

    printf (">> ");
    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode) {
        printf("%ld ", pNode->nValue);
        //if id is not continous print eol to easy missing node ids
        if((pNode->pNextNode)&&(pNode->pNextNode->nID!=pNode->nID+1)) printf("\n   ");
    }
    printf ("\n\n");
}

