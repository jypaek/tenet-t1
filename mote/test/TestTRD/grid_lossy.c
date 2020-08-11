
/**
 * Generate a simple n-by-m grid topology 'lossy.nss' file for TOSSIM
 *
 * @date Nov/17/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[])
{
    int i,j,k,l,row,col,id,next;
    FILE *fp;
    double lr = 0.0;
    if ((argc != 3) && (argc != 4)) {
        printf("Usage : lossy [row] [col] <lossrate>\n");
        exit(1);
    }
    if (argc == 4) lr = atof(argv[3]);
    fp = fopen("lossy.nss","w");
    row = atoi(argv[1]);
    col = atoi(argv[2]);
    //printf("row=%d, col=%d\n",row,col);
    for (i=0; i<row; i++) {
        for (j=0; j<col; j++) {
            id = (row*i)+j;
            for (k=0; k<row; k++) {
                for (l=0; l<col; l++) {
                    next = (row*k)+l;
                    if ((i==k)&&(j==(l-1)))
                        fprintf(fp,"%d:%d:%.1f\n",id,next,lr);
                    else if ((i==k)&&(j==(l+1)))
                        fprintf(fp,"%d:%d:%.1f\n",id,next,lr);
                    else if ((i==(k-1))&&(j==l))
                        fprintf(fp,"%d:%d:%.1f\n",id,next,lr);
                    else if ((i==(k+1))&&(j==l))
                        fprintf(fp,"%d:%d:%.1f\n",id,next,lr);
                    else if ((i!=k)||(j!=l))
                        fprintf(fp,"%d:%d:1\n",id,next);
                }
            }
        }
    }
    fclose(fp);
    printf("\n\"lossy.nss\" file generated successfully (%dx%d grid topology)\n\n", row, col);
}
