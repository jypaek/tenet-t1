
/**
 * @modified 7/2/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/
 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <stddef.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif
#include <unistd.h>
#include <time.h>

#include "cyapp_util.h"
#include "bmp.h"


/********************************************
 * functions storing results into files
 ********************************************/


void output_result_to_file(query_state_t *p, result_item_t *r) {
    char filename[50];
    int format = p->snapQ.type;  //msg->imageType;
    int x = p->snapQ.size.x;
    int y = p->snapQ.size.y; 
    unsigned int length = 0;
    time_t m_time = time(NULL);
    struct tm *tt = localtime(&m_time);

    printf("%02d:%02d:%02d ", tt->tm_hour, tt->tm_min, tt->tm_sec);
    printf("[Image] type: %2d, x: %3d, y: %3d\n", format, x, y); 

    /************ BW image ***********/
    if ((format == 16) || (format == 19)) {
        format = 0;
        length = x * y;
    /*********** COLOR image **********/
    } else if (format == 17) {
        format = 1;
        length = x * y * 3;
    }

    r->image_cnt++; //increase the image counter

    //sprintf(filename,"mote%03d_tid%03d_%03d", r->addr, p->tid, r->image_cnt);
    sprintf(filename,"mote%03d_tid%03d-%03d_%02d-%02d-%02d", 
                    r->addr, p->tid, r->image_cnt,
                    tt->tm_hour, tt->tm_min, tt->tm_sec);
        
    if (p->outputFormat == OUTPUT_FORMAT_BMP) {
        sprintf(filename,"%s.bmp", filename);
        printf(" ==> Save in Bitmap File %s\n", filename); 

        convert_data_to_bmp(r->buffer, format, x, y, filename);
    }
    else {
        FILE *fp1;
        int i;
        sprintf(filename,"%s.dat", filename);
        printf(" ==> Save in Data File %s\n", filename); 

        if ((fp1 = fopen (filename, "w")) == NULL)  // Open a file to save data
            printf("Data file error\n");

        // Fill the file with the data
        for (i = 0; i < length; i++) {
            fprintf(fp1,"%02hhx ", (unsigned char) r->buffer[i]);
            if ((i+1) % 16 == 0) fprintf(fp1,"\n");
        }
        fclose(fp1);
    }
}


void set_query_defaults(query_state_t *p) {
    p->tid              = 2;        // queryID
    p->nSignal          = NEURON_GET_IMAGE;
    p->outputFormat     = OUTPUT_FORMAT_BMP;

    set_snap_query_defaults(&p->snapQ);             // 128x128 B/W with Flash
    set_getImage_query_defaults(&p->getImageQ);     // takeNew, fragSize=40, 50pkts/sec
    set_activeEye_query_defaults(&p->activeQ);
    set_detect_query_defaults(&p->detectQ);
    set_getRle_query_defaults(&p->getRleQ);             // thresh = 20
    set_getPackBits_query_defaults(&p->getPackBitsQ);   // thresh = 20
    set_copy_query_defaults(&p->copyQ);                 // NEW -> 2
}


