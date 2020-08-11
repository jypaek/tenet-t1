
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "bmp.h"

void print_usage(argv0) {
    printf("\nUsage: %s [-d] [-w width] [-h height] [-f format] inputfile outputfile\n\n", argv0);
    printf("    ex>: %s in.dat out.bmp\n", argv0);
    printf("    ex>: %s -w 128 -h 128 -f 0 in.dat out.bmp\n", argv0);
    printf(" [options]\n");
    printf("    -f <format>  : 0 = B/W(default), 1 = Color\n");
    printf("    -w <width>   : width of image (default = 128)\n");
    printf("    -g <height>  : height of image (default = 128)\n");
    printf("    -d           : 'input data' is in decimal, not hex.\n");
    exit(1);
}

int main(int argc, char ** argv) {

    FILE *finptr; 
    char *outputBuf;

    char *inputfname;
    char *outputfname = NULL;

    int width = 128;
    int height= 128;
    int format = 0;     // BW(0) or Color(1) image

    int hex = 1;

    int totalsize;
    int c;
    int i;

    while ((c = getopt(argc, argv, "w:h:f:d")) != -1) {
        switch (c) {
            case 'w': width = atoi(optarg); break;
            case 'h': height = atoi(optarg); break;
            case 'f': format = atoi(optarg); break;
            case 'd': hex = 0; break;
            default: print_usage(argv[0]);
        }
    }
    if (optind+1 < argc) {
        inputfname = argv[optind];
        outputfname = argv[optind+1];
    } else
        print_usage(argv[0]);

    if ((finptr = fopen(inputfname, "r")) == NULL) {
        printf("Input Data file error\n");
        print_usage(argv[0]);
    }

    /* Black/White image */
    if (format == 0)
        totalsize = width * height;
    /* COLOR image */
    else if (format == 1)
        totalsize = width * height * 3;

    /* read input file */
    outputBuf = (char *)malloc(totalsize);
    for (i = 0; i < totalsize; i++) {
        if (hex) fscanf(finptr,"%hhx ", &outputBuf[i]);
        else     fscanf(finptr,"%hhd ", &outputBuf[i]);
    }

    convert_data_to_bmp(outputBuf, format, width, height, outputfname);

    printf("\n INPUT_DAT_FILE  = %s\n OUTPUT_BMP_FILE = %s\n", inputfname, outputfname);
    printf(  " WIDTH           = %d\n", width);
    printf(  " HEIGTH          = %d\n", height);
    printf(  " FORMAT          = %d\n", format);
    printf(  " LENGTH          = %d\n\n", totalsize);

    fclose(finptr);
    return 0;
}


