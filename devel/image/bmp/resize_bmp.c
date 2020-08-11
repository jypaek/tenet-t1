/**
 * "Copyright (c) 2006~2009 University of Southern California.
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
 **/

/**
 * Resize a bmp file
 *
 * @modified Feb/26/2009
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "bmp.h"

void print_usage(argv0) {
    printf("\nUsage: %s [options] inputfile outputfile\n\n", argv0);
    printf("    ex>: %s in.bmp out.bmp\n", argv0);
    printf("    ex>: %s -w 128 -h 128 in.bmp out.bmp\n", argv0);
    printf(" [options]\n");
    printf("    -w <width>    : width of image (default = half of input bmp)\n");
    printf("                    must be equal or smaller than width of input image.\n");
    printf("    -h <height>   : height of image (default = half of input bmp)\n");
    printf("                    must be equal or smaller than height of input image.\n");
    printf("    -x <offset x> : \n");
    printf("    -y <offset y> : \n");
    exit(1);
}


int main(int argc, char ** argv) {

    char *inputfname;
    char *outputfname = NULL;
    FILE *finptr; 
    FILE *foutptr; 
    char *inputBuf;
    char *outputBuf;

    int i_width = 0, i_height = 0;
    int o_width = 0, o_height = 0;
    int format = 0;     // BW(0) or Color(1) image
    int offsetx = 0, offsety = 0;

    int i_totalsize;
    int o_totalsize;
    int c;
    int ii, ij, oi, oj;

    while ((c = getopt(argc, argv, "w:h:x:y:")) != -1) {
        switch (c) {
            case 'w': o_width = atoi(optarg); break;
            case 'h': o_height = atoi(optarg); break;
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
    if ((foutptr = fopen (outputfname, "wb")) == NULL) {
        printf("Ouput Data file error\n");
        print_usage(argv[0]);
    }

    i_totalsize = convert_bmp_to_dat(inputfname, &format, &i_width, &i_height, &inputBuf);

    if (i_totalsize < 0) {
        printf("ERROR!!!\n");
        exit(1);
    }
   
    /* output size cannot be larger than input */
    if (i_width < o_width) o_width = i_width;
    if (i_height < o_height) o_height = i_height;

    /* if output size not specified, default is half */
    if (o_width == 0) o_width = i_width/2;
    if (o_height == 0) o_height = i_height/2;

    /* offset should not go out of bound */
    if (i_width < offsetx + o_width) offsetx = i_width - o_width;
    if (i_height < offsetx + o_height) offsetx = i_height - o_height;

    /* Black/White image */
    if (format == 0)
        o_totalsize = o_width * o_height;
    /* COLOR image */
    else if (format == 1)
        o_totalsize = o_width * o_height * 3;

    outputBuf = (char *)malloc(o_totalsize);


    /* copy data */
    oi = 0;
    for (ii = offsety; ii < i_height; ii++) {
        oj = 0;
        for (ij = offsetx; ij < i_width;) {
            outputBuf[oi*o_width + oj++] = inputBuf[ii*i_width + ij++];
            if (format == 1) {
                outputBuf[oi*o_width + oj++] = inputBuf[ii*i_width + ij++];
                outputBuf[oi*o_width + oj++] = inputBuf[ii*i_width + ij++];
            }
        }
        oi++;
    }

    convert_data_to_bmp(outputBuf, format, o_width, o_height, outputfname);


    printf("\n INPUT_BMP_FILE  = %s\n OUTPUT_BMP_FILE = %s\n\n", inputfname, outputfname);
    printf(  " WIDTH     = %3d   -->   %3d\n", i_width, o_width);
    printf(  " HEIGTH    = %3d   -->   %3d \n", i_height, o_height);
    printf(  " FORMAT    = %d\n", format);
    printf(  " SIZE      = %5d --> %5d\n\n", i_totalsize, o_totalsize);

    fclose(finptr);
    fclose(foutptr);
    return 0;
}