int parse_single_argument(char *argv[], int ind, query_state_t *p) {

/************ Generic options ***********/
    if (strncasecmp(argv[ind], "MODULE", 3) == 0) {
        ind++;
        if (strncasecmp(argv[ind], "GET_IMAGE", 7) == 0)
            p->nSignal = NEURON_GET_IMAGE;
        else if (strncasecmp(argv[ind], "SNAP", 4) == 0)
            p->nSignal = NEURON_SNAP_ONLY;
        else if (strncasecmp(argv[ind], "ACTIVE_EYE", 7) == 0)
            p->nSignal = NEURON_ACTIVE_EYE;
        else if (strncasecmp(argv[ind], "DETECT", 5) == 0)
            p->nSignal = NEURON_DETECT_OBJECT;
        else if (strncasecmp(argv[ind], "GET_RLE_IMAGE", 7) == 0)
            p->nSignal = NEURON_GET_RLE_IMAGE;
        else if (strncasecmp(argv[ind], "GET_PACKBITS_IMAGE", 7) == 0)
            p->nSignal = NEURON_GET_PACKBITS_IMAGE;
        else if (strncasecmp(argv[ind], "COPY_IMAGE", 7) == 0)
            p->nSignal = NEURON_COPY_IMAGE;
        else
            p->nSignal = atoi(argv[ind]);    //sets the neuron Module to call
    }
    else if (strncasecmp(argv[ind], "FORMAT", 4) == 0) {
        ind++;
        if (strncasecmp(argv[ind], "BMP", 3) == 0)
            p->outputFormat = OUTPUT_FORMAT_BMP;
        else if (strncasecmp(argv[ind], "DAT", 3) == 0)
            p->outputFormat = OUTPUT_FORMAT_DAT;
        else
            p->outputFormat = atoi(argv[ind]);
    }
    
/************ SNAP-ralated options ***********/
    else if (strncasecmp(argv[ind], "FLASH", 5) == 0) {
        p->snapQ.enableFlash = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "IMAGETYPE", 8) == 0) {
        ind++;
        if (strncasecmp(argv[ind], "COLOR", 3) == 0)
            p->snapQ.type = CYCLOPS_IMAGE_TYPE_RGB;
        else if (strncasecmp(argv[ind], "BW", 2) == 0)
            p->snapQ.type = CYCLOPS_IMAGE_TYPE_Y;
        else
            p->snapQ.type = atoi(argv[ind]);
    }
    else if (strncasecmp(argv[ind], "SIZE", 4) == 0) {
        p->snapQ.size.x = atoi(argv[++ind]);
        p->snapQ.size.y = atoi(argv[++ind]);
    }
    
/************ GET_IMAGE          options ***********/
/************ GET_RLE_IMAGE      options ***********/
/************ GET_PACKBITS_IMAGE options ***********/
    else if (strncasecmp(argv[ind], "IMAGEADDR", 8) == 0) {
        ind++;
        if (strncasecmp(argv[ind], "NEW", 3) == 0)
            p->getImageQ.imageAddr = 0;
        else if (strncasecmp(argv[ind], "FIRST", 5) == 0)
            p->getImageQ.imageAddr = 1;
        else if (strncasecmp(argv[ind], "SECOND", 5) == 0)
            p->getImageQ.imageAddr = 2;
        else if (strncasecmp(argv[ind], "THIRD", 5) == 0)
            p->getImageQ.imageAddr = 3;
        else
            p->getImageQ.imageAddr = atoi(argv[ind]);
        p->getRleQ.imageAddr = p->getImageQ.imageAddr;
        p->getPackBitsQ.imageAddr = p->getImageQ.imageAddr;
    }
    else if (strncasecmp(argv[ind], "REPORTRATE", 7) == 0) {
        p->getImageQ.reportRate = atoi(argv[++ind]);    //sets the reportRate
        p->getRleQ.reportRate = p->getImageQ.reportRate;
        p->getPackBitsQ.reportRate = p->getImageQ.reportRate;
    }
    else if (strncasecmp(argv[ind], "FRAGMENTSIZE", 7) == 0) {
        p->getImageQ.fragmentSize = atoi(argv[++ind]);
        p->getRleQ.fragmentSize = p->getImageQ.fragmentSize;
        p->getPackBitsQ.fragmentSize = p->getImageQ.fragmentSize;
    }
    else if (strncasecmp(argv[ind], "THRESH", 6) == 0) {
        p->getRleQ.threshold = atoi(argv[++ind]);
        p->getPackBitsQ.threshold = p->getRleQ.threshold;
    }
    
/************ ACTIVE EYE options ***********/
    else if (strncasecmp(argv[ind], "EYETYPE", 4) == 0) {
        ind++;
        if (strncasecmp(argv[ind], "GET", 3) == 0)
            p->activeQ.type = ACTIVE_EYE_GET_PARAMS;
        else if (strncasecmp(argv[ind], "SET", 3) == 0)
            p->activeQ.type = ACTIVE_EYE_SET_PARAMS;
        else
            p->activeQ.type = atoi(argv[ind]);
        // 0 = ACTIVE_EYE_GET_PARAMS, 1 = ACTIVE_EYE_SET_PARAMS;
    }
    else if (strncasecmp(argv[ind], "OFFSET", 5) == 0) {
        p->activeQ.cp.offset.x = atoi(argv[++ind]);
        p->activeQ.cp.offset.y = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "INPUT", 5) == 0) {
        p->activeQ.cp.inputSize.x = atoi(argv[++ind]);
        p->activeQ.cp.inputSize.y = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "TESTMODE", 5) == 0) {
        p->activeQ.cp.testMode = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "EXPOSURE", 5) == 0) {
        p->activeQ.cp.exposurePeriod = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "ANALOGRGB", 9) == 0) {
        p->activeQ.cp.analogGain.red= atoi(argv[++ind]);
        p->activeQ.cp.analogGain.green= atoi(argv[++ind]);
        p->activeQ.cp.analogGain.blue= atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "DIGITALRGB", 8) == 0) {
        p->activeQ.cp.digitalGain.red= atoi(argv[++ind]);
        p->activeQ.cp.digitalGain.green = atoi(argv[++ind]);
        p->activeQ.cp.digitalGain.blue = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "RUNTIME", 7) == 0) {
        p->activeQ.cp.runTime = atoi(argv[++ind]);
    }
    
