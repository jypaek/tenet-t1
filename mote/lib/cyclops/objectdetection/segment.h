
#ifndef SEGMENT_H
#define SEGMENT_H

/****************Definitions***************/
enum {
  MAXIMUM_NUMBER_LISTS = 150,
  MEMORY_SIZE = 11264
};

//definition of a linked list node
typedef struct list_node {
    uint8_t col;
    uint8_t row;
    struct list_node *next;
} __attribute__ ((packed)) llnode; 

//definition of a linked list set
typedef struct linkedListSets
{
    llnode *linkedList;
    //The combination of memberNumber and maxRow enables fast filtering of the blobs that are one row distant, 
    //that is no longer have a chance of growing and their size is below blob threshold.
    //MaxCol, minRow, and minCol are provided to for easier access to the object that has been detected
    uint8_t minCol;
    uint8_t minRow;
    uint8_t maxCol;
    uint8_t maxRow; 
    uint16_t memberNumber;  
} __attribute__ ((packed)) linkedListSets; 
 
//Important note, we keep record zero for the background, in addition we keep record MAXIMUM_NUMBER_LISTS+1 for the
//link list of the small objects which are filtered and their linklist is now available for reuse. This way we do not
//let their memory be wasted if we want to reuse it. We call this zombie linked list!
//linkedListSets linkedListSet[MAXIMUM_NUMBER_LISTS+1]={{0,NULL}};

#endif

