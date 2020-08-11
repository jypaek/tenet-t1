/*
* "Copyright (c) 2006 University of Southern California.
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
 * This file contans the functions to manipulate Response struct.
 * Response struct is what the application layer receives from the network.
 * Response is a list of attr_node (attributes).
 */

/**
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 * @modified 7/2/2007
 * Embedded Networks Laboratory, University of Southern California
 **/

#include "response.h"

response* response_create(int tid, int mote_addr) {
    response *list = (response *) malloc(sizeof(response));
    if (list) {
        list->head = NULL;
        list->length = 0;
        list->tid = tid;
        list->mote_addr = mote_addr;
    }
    return list;
}

void response_delete(response* list) {
    while (1) {
        if (!response_pop (list))
            break;
    }
    free(list);
}

attr_node* response_find(response* list, int type) {
    attr_node* pattr_node = NULL;
    for (pattr_node = list->head; pattr_node; pattr_node = pattr_node->next) {
        if (pattr_node->type == type)
            return pattr_node;
    }
    return NULL;
}

/* the response is sorted by type when inserting a new responsenode */
int response_insert(response* list, int type, int* value, int nelements) {
    //response can have same type
    //if (response_find(list, type) != NULL) return 0;
    attr_node *pattr_node = (attr_node*) malloc(sizeof (attr_node));
    attr_node *prev, *next;

    pattr_node->type = type;
    pattr_node->value = (int*)malloc(sizeof(int)*nelements);
    memcpy(pattr_node->value, value, sizeof(int)*nelements);
    pattr_node->length = nelements;
    pattr_node->next = NULL;

    if (list->head == NULL) {
        list->head = pattr_node;
    } else if (type < list->head->type) {
        pattr_node->next = list->head;
        list->head = pattr_node;
    } else {
        for (prev = list->head; prev; prev = prev->next) {
            next = prev->next;
            if ((next == NULL) || (type < next->type)) {
                prev->next = pattr_node;
                pattr_node->next = next;
                break;
            }
        }
    }
    list->length++;
    return 1;
}

int response_remove(response* list, int type) {
    attr_node* pattr_node = NULL;
    attr_node* pPrevattr_node = NULL;

    if (!list->head)
        return 0;

    for (pattr_node = list->head; pattr_node; pattr_node = pattr_node->next) {
        if (pattr_node->type == type) {        
            if (pPrevattr_node)
                pPrevattr_node->next = pattr_node->next;
            if (pattr_node == list->head)
                list->head = pattr_node->next;
            list->length--;
            free(pattr_node->value);
            free(pattr_node);
            return 1;
        }
        pPrevattr_node = pattr_node;
    }
    return 0;
}

attr_node* response_pop(response* list) {
    static attr_node node;
    if (!list->head)
        return NULL;

    node.type = list->head->type;
    node.value = list->head->value;

    response_remove(list, list->head->type);
    return &node;
}

int response_length(response* list) {
    return list->length;
}

int response_tid(response* list) {
    return list->tid;
}

int response_mote_addr(response* list) {
    return list->mote_addr;
}

void response_print(response* list) {
    attr_node* pattr_node=NULL;
    int i;

    printf("node = %d attributes = %d\n",list->mote_addr,list->length);

    for (pattr_node = list->head ; pattr_node ; pattr_node = pattr_node->next) {
        printf("\ttype = %d length = %d values = ",pattr_node->type, pattr_node->length);
        for (i = 0; i < pattr_node->length; i++)
            printf(" %d",pattr_node->value[i]);
        printf("\n");
    }
}