/************ Detect options ***********/
    else if (strncasecmp(argv[ind], "DETECTTYPE", 3) == 0) {   // DET
        ind++;
        if (strncasecmp(argv[ind], "RUN_NEW", 7) == 0)
            p->detectQ.type = DETECT_RUN_NEW_IMG;
        else if (strncasecmp(argv[ind], "RUN_OLD", 7) == 0)
            p->detectQ.type = DETECT_RUN_OLD;
        else if (strncasecmp(argv[ind], "RESET_BACKGROUND", 7) == 0)
            p->detectQ.type = DETECT_SET_BACKGROUND;
        else if (strncasecmp(argv[ind], "SET_BACKGROUND", 7) == 0)
            p->detectQ.type = DETECT_SET_PARAM;
        else if (strncasecmp(argv[ind], "SET_PARAM", 7) == 0)
            p->detectQ.type = DETECT_RESET_BACKGROUND;
        else
            p->detectQ.type = atoi(argv[ind]);
        // 1=RUN_NEW_IMG, 3=RUN_ONLY, 3=RESET_BG, 4=SET_BG, 5=SET_PARAM
    }
    else if (strncasecmp(argv[ind], "SEGMENT", 4) == 0) {
        p->detectQ.use_segment = atoi(argv[++ind]);
    }
    else if (strncasecmp(argv[ind], "DETECTPARAM", 7) == 0) {
        p->detectQ.detectParam.RACoeff = atoi(argv[++ind]);
        p->detectQ.detectParam.skip = atoi(argv[++ind]);
        p->detectQ.detectParam.illCoeff = atoi(argv[++ind]);
        p->detectQ.detectParam.range = atoi(argv[++ind]);
        p->detectQ.detectParam.detectThresh = atoi(argv[++ind]);
    }

/************ Copy options ***********/
    else if (strncasecmp(argv[ind], "COPY", 4) == 0) {
        p->copyQ.fromImageAddr = atoi(argv[++ind]);
        p->copyQ.toImageAddr = atoi(argv[++ind]);
    }

/************ Unknown options ***********/
    else {
        printf("Unknown argument %s\n", argv[ind]);
        return -1;
    }
    return ind;
}


void check_img_size(query_state_t *p) {
    long int totalSize;

    /* 'snapQ' has image parameters */
    memcpy(&p->getImageQ.snapQ, &p->snapQ, sizeof(p->snapQ));
    memcpy(&p->detectQ.snapQ, &p->snapQ, sizeof(p->snapQ));
    memcpy(&p->getRleQ.snapQ, &p->snapQ, sizeof(p->snapQ));
    memcpy(&p->getPackBitsQ.snapQ, &p->snapQ, sizeof(p->snapQ));

    totalSize = get_image_size(p->snapQ.size.x, p->snapQ.size.y, p->snapQ.type);

    if (p->nSignal == NEURON_DETECT_OBJECT) {
        if ((p->detectQ.snapQ.size.x != p->detectQ.snapQ.size.y)  ||
            (p->detectQ.snapQ.type != CYCLOPS_IMAGE_TYPE_Y)) {
            printf("DETECT only supports B/W image with XSIZE==YSIZE<=128");
        }
        if (totalSize > 16384) {    // 128x128
            printf("ERROR! You've asked for too large image.\n");
            exit(0);
        }
    } else if (totalSize > 61000) {
        printf("ERROR! You've asked for too large image.\n");
        printf(" - (xsize*ysize*bytesPerPixel) should not exceed 61KB,\n");
        printf("   where bytesPerPixel is 1 for B/W, 3 for color images\n");
        exit(0);
    }
    if ((p->nSignal == NEURON_GET_IMAGE) ||
            (p->nSignal == NEURON_DETECT_OBJECT)) {
        p->numExpectedPkts = totalSize / p->getImageQ.fragmentSize;
        if (totalSize % p->getImageQ.fragmentSize != 0)
            p->numExpectedPkts++;
    } else if ((p->nSignal == NEURON_GET_RLE_IMAGE) || 
                (p->nSignal == NEURON_GET_PACKBITS_IMAGE)) {
        p->numExpectedPkts = 0;
    } else {
        /* active eye (set/get params) task expects one packet */
        p->numExpectedPkts = 1;
    }
}


