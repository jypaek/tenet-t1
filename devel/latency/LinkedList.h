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
 * Header file for a typical linked list.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/
 
#ifndef _LINKED_LIST_
#define _LINKED_LIST_
//#define LIST_DEBUG

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct Node
{
    int nID;
    long int nValue;
    struct Node*    pNextNode;
};

struct LinkedList
{
    struct Node* pListHead;
    int nCount;
};

struct LinkedList* NewLinkedList();
void DeleteLinkedList( struct LinkedList* pLinkedList );

struct Node* FindNode( struct LinkedList* pLinkedList, int nID );

int InsertNode( struct LinkedList* pLinkedList, int nID, long int nValue );
int RemoveNode( struct LinkedList* pLinkedList, int nID );
struct Node* Pop( struct LinkedList* pLinkedList );

long int GetValueOf( struct LinkedList* pLinkedList, int nID );
int ChangeValueOf( struct LinkedList* pLinkedList, int nID, long int nValue );

void PrintAllNodes( struct LinkedList* pLinkedList );
void PrintAllValues( struct LinkedList* pLinkedList );

#endif
