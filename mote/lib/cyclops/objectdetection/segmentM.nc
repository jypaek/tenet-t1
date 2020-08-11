
#include "segment.h"
#include "matrix.h"

module segmentM {
    provides interface segment;
}
implementation {

//What this library does is that it accepts an intensity matrix and converts it to segmented object matrix.
//The segmentation happens only for pixels above some intensity value. In addition it constantly filters those 
//segments that have their size below some threshold size of pixels.


/**************Psudeo Code****************/
//Note we sweep across the input matrix from (0,0) at top left corner all the way to the maxximum col and row 
//and analyze each pixel.
//Note L:left,T:top,TR:top right,TL:top left and G stands for the group the pixel belongs to

//TL   T   TR
//L  pixel 

//if (L)
//{
//join(G_L)
//if (T) merge(G_L,G_T)
//elseif (TR) merge(G_TR,G_L)
//}
//elseif (T)
//{
//    join(G_T)
//}
//elseif (TL)
//{
//join(G_TL)
//if (TR) merge(G_TL,G_TR)
//}
//elseif (TR) join(G_TR)
//else createGroup(pixel)
/******************************************/

    llnode *memStart;
    llnode *memIndex;
    linkedListSets* linkedListSet;
    uint16_t currentGroupNumber = 1; //we start with one as object group and 0 is the background group    
    uint16_t blobFiterThreshold;  //minimum size of an object in terms of the number of pixels.
    CYCLOPS_Matrix *objectMatrix;  //it stores the group number that the pixel belongs to

    static inline uint16_t getMemLocation(uint8_t row, uint8_t col) {
        return  (objectMatrix->cols)*row+col;
    }

    llnode *getllnode() {
        llnode *head;
        //checking if a new allocation exceeds the boundry of the memory
        if ((memIndex + sizeof(llnode)- memStart)> MEMORY_SIZE) return NULL;
        head = (llnode *) memIndex;
        memIndex = memIndex + sizeof(llnode);
        return head;
    }

    result_t create(uint8_t myrow, uint8_t mycol) {
        llnode *myllnode;
        myllnode = getllnode();
        if (myllnode == NULL) return FAIL;
        myllnode->row = myrow;
        myllnode->col = mycol;
        myllnode->next = NULL;
        //note that we assigned group zero to the background although we do not have a real link list for it. The 
        //fact that we start from zero is ok since we add one to it immidiately in the while loop.
        currentGroupNumber = 0;
        do {
            currentGroupNumber++;
        } while (currentGroupNumber<MAXIMUM_NUMBER_LISTS && linkedListSet[currentGroupNumber].linkedList!= NULL);

        //all records are filled up, let us filter the small groups now         
        if (currentGroupNumber == MAXIMUM_NUMBER_LISTS) return FAIL;
        //later we test this following logic to release memory

        objectMatrix->data.ptr8[getMemLocation(myrow,mycol)] = currentGroupNumber; //writing group number into the associated pixel
        linkedListSet[currentGroupNumber].linkedList = myllnode;  //recording the first link in the group
        linkedListSet[currentGroupNumber].memberNumber = 1;       //it now has one member
        linkedListSet[currentGroupNumber].maxRow = myrow;
        linkedListSet[currentGroupNumber].minRow = myrow;
        linkedListSet[currentGroupNumber].maxCol = mycol;
        linkedListSet[currentGroupNumber].minCol = mycol;
        return SUCCESS;

    }

    result_t join(uint8_t joinedGroup, uint8_t myrow, uint8_t mycol)
    {
        llnode *myllnode;
        myllnode = getllnode();
        if (myllnode == NULL) return FAIL;
        myllnode->row = myrow;
        myllnode->col = mycol;
        //writing group number into the associated pixel
        objectMatrix->data.ptr8[getMemLocation(myrow,mycol)] = joinedGroup;
        //inserting the link list node into the list
        if (linkedListSet[joinedGroup].linkedList->next == NULL) { //if it only has one element is a simple append
            linkedListSet[joinedGroup].linkedList->next = myllnode;
            myllnode->next = NULL;
        } else {  //but if it is more than one element we insert it into the link list
            myllnode->next = linkedListSet[joinedGroup].linkedList->next;
            linkedListSet[joinedGroup].linkedList->next = myllnode;
        }
        linkedListSet[joinedGroup].memberNumber += 1;

        if (myrow>linkedListSet[joinedGroup].maxRow) linkedListSet[joinedGroup].maxRow = myrow;       
        if (myrow<linkedListSet[joinedGroup].minRow) linkedListSet[joinedGroup].minRow = myrow;  
        if (mycol>linkedListSet[joinedGroup].maxCol) linkedListSet[joinedGroup].maxCol = mycol;
        if (mycol<linkedListSet[joinedGroup].minCol) linkedListSet[joinedGroup].minCol = mycol;

        return SUCCESS;
    }

    void merge(uint8_t group1,uint8_t group2)
    {   
        llnode *myllnode;
        llnode *lastllnode;
        //determining if the merge is needed and the group nmuber of the merged one
        if (group1 == group2) return;
        //we let smaller group join the larger group since it is computationaly cheaper
        if (linkedListSet[group1].memberNumber >= linkedListSet[group2].memberNumber)
        {     
            //save the link for the first element since we insert the other one here
            lastllnode = linkedListSet[group1].linkedList->next;
            linkedListSet[group1].linkedList->next = linkedListSet[group2].linkedList;
            myllnode = linkedListSet[group2].linkedList;
            while((myllnode->next)!= NULL) {   
                objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = group1;
                myllnode = myllnode->next;
            };
            //althought the next element is null but this is actualy the last valid link in the link list
            //so this one should also be regrouped. of course no more since next one is null.
            objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = group1;
            myllnode->next = lastllnode;
            linkedListSet[group1].memberNumber = linkedListSet[group1].memberNumber+linkedListSet[group2].memberNumber;
            linkedListSet[group1].maxRow = (linkedListSet[group1].maxRow > linkedListSet[group2].maxRow) ? linkedListSet[group1].maxRow : linkedListSet[group2].maxRow;
            linkedListSet[group1].minRow = (linkedListSet[group1].minRow < linkedListSet[group2].minRow) ? linkedListSet[group1].minRow : linkedListSet[group2].minRow;
            linkedListSet[group1].maxCol = (linkedListSet[group1].maxCol > linkedListSet[group2].maxCol) ? linkedListSet[group1].maxCol : linkedListSet[group2].maxCol;
            linkedListSet[group1].minCol = (linkedListSet[group1].minCol < linkedListSet[group2].minCol) ? linkedListSet[group1].minCol : linkedListSet[group2].minCol;

            linkedListSet[group2].linkedList = NULL;
            linkedListSet[group2].memberNumber = 0;
        }                                  
        else
        {                 
            //save the link for the first element since we insert the other one here
            lastllnode = linkedListSet[group2].linkedList->next;
            linkedListSet[group2].linkedList->next = linkedListSet[group1].linkedList;
            myllnode = linkedListSet[group1].linkedList;
            while((myllnode->next)!= NULL)            
            {   
                objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = group2;
                myllnode = myllnode->next;
            };
            //althought the next element is null but this is actualy the last valid link in the link list
            //so this one should also be regrouped. of course no more since next one is null.
            objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = group2;
            myllnode->next = lastllnode;

            linkedListSet[group2].memberNumber = linkedListSet[group2].memberNumber+linkedListSet[group1].memberNumber;
            linkedListSet[group2].maxRow = (linkedListSet[group2].maxRow > linkedListSet[group1].maxRow) ? linkedListSet[group2].maxRow : linkedListSet[group1].maxRow;
            linkedListSet[group2].minRow = (linkedListSet[group2].minRow < linkedListSet[group1].minRow) ? linkedListSet[group2].minRow : linkedListSet[group1].minRow;
            linkedListSet[group2].maxCol = (linkedListSet[group2].maxCol > linkedListSet[group1].maxCol) ? linkedListSet[group2].maxCol : linkedListSet[group1].maxCol;
            linkedListSet[group2].minCol = (linkedListSet[group2].minCol < linkedListSet[group1].minCol) ? linkedListSet[group2].minCol : linkedListSet[group1].minCol;        

            linkedListSet[group1].linkedList = NULL;
            linkedListSet[group1].memberNumber = 0;
        }
    }

    void clearMatrix() {
        uint16_t clearIndex = 0; //index used for clearing the link list memory before and after the operatio.
        for (clearIndex = 1;clearIndex<MAXIMUM_NUMBER_LISTS;clearIndex++)
        {
            llnode *myllnode;
            //if it is smaller than minimum blob size lets drop it
            if ((linkedListSet[clearIndex].linkedList != NULL) && (linkedListSet[clearIndex].memberNumber <= blobFiterThreshold))
            {
                myllnode = linkedListSet[clearIndex].linkedList;
                //we set every pixel in the object matrix to zero for the groups we remove
                while((myllnode->next)!= NULL)
                {
                    objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = 0;
                    myllnode = myllnode->next;
                }
                //we set every pixel in the object matrix to zero for the groups we remove
                objectMatrix->data.ptr8[getMemLocation(myllnode->row,myllnode->col)] = 0;
                linkedListSet[clearIndex].linkedList = NULL;
                linkedListSet[clearIndex].memberNumber = 0;
            }
        }
    }

    /**************Implementations*************/
    //As we traverse across the matrix we assign zero to the pixels that they are below threshold. 
    //This in fact means that zero is not belonging to any group. This save us from duplicating the input matrix.
    //****Note: this means that we should never join groups that have zeoro.
    command result_t segment.segment(CYCLOPS_Matrix* myObjectMatrix, linkedListSets* myllSet, llnode* mI, uint16_t myBlobFiterThreshold, uint8_t myThreshold)
    {
        uint8_t c,r; //column and row of the matrix
        uint16_t clearIndex = 0; //index used for clearing the link list memory before and after the operatio.
        objectMatrix = myObjectMatrix;
        currentGroupNumber = 1;

        //Instantiation of required structures
        memStart = mI;
        memIndex = mI;
        linkedListSet = myllSet;

        //initialization
        for (clearIndex = 0;clearIndex<MAXIMUM_NUMBER_LISTS;clearIndex++) {
            linkedListSet[clearIndex].linkedList = NULL; 
            linkedListSet[clearIndex].memberNumber = 0; 
            linkedListSet[clearIndex].maxRow = 0;
            linkedListSet[clearIndex].minRow = 0;
            linkedListSet[clearIndex].maxCol = 0;
            linkedListSet[clearIndex].minCol = 0;
        }
        blobFiterThreshold = myBlobFiterThreshold;

        //Do not need to clear matrix since no elements were created
        if (objectMatrix->depth != CYCLOPS_1BYTE) return FAIL;

        //The first element
        if (objectMatrix->data.ptr8[0] > myThreshold) {
            //Do not need to clear matrix since no elements were created
            if (create(0,0) == FAIL) return FAIL;
        }
        else
            objectMatrix->data.ptr8[0] = 0;
            
        //The first row , we treat it exceptionaly since it never causes any group join
        for (c = 1; c < (objectMatrix->cols); c++) {   
            if (objectMatrix->data.ptr8[c]>myThreshold) {
                if (objectMatrix->data.ptr8[c-1]) {
                    if (join(objectMatrix->data.ptr8[c-1],0,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                } else { 
                    if (create(0,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
            }
            else
                objectMatrix->data.ptr8[c] = 0;
        }
        //The rest of the rows
        for (r = 1; r < (objectMatrix->rows); r++) {            
            c = 0;
            //The first column we treat it spacialy
            if (objectMatrix->data.ptr8[getMemLocation(r,c)]>myThreshold) {
                //checking the top pixel
                if (objectMatrix->data.ptr8[getMemLocation(r-1,c)]) {
                    if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c)],r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
                //now checking the top right pixel
                else if (objectMatrix->data.ptr8[getMemLocation(r-1,c+1)]) {
                    if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c+1)],r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
                //well it has not neighbor, we create a new group for it
                else {
                    if (create(r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
            }
            else
                objectMatrix->data.ptr8[getMemLocation(r,c)] = 0;

            //all the mid column
            for (c = 1; c < (objectMatrix->cols-1); c++) {
                //This pixel is above the threshold so should join a group
                //here we determine the group that pixel belongs to
                //In addition, we merge those groups that this pixel connects
                if (objectMatrix->data.ptr8[getMemLocation(r,c)]>myThreshold) {
                    //checking for the left side pixel
                    if (objectMatrix->data.ptr8[getMemLocation(r,c-1)]) {
                        if (join(objectMatrix->data.ptr8[getMemLocation(r,c-1)],r,c) == FAIL) {
                            clearMatrix();
                            return FAIL;
                        }
                        //checking the top pixel to merge top and left 
                        if (objectMatrix->data.ptr8[getMemLocation(r-1,c)]) {
                            merge(objectMatrix->data.ptr8[getMemLocation(r-1,c)],objectMatrix->data.ptr8[getMemLocation(r,c-1)]);
                        }
                        //checking the top right pixel to merge top right and left
                        else if (objectMatrix->data.ptr8[getMemLocation(r-1,c+1)]) {
                            merge(objectMatrix->data.ptr8[getMemLocation(r-1,c+1)],objectMatrix->data.ptr8[getMemLocation(r,c-1)]);
                        }
                    }
                    //now checking the top pixel
                    else if (objectMatrix->data.ptr8[getMemLocation(r-1,c)]) {
                        if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c)],r,c) == FAIL) {
                            clearMatrix();
                            return FAIL;
                        }
                    }
                    //now checking the top left
                    else if (objectMatrix->data.ptr8[getMemLocation(r-1,c-1)]) {
                        if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c-1)],r,c) == FAIL) { 
                            clearMatrix();
                            return FAIL;
                        }
                        //checkign the top right  to merge top right and top left
                        if (objectMatrix->data.ptr8[getMemLocation(r-1,c+1)]) {
                            merge(objectMatrix->data.ptr8[getMemLocation(r-1,c+1)],objectMatrix->data.ptr8[getMemLocation(r-1,c-1)]);
                        }
                    }
                    //now checking the top right pixel
                    else if (objectMatrix->data.ptr8[getMemLocation(r-1,c+1)]) {
                        if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c+1)],r,c) == FAIL) {
                            clearMatrix();
                            return FAIL;
                        }
                    }
                    //well it has not neighbor, we create a new group for it
                    else {
                        if (create(r,c) == FAIL) {
                            clearMatrix();
                            return FAIL;
                        }
                    }
                }
                else objectMatrix->data.ptr8[getMemLocation(r,c)] = 0;
            }

            //The last column we again treat it spacialy
            c = (objectMatrix->cols)-1;
            if (objectMatrix->data.ptr8[getMemLocation(r,c)]>myThreshold) {
                //checking for the left side pixel
                if (objectMatrix->data.ptr8[getMemLocation(r,c-1)]) {
                    {
                        if (join(objectMatrix->data.ptr8[getMemLocation(r,c-1)],r,c) == FAIL) {
                            clearMatrix();
                            return FAIL;
                        }
                    }
                    //checking the top pixel to merge top and left
                    if (objectMatrix->data.ptr8[getMemLocation(r-1,c)]) {
                        merge(objectMatrix->data.ptr8[getMemLocation(r-1,c)],objectMatrix->data.ptr8[getMemLocation(r,c-1)]);
                    }
                }
                //now checking the top pixel
                else if (objectMatrix->data.ptr8[getMemLocation(r-1,c)]) {
                    if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c)],r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
                //now checking the top left
                else if (objectMatrix->data.ptr8[getMemLocation(r-1,c-1)]) {
                    if (join(objectMatrix->data.ptr8[getMemLocation(r-1,c-1)],r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
                //well it has not neighbor, we create a new group for it
                else {
                    if (create(r,c) == FAIL) {
                        clearMatrix();
                        return FAIL;
                    }
                }
            }
            else objectMatrix->data.ptr8[getMemLocation(r,c)] = 0;
        }
        clearMatrix();
        return SUCCESS;
    }

    command linkedListSets* segment.getObjectList() {
        return linkedListSet;
    }
}