void print_query_state(query_state_t *p) {
    /* print out the selected options, including defaults */

    if (p->nSignal == NEURON_GET_IMAGE) {
        printf("MODULE       = (%d) GET_IMAGE\n", p->nSignal);
        print_getImage_query(&p->getImageQ);
    }
    else if (p->nSignal == NEURON_SNAP_ONLY) {
        printf("MODULE       = (%d) SNAP_ONLY\n", p->nSignal);
        print_snap_query(&p->snapQ);
    }
    else if (p->nSignal == NEURON_ACTIVE_EYE) {
        printf("MODULE       = (%d) ACTIVE_EYE\n", p->nSignal);
        print_activeEye_query(&p->activeQ);
    }
    else if (p->nSignal == NEURON_DETECT_OBJECT) {
        printf("MODULE       = (%d) DETECT_OBJECT\n", p->nSignal);
        print_detect_query(&p->detectQ);
    }
    else if (p->nSignal == NEURON_GET_RLE_IMAGE) {
        printf("MODULE       = (%d) GET_RLE_IMAGE\n", p->nSignal);
        print_getRle_query(&p->getRleQ);
    }
    else if (p->nSignal == NEURON_GET_PACKBITS_IMAGE) {
        printf("MODULE       = (%d) GET_PACKBITS_IMAGE\n", p->nSignal);
        print_getPackBits_query(&p->getPackBitsQ);
    }
    else if (p->nSignal == NEURON_COPY_IMAGE) {
        printf("MODULE       = (%d) COPY_IMAGE\n", p->nSignal);
        print_copy_query(&p->copyQ);
    }
    else {
        printf("MODULE = ? (%d)\n", p->nSignal);
        exit(0);
    }
}


