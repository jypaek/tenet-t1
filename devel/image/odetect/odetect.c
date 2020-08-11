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
 * For testing background subtraction based object detection algorithm.
 *
 * @modified Feb/26/2009
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "image.h"
#include "ObjectDetectionM.h"
#include "segmentM.h"


int m_use_segment = 0;
uint8_t  img_type = CYCLOPS_IMAGE_TYPE_Y;
uint16_t img_size_x = 128;  // fixed in the motes!!
uint16_t img_size_y = 128;

uint8_t new_img[128*128];
uint8_t bg_img[128*128];
uint8_t fg_img[128*128];
uint8_t ll[128*128];


void print_usage(argv0) {
    printf("\nUsage: %s [-d] [-t thresh] inputfile1 inputfile2\n\n", argv0);
    printf("    ex>: %s in1.dat in2.dat\n\n", argv0);
    printf(" [options]\n");
    printf("    -d           : (for encoding) 'input data' is in decimal, not hex.\n");
    printf("                   (default is hex for encoding. we always assume hex for decoding)\n");
    printf("    -t           : (for encoding) do lossy compression using threshold\n");
    exit(1);
}

int main(int argc, char ** argv) {

    FILE *fin1ptr; 
    FILE *fin2ptr; 

    char *inputfname1;
    char *inputfname2;

    int hex = 1;        // whether input data is in decimal or hex

    int success;
    int i;
    int c;

    while ((c = getopt(argc, argv, "d")) != -1) {
        switch (c) {
            case 'd': hex = 0; break;
            default: print_usage(argv[0]);
        }
    }
    if (optind+1 < argc) {
        inputfname1 = argv[optind];
        inputfname2 = argv[optind+1];
    } else
        print_usage(argv[0]);

    if ((fin1ptr = fopen(inputfname1, "r")) == NULL) {
        printf("Input Data file error 1\n");
        print_usage(argv[0]);
    } else if ((fin2ptr = fopen(inputfname2, "r")) == NULL) {
        printf("Input Data file error 2\n");
        print_usage(argv[0]);
    }

    printf(" IN: %s, IN: %s\n\n",
            inputfname1, inputfname2);

    i = 0;

    while(1) {
        unsigned char a, b;
        int ok1, ok2;
        if (hex) {
            ok1 = fscanf(fin1ptr,"%hhx ", &a);
            ok2 = fscanf(fin2ptr,"%hhx ", &b);
        } else {
            ok1 = fscanf(fin1ptr,"%hhd ", &a);
            ok2 = fscanf(fin2ptr,"%hhd ", &b);
        }
        if (ok1 == EOF || ok2 == EOF)
            break;

        if (i == 128*128) {
            printf("Err: currently limited to 128x128 image!!\n");
            exit(1);
        }
        
        new_img[i] = a;
        bg_img[i] = b;

        i++;

        //fprintf(stdout, "%02hhx ", (unsigned char)(a - b));
        //if (i%16 == 0)
        //   fprintf(stdout, "\n"); 
        
    }

    ObjectDetection_init(new_img, bg_img, fg_img, ll);

    ObjectDetection_setImgRes(img_size_x, img_size_y, img_type);

    if (m_use_segment) 
        success = ObjectDetection_detect(1);
    else             
        success = ObjectDetection_detect(0);
    //if (success) segSuccess = ObjectDetection_getSegmentResult();

    printf("\nObject Detection Result >> \n");
    if (success)
        printf("\n### Detected!!!\n\n");
    else
        printf("\n### Not detected.\n\n");
        

    fclose(fin1ptr);
    fclose(fin2ptr);
    return 0;
}



