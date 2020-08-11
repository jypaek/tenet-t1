
#include "segment.h"

module geometricM
{
    provides interface geometric;
}
implementation
{  
    uint8_t aspectresult[2];
    uint16_t compactresult[2];
    CYCLOPS_Matrix* m_mat;

    static inline uint16_t get_memloc(uint8_t row, uint8_t col) {
        return  (m_mat->cols)*row + col;
    }

    command uint16_t* geometric.getCompactRatio(uint8_t group, linkedListSets *objSet, CYCLOPS_Matrix* objMat) {
        uint8_t minRow, minCol, maxRow, maxCol;
        uint8_t rowCnt, colCnt;
        uint16_t boundarypixels = 0;
        uint16_t totalpixels = 0;

        //If there are no members, then simply return 0
        if (!objSet[group].memberNumber)
            return 0;

        m_mat = objMat;

        minRow = objSet[group].minRow;
        minCol = objSet[group].minCol;
        maxRow = objSet[group].maxRow;
        maxCol = objSet[group].maxCol;

        //We zero in on the object by using the minimums and maximums
        for (rowCnt = minRow; rowCnt <=  maxRow; rowCnt++) {
            for (colCnt = minCol; colCnt <=  maxCol; colCnt++) {
                //Special case if on boundary of zero-ed in matrix
                if ((rowCnt ==  minRow)||(rowCnt ==  maxRow)||(colCnt ==  minCol)||(colCnt ==  maxCol)) {
                    //If this pixel is part of the group, increment boundary pixels 
                    if (objMat->data.ptr8[get_memloc(rowCnt,colCnt)] ==  group) {
                        boundarypixels++;
                        totalpixels++;
                    }
                    continue;
                }

                //All other cases are the same: Check to see if pixel is part of the group.
                //If so, then check to see if it is surrounded by other members in the group.
                //If it is not, then it must be a boundary pixel.
                if (objMat->data.ptr8[get_memloc(rowCnt,colCnt)] ==  group) {
                    //increment total pixels
                    totalpixels++;
                    //Since pixel is part of group, check surrounding pixels
                    if (objMat->data.ptr8[get_memloc(rowCnt,colCnt-1)] !=  group) {
                        //If left pixel is not in group, we must have a boundary pixel.
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt,colCnt+1)] !=  group) {
                        //If right pixel is not in group, we must have a boundary pixel.
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt-1,colCnt)] !=  group) {
                        //If top pixel is not in goup, we must have a boundary pixel.
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt+1,colCnt)] !=  group) {
                        //If bottom pixel is not in group, we must have a boundary pixel
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt-1,colCnt-1)] !=  group) {
                        //If top left pixel is not in group, we must have a boundary pixel
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt-1,colCnt+1)] !=  group) {
                        //If top right pixel is not in group, we must have a boundary pixel
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt+1,colCnt-1)] !=  group) {
                        //If bottom left pixel is not in group, we must have a boundary pixel
                        boundarypixels++;
                    }
                    else if (objMat->data.ptr8[get_memloc(rowCnt+1,colCnt+1)] !=  group) {
                        //If bottom right pixel is not in group, we must have a boundary pixel
                        boundarypixels++;
                    }
                    else {
                        //We do not have a boundary pixel
                    }

                }        
            }
        }

        //Return a uint16_t version of exactRatio. This drops the
        //remaining unwanted decimal places. This is done to avoid
        //using floating point throughout the system.
        compactresult[0] = boundarypixels;
        compactresult[1] = totalpixels;
        return compactresult;
    }

    command uint8_t* geometric.getAspectRatio(uint8_t group, linkedListSets *objSet) {
        aspectresult[0] = objSet[group].maxRow - objSet[group].minRow;
        aspectresult[1] = objSet[group].maxCol - objSet[group].minCol;
        return aspectresult;
    }
}
