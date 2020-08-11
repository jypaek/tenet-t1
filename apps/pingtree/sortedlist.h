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
 * Header file for a simple sorted-linked-list of integers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/
 
#ifndef _SORTEDED_LIST_
#define _SORTEDED_LIST_

struct Node {
    int nID;
    long int nValue;
    struct Node* pNextNode;
};

struct sortedlist {
    struct Node* pListHead;
    int nCount;
};

struct sortedlist* sortedlist_create();
void sortedlist_delete(struct sortedlist* slist);

struct Node* sortedlist_find(struct sortedlist* slist, int nID);

int sortedlist_insert(struct sortedlist* slist, int nID, long int nValue);
int sortedlist_remove(struct sortedlist* slist, int nID);
struct Node* sortedlist_pop(struct sortedlist* slist);

long int sortedlist_getValue(struct sortedlist* slist, int nID);
int sortedlist_length(struct sortedlist* slist);

void sortedlist_print(struct sortedlist* slist);
void sortedlist_printMissing(struct sortedlist* slist);
void sortedlist_printValues(struct sortedlist* slist);

#endif