void print_cyclops_option_usage() {
    printf("\nOPTIONS:\n\n");
    printf("    MODULE <module>     : 'module' can be one of... 'GET_IMAGE', 'ACTIVE_EYE',\n");
    printf("                          'DETECT', 'GET_RLE', 'GET_PACKBITS', 'COPY_IMAGE'.\n");
    printf("                          (default: GET_IMAGE).\n");
    printf("\n");
    printf(" (basic image params)\n");
    printf("    IMAGETYPE <type>    : 'type' is either 'BW' or 'COLOR'. (default: %d)\n", CYCLOPS_IMAGE_TYPE_Y);
    printf("    SIZE   <x> <y>      : set image size to be x-by-y. (default: %d %d) (max: %d %d for BW).\n",
                                        DEFAULT_IMAGE_SIZE_X, DEFAULT_IMAGE_SIZE_Y,
                                        MAX_IMAGE_SIZE_X, MAX_IMAGE_SIZE_Y);
    printf("    FLASH  <on>         : whether (1 or 0) to turn on the flash light. (default: %d)\n", DEFAULT_SNAP_ENABLE_FLASH);
    printf("\n");
    printf(" (for transfering an image or compressed image)\n");
    printf("    FORMAT <format>     : file format to save image. either 'BMP' or 'DAT'. (default = BMP)\n");
    printf("    REPORTRATE <msec>   : when transfering image, inter-packet interval in millisec.\n");
    printf("                          (default = 20, which means 50pkts/sec)\n");
    printf("    FRAGMENTSIZE <size> : when transfering image, data size of each fragment (in bytes).\n");
    printf("                          (default: %d, limited by TOS_DATA_LENGTH)\n", DEFAULT_FRAGMENT_SIZE);
    printf("    IMAGEADDR <#>       : you can take and get a new image, but you can also\n");
    printf("                          read an old image from the memory. (default: NEW)\n");
    printf("                          '#' can be one of 'NEW', 'FIRST', 'SECOND', 'THIRD',\n");
    printf("\n");
    printf(" (for module == COPY_IMAGE)\n");
    printf("    COPY <from> <to>    : copy image <from> <to>, where <from> and <to> are\n");
    printf("                          logical address that has same semantics as IMAGEADDR;\n");
    printf("                          valid values are 0,1,2,3, where 0 means new image at 1.\n");
    printf("\n");
    printf(" (for module == ACTIVE_EYE)\n");
    printf("    EYETYPE <type>      : either 'GET' or 'SET' capture parameters\n");
    printf("\n");
    printf(" (for eyetype == SET)\n");
    printf("    OFFSET <x> <y>         : offsetx, offsety (default: %d %d)\n", 
                                        DEFAULT_CAPTURE_OFFSET_X, DEFAULT_CAPTURE_OFFSET_Y);
    printf("    INPUT  <x> <y>         : inputx, inputy   (default: %d %d)\n",
                                        DEFAULT_CAPTURE_INPUT_SIZE_X, DEFAULT_CAPTURE_INPUT_SIZE_Y);
    printf("    EXPOSURE <val>         : exposure         (default: %d)\n", 
                                        DEFAULT_CAPTURE_EXPOSURE_PERIOD);
    printf("    ANALOGRGB <r> <g> <b>  : analog gain red, green, blue  (default: %d %d %d)\n",
                                        DEFAULT_CAPTURE_ANALOG_GAIN_RED,
                                        DEFAULT_CAPTURE_ANALOG_GAIN_GREEN,
                                        DEFAULT_CAPTURE_ANALOG_GAIN_BLUE);
    printf("    DIGITALRGB <r> <g> <b> : digital gain red, green, blue (default: %d %d %d)\n",
                                        DEFAULT_CAPTURE_DIGITAL_GAIN_RED,
                                        DEFAULT_CAPTURE_DIGITAL_GAIN_GREEN,
                                        DEFAULT_CAPTURE_DIGITAL_GAIN_BLUE);
    printf("    RUNTIME <val>          : run time (default: %d)\n", DEFAULT_CAPTURE_RUN_TIME);
    printf("\n");
    printf(" (for module == DETECT)\n");
    printf("    DETECTTYPE <type>   : 'type' can be one of 'RUN_NEW', 'RUN_OLD', 'SET_PARAM'\n");
    printf("                          'SET_BACKGROUND', 'RESET_BACKGROUND'. (default: RUN_NEW)\n");
    printf("\n");
    printf(" (for detecttype == SET_PARAM)\n");
    printf("    DETECTPARAM <RACoeff> <skip> <illCoeff> <range> <thresh>\n");
    printf("                        : set detection parameters for object detection alg.\n");
    printf("                          (default: %d %d %d %d %d)\n", DEFAULT_DETECT_RACOEFF, 
                                        DEFAULT_DETECT_ILLCOEFF, DEFAULT_DETECT_SKIP, 
                                        DEFAULT_DETECT_RANGE, DEFAULT_DETECT_THRESH);
    printf("\n");
    printf(" (for module == GET_RLE || GET_PACKBITS)\n");
    printf("    THRESH <thresh>     : threshold value for lossy run-length encoding (default: %d)\n", DEFAULT_RLE_THRESH);
    printf("\n");
}


/********************************************
 * functions for the list of received result
 ********************************************/
struct result_item *add_outitem(result_item_t **outlist_ptr, unsigned int addr) {
    struct result_item *c = malloc(sizeof(struct result_item));
    if (c == NULL) {
        fprintf(stderr, "FatalError: Not enough memory, failed to malloc!\n");
        exit(1);
    }
    memset(c, 0, sizeof(struct result_item));    // clear buffer

    c->next = *outlist_ptr;
    *outlist_ptr = c;
    c->addr = addr;
    return c;
}

struct result_item *find_outitem(result_item_t *outlist, unsigned int addr) {
    struct result_item *c;
    for (c = outlist; c; c = c->next) {
        if (c->addr == addr)
            return c;
    }
    return NULL;
}

void remove_outlist(result_item_t **outlist_ptr) {
    struct result_item **c;
    struct result_item *dead;
    for (c = outlist_ptr; *c; ) {
        dead = *c;
        *c = dead->next;
        dead->next = NULL;
        free(dead);
    }
}

