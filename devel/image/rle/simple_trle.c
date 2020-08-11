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
 * For testing simple run-length encoding algorithm 
 * with run-value thresholding.
 *
 * @modified Feb/26/2009
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

FILE *finptr; 
FILE *foutptr;
unsigned char *outputBuf;

void print_usage(argv0) {
    printf("\nUsage: %s [-ud] [-t thresh] inputfile outfile\n\n", argv0);
    printf("    ex>: %s in.dat\n", argv0);
    printf("    ex>: %s -o out.dat in.dat\n\n", argv0);
    printf(" [options]\n");
    printf("    -u           : uncompress(decode), instead of compress(encode)\n");
    printf(" [encoding options]\n");
    printf("    -d           : (for encoding) 'input data' is in decimal, not hex.\n");
    printf("                   (default is hex for encoding. we always assume hex for decoding)\n");
    printf("    -t           : (for encoding) do lossy compression using threshold\n");
    exit(1);
}

unsigned char max8(unsigned char a, unsigned char b) { if (a > b) return a; return b; }
unsigned char min8(unsigned char a, unsigned char b) { if (a > b) return b; return a; }

int main(int argc, char ** argv) {

    char *inputfname;
    char *outputfname = NULL;

    int hex = 1;        // whether input data is in decimal or hex
    int decode = 0;
    char thresh = 0;

    int c;

    while ((c = getopt(argc, argv, "udt:")) != -1) {
        switch (c) {
            case 'd': hex = 0; break;
            case 'u': decode = 1; break;
            case 't': thresh = (char) atoi(optarg); break;
            default: print_usage(argv[0]);
        }
    }
    if (optind+1 < argc)
        outputfname = argv[optind+1];
    if (optind < argc)
        inputfname = argv[optind];
    else
        print_usage(argv[0]);

    if ((finptr = fopen(inputfname, "r")) == NULL) {
        printf("Input Data file error\n");
        print_usage(argv[0]);
    }

    if (outputfname == NULL) {
        foutptr = stdout;
    } else if ((foutptr = fopen (outputfname, "wb")) == NULL) {
        printf("Ouput Data file error\n");
        print_usage(argv[0]);
    }


    if (decode) {
        int ok1, ok2;
        unsigned char val;    // char
        unsigned char runlen;    // run length
        int codelen = 0;
        int rawlen = 0;

        while (1) {
            ok1 = fscanf(finptr, "%hhx ", &val);
            ok2 = fscanf(finptr, "%hhx ", &runlen);
            if (ok1 == EOF || ok2 == EOF) break;
            codelen += 2;

            while (runlen > 0) {
                fprintf(foutptr, "%02hhx ", val);
                if (++rawlen % 16 == 0) fprintf(foutptr, "\n");
                runlen--;
            }
        }
        fflush(foutptr);
        printf("\nDECODING... \n");
        printf(" INPUT_FILE      = %s\n", inputfname);
        printf(" OUTPUT_FILE     = %s\n", outputfname);
        printf(" CODE LENGTH     = %d\n", codelen);
        printf(" RAW DATA LENGTH = %d\n\n", rawlen);
    } else {
        int ok;
        unsigned char val;    // char
        unsigned char prev;
        unsigned char runlen;
        int codelen = 0;
        int rawlen = 0;
        unsigned long int sum;

        while(1) {
            if (hex) ok = fscanf(finptr,"%hhx ", &val);
            else ok = fscanf(finptr,"%hhd ", &val);
            if (ok == EOF) break;
            rawlen++;

            if (rawlen == 1) {
                runlen = 1;
                prev = val;
                sum = (unsigned long int) val;
            } else if ((val <= max8(prev, prev + thresh)) && (val >= min8(prev, prev - thresh))) {
                // if we have run long than max len
                if (runlen == 254) {
                    prev = (unsigned char)(sum / (unsigned long int)(runlen));
                    fprintf(foutptr, "%02hhx ", prev);
                    fprintf(foutptr, "%02hhx ", runlen);
                    codelen += 2;
                    if (codelen % 16 == 0) fprintf(foutptr, "\n");
                    runlen = 0;
                    prev = val;
                    sum = 0;
                }
                runlen++;
                sum += (unsigned long int) val;
            } else { /* no run */
                prev = (unsigned char)(sum / (unsigned long int)(runlen));
                fprintf(foutptr, "%02hhx ", prev);
                fprintf(foutptr, "%02hhx ", runlen);
                codelen += 2;
                if (codelen % 16 == 0) fprintf(foutptr, "\n");
                runlen = 1;
                prev = val;
                sum = (unsigned long int) val;
            }
        }
        /* write the left-overs */
        prev = (unsigned char)(sum / (unsigned long int)(runlen));
        fprintf(foutptr, "%02hhx ", prev);
        fprintf(foutptr, "%02hhx ", runlen);
        codelen += 2;
        if (codelen % 16 == 0) fprintf(foutptr, "\n");

        fflush(foutptr);
        printf("\nENCODING... \n");
        printf(" INPUT_FILE      = %s\n", inputfname);
        printf(" OUTPUT_FILE     = %s\n", outputfname);
        printf(" RAW DATA LENGTH = %d\n", rawlen);
        printf(" CODE LENGTH     = %d\n\n", codelen);
    }


    if (foutptr != stdout) fclose(foutptr);
    fclose(finptr);
    return 0;
}


