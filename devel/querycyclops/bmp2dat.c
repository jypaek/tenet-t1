
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "bmp.h"

FILE *finptr; 
FILE *foutptr; 
char *outputBuf;

void print_usage(argv0) {
    printf("\nUsage: %s input_bmp_file [output_dat_file]\n\n", argv0);
    printf("    ex>: %s in.bmp out.dat\n", argv0);
    exit(1);
}

int main(int argc, char ** argv) {

    char *inputfname;
    char *outputfname = NULL;

    int width, height;
    int format = 0;     // BW(0) or Color(1) image

    int totalsize;
    int c;
    int i;

    while ((c = getopt(argc, argv, "h")) != -1) {
        switch (c) {
            default: print_usage(argv[0]);
        }
    }
    if (optind+1 < argc)
        outputfname = argv[optind+1];
    if (optind < argc)
        inputfname = argv[optind];
    else
        print_usage(argv[0]);

    if (outputfname == NULL) {
        foutptr = stdout;
    } else if ((foutptr = fopen (outputfname, "wb")) == NULL) {
        printf("Ouput Data file error\n");
        print_usage(argv[0]);
    }

    totalsize = convert_bmp_to_dat(inputfname, &format, &width, &height, &outputBuf);

    if (totalsize < 0) {
        printf("ERROR!!!\n");
        exit(1);
    }

    for (i = 0; i < totalsize; i++) {
        fprintf(foutptr, "%02hhx ", outputBuf[i]);
        if ((i+1)%16 == 0) fprintf(foutptr, "\n"); 
    }

    printf("\n INPUT_BMP_FILE  = %s\n OUTPUT_DAT_FILE = %s\n", inputfname, outputfname);
    printf(  " WIDTH           = %d\n", width);
    printf(  " HEIGTH          = %d\n", height);
    printf(  " FORMAT          = %d\n", format);
    printf(  " LENGTH          = %d\n\n", totalsize);

    if (foutptr != stdout) fclose(foutptr);
    return 0;
}


