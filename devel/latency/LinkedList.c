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
 * Typical linked list.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "LinkedList.h"

struct LinkedList* NewLinkedList()
{
    struct LinkedList* pLinkedList = (struct LinkedList*) malloc( sizeof( struct LinkedList )) ;

    if ( pLinkedList )
    {
        pLinkedList->pListHead = NULL;
        pLinkedList->nCount = 0;
    }

    return pLinkedList;
}

void DeleteLinkedList( struct LinkedList* pLinkedList )
{
    while ( 1 )
    {
        if ( !Pop ( pLinkedList ) )
            break;
    }

    free( pLinkedList );
}

struct Node* FindNode( struct LinkedList* pLinkedList, int nID )
{
    struct Node* pNode = NULL;

    for ( pNode = pLinkedList->pListHead ; pNode ; pNode = pNode->pNextNode )
    {
        if ( pNode->nID == nID )
            return pNode;
    }

    return NULL;
}

int InsertNode( struct LinkedList* pLinkedList, int nID, long int nValue )
{
    if ( FindNode( pLinkedList, nID ) != NULL )
        return 0;

    struct Node* pNode = ( struct Node* ) malloc( sizeof ( struct Node ) );
    struct Node *prev, *next;

    pNode->nID = nID;
    pNode->nValue = nValue;
    pNode->pNextNode = NULL;

    if (pLinkedList->pListHead == NULL) {
        pLinkedList->pListHead = pNode;
    } else if (nValue < pLinkedList->pListHead->nValue) {
        pNode->pNextNode = pLinkedList->pListHead;
        pLinkedList->pListHead = pNode;
    } else {
        for (prev = pLinkedList->pListHead ; prev ; prev = prev->pNextNode) {
            next = prev->pNextNode;
            if ((next == NULL) || (nValue < next->nValue)) {
                prev->pNextNode = pNode;
                pNode->pNextNode = next;
                break;
            }
        }
    }

    pLinkedList->nCount++;

    return 1;
}

int RemoveNode( struct LinkedList* pLinkedList, int nID )
{
    struct Node* pNode = NULL;
    struct Node* pPrevNode = NULL;

    if ( !pLinkedList->pListHead )
        return 0;

    for ( pNode = pLinkedList->pListHead ; pNode ; pNode = pNode->pNextNode )
    {
        if ( pNode->nID == nID )
        {
            if ( pPrevNode )
                pPrevNode->pNextNode = pNode->pNextNode;

            if ( pNode == pLinkedList->pListHead )
                pLinkedList->pListHead = pNode->pNextNode;

            pLinkedList->nCount--;

            free ( pNode );
            return 1;
        }

        pPrevNode = pNode;
    }

    return 0;
}

struct Node* Pop( struct LinkedList* pLinkedList )
{
    static struct Node node;

    if ( !pLinkedList->pListHead )
        return NULL;

    node.nID = pLinkedList->pListHead->nID;
    node.nValue = pLinkedList->pListHead->nValue;

    RemoveNode( pLinkedList, pLinkedList->pListHead->nID );

    return &node;
}

long int GetValueOf( struct LinkedList* pLinkedList, int nID )
{
    struct Node* pNode = FindNode( pLinkedList, nID );

    if ( !pNode )
        return -1;

    return pNode->nValue;
}

int ChangeValueOf( struct LinkedList* pLinkedList, int nID, long int nValue )
{
    struct Node* pNode = FindNode( pLinkedList, nID );

    if ( !pNode )
        return -1;

    pNode->nValue = nValue;

    return pNode->nValue;
}

void PrintAllNodes( struct LinkedList* pLinkedList )
{
    struct Node* pNode = NULL;

    printf ( "\n>> ");

    for ( pNode = pLinkedList->pListHead ; pNode ; pNode = pNode->pNextNode )
    {
        printf( "(%d,%ld) ", pNode->nID, pNode->nValue );
    }

    printf ("\n");
}

void PrintAllValues( struct LinkedList* pLinkedList )
{
    struct Node* pNode = NULL;

    printf ( "\n>> ");

    for ( pNode = pLinkedList->pListHead ; pNode ; pNode = pNode->pNextNode )
    {
        printf( "%ld ", pNode->nValue );
    }

    printf ("\n");
}

#ifdef LIST_DEBUG
int main ( void )
{
    struct LinkedList* pLinkedList = NewLinkedList();
    struct Node* pNode = NULL;

    InsertNode( pLinkedList, 1, 1);
    PrintAllNodes( pLinkedList );
    RemoveNode( pLinkedList, 2 );
    PrintAllNodes( pLinkedList );
    RemoveNode( pLinkedList, 1 );
    PrintAllNodes( pLinkedList );

    InsertNode( pLinkedList, 1, 1);
    InsertNode( pLinkedList, 2, 2);
    InsertNode( pLinkedList, 3, 3);

    PrintAllNodes( pLinkedList );

    RemoveNode( pLinkedList, 2 );

    PrintAllNodes( pLinkedList );

    InsertNode( pLinkedList, 2, 2);

    PrintAllNodes( pLinkedList );

    RemoveNode( pLinkedList, 2 );

    PrintAllNodes( pLinkedList );


    RemoveNode( pLinkedList, 1 );

    PrintAllNodes( pLinkedList );

    printf(" lfshdfvb : %d \n", GetValueOf( pLinkedList, 3 ) );
    ChangeValueOf( pLinkedList, 3, 100 );
    printf(" lfshdfvb : %d \n", GetValueOf( pLinkedList, 3 ) );
    printf(" lfshdfvb : %d \n", GetValueOf( pLinkedList, 5 ) );

    RemoveNode( pLinkedList, 3 );

    InsertNode( pLinkedList, 1, 1);
    InsertNode( pLinkedList, 2, 2);
    InsertNode( pLinkedList, 3, 3);
    InsertNode( pLinkedList, 4, 4);
    InsertNode( pLinkedList, 5, 5);
    InsertNode( pLinkedList, 6, 6);
    /*
       while ( 1 )
       {
       pNode = Pop ( pLinkedList );

       if ( !pNode )
       break;

       printf ("sdlknvdfknb : %d, %d \n", pNode->nID, pNode->nValue );
       }

     */
    DeleteLinkedList( pLinkedList );

    return 0;
}
#endif
