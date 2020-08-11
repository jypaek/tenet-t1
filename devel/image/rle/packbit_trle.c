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
 * For testing "PackBits" run-length encoding algorithm 
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
    printf("\nUsage: %s [-ud] [-t thresh] inputfile [outfile]\n\n", argv0);
    printf("    ex>: %s in.dat\n", argv0);
    printf("    ex>: %s in.dat out.dat\n\n", argv0);
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
    int thresh = 0;

    int c;

    while ((c = getopt(argc, argv, "udt:")) != -1) {
        switch (c) {
            case 'd': hex = 0; break;
            case 'u': decode = 1; break;
            case 't': thresh = atoi(optarg); break;
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


/***************************************************************************
*               Packbits Encoding and Decoding Library
*
*   Purpose : Use packbits run length coding to compress and
*             decompress files.  This packbits variant begins each block of
*             data with the a byte header that is decoded as follows.
*
*             Byte (n)   | Meaning
*             -----------+-------------------------------------
*             0 ~ 127    | Copy the next n + 1 bytes
*             -127 ~ -1  | Make 1 - n copies of the next byte
*             -128       | Do nothing
***************************************************************************/

    /* DECODE */
    if (decode) {
        int ok;
        unsigned char val;      /* current character */
        int8_t lenbyte;         /* (signed) run/copy count */
        int runlen;             /* actual run length */
        int rawlen = 0;
        int codelen = 0;

        while (1) {
            ok = fscanf(finptr, "%hhx ", &lenbyte);
            if (ok == EOF) break;
            codelen++;
            
            if (lenbyte < 0) {
                runlen = 1 - (int)lenbyte;

                ok = fscanf(finptr, "%hhx ", &val);
                if (ok == EOF) {
                    fprintf(stderr, "Run block is too short!\n");
                    break;
                }
                codelen++;
                while (runlen > 0) {
                    fprintf(foutptr, "%02hhx ", val);
                    if (++rawlen % 16 == 0) fprintf(foutptr, "\n");
                    runlen--;
                }
            } else {
                /* we have a block of runlen + 1 symbols to copy */
                runlen = 1 + (int)lenbyte;
                while (runlen > 0) {
                    ok = fscanf(finptr, "%hhx ", &val);
                    if (ok == EOF) {
                        fprintf(stderr, "Copy block is too short!\n");
                        break;
                    }
                    codelen++;

                    fprintf(foutptr, "%02hhx ", val);
                    if (++rawlen % 16 == 0) fprintf(foutptr, "\n");
                    runlen--;
                }
            }
        }
        fflush(foutptr);
        printf("\nDECODING... \n");
        printf(" INPUT_FILE      = %s\n", inputfname);
        printf(" OUTPUT_FILE     = %s\n", outputfname);
        printf(" CODE LENGTH     = %d\n", codelen);
        printf(" RAW DATA LENGTH = %d\n\n", rawlen);
    } 
    /* ENCODE */
    else {
        #define MIN_RUN     2               /* minimum run length */
        #define MAX_RUN     128             /* maximum run length */
        #define MAX_READ    MAX_RUN+1       /* maximum characters to buffer */
        int ok;
        unsigned char val;      // current character
        unsigned char prevBuf[MAX_READ];
        int runlen = 0; 
        int codelen = 0;        /* length of encoded data */
        int rawlen = 0;         /* length of raw data */
        int j = 0;
        unsigned long int sum = 0;

        while(1) {
            if (hex) ok = fscanf(finptr,"%hhx ", &val);
            else ok = fscanf(finptr,"%hhd ", &val);
            if (ok == EOF) break;
            rawlen++;

            prevBuf[runlen] = val;
            runlen++;

            if (runlen >= MIN_RUN) {

                if ((val <= max8(prevBuf[runlen - MIN_RUN], prevBuf[runlen - MIN_RUN] + thresh)) && 
                    (val >= min8(prevBuf[runlen - MIN_RUN], prevBuf[runlen - MIN_RUN] - thresh))) { /* run */
                    unsigned char next;

                    if (runlen > MIN_RUN) {
                        fprintf(foutptr, "%02hhx ", (char)(runlen - MIN_RUN - 1));
                        if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                        for (j = 0; j < runlen - MIN_RUN; j++) {
                            fprintf(foutptr, "%02hhx ", prevBuf[j]);
                            if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                        }
                    }

                    sum = (unsigned long int)prevBuf[runlen - MIN_RUN];
                    sum += (unsigned long int)val;
                    val = prevBuf[runlen - MIN_RUN];
                    runlen = MIN_RUN;

                    while (1) {
                        if (hex) ok = fscanf(finptr,"%hhx ", &next);
                        else     ok = fscanf(finptr,"%hhd ", &next);
                        if (ok == EOF) break;
                        rawlen++;

                        if ((next > max8(val, val + thresh)) ||
                            (next < min8(val, val - thresh))) break;  // no more run
                        runlen++;                       // run continues
                        sum += (unsigned long int) next;
                        if (MAX_RUN == runlen) break;   // run is at max length
                    }

                    val = (unsigned char)(sum / (unsigned long int)(runlen));

                    /* write out encoded run length and run symbol */
                    fprintf(foutptr, "%02hhx ", (char)(1 - runlen));
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                    fprintf(foutptr, "%02hhx ", val);
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");

                    if ((ok != EOF) && (runlen != MAX_RUN)) {
                        /* make run breaker start of next buffer */
                        runlen = 1;
                        prevBuf[0] = next;
                    }
                    else { /* file or max run ends in a run */
                        runlen = 0;
                    }
                } else if (runlen == MAX_RUN + 1) {
                    int j;
                    fprintf(foutptr, "%02hhx ", (char)(MAX_RUN - 1));
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                    for (j = 0; j < MAX_RUN; j++) {
                        fprintf(foutptr, "%02hhx ", prevBuf[j]);
                        if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                    }

                    runlen = 1;                     /* start a new buffer */
                    prevBuf[0] = prevBuf[MAX_RUN];  /* copy excess to front of buffer */
                }
            }
        }
        /* write out last buffer */
        if (0 != runlen) {
            if (runlen <= MAX_RUN) { /* write out entire copy buffer */
                fprintf(foutptr, "%02hhx ", (char)(runlen - 1));
                if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                for (j = 0; j < runlen; j++) {
                    fprintf(foutptr, "%02hhx ", prevBuf[j]);
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                }
            } else {
                /* we read more than the maximum for a single copy buffer */
                fprintf(foutptr, "%02hhx ", (char)(MAX_RUN - 1));
                if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                for (j = 0; j < MAX_RUN; j++) {
                    fprintf(foutptr, "%02hhx ", prevBuf[j]);
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                }
                codelen += (1 + MAX_RUN);

                /* write out remainder */
                fprintf(foutptr, "%02hhx ", (char)(runlen - MAX_RUN - 1));
                if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                for (j = MAX_RUN; j < runlen; j++) {
                    fprintf(foutptr, "%02hhx ", prevBuf[j]);
                    if (++codelen % 16 == 0) fprintf(foutptr, "\n");
                }
            }
        }

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

