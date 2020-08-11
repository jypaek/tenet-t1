
interface segment
{
    command result_t segment(CYCLOPS_Matrix* objMat, linkedListSets* myllSet, llnode* mI, uint16_t blobThresh, uint8_t myThresh);
    command linkedListSets* getObjectList();
}
