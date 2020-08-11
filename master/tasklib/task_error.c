/*
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
 */

/**
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * @modified Feb/16/2009
 **/
/**
 * This file contains functions to handle error Messages from Motes on Master side.
 * It usually prints which tasklet got an error and what type or error.
 */
#include <string.h>
#include <stdio.h>
#include <time.h>
#include "task_error.h"
#include "element_map.h"

char err_code_str[50];
char err_location_str[50];
uint16_t last_err_code = 0;
uint16_t last_err_loc = 0;
uint16_t last_err_loc2 = 0;

void print_error_attribute(FILE *fptr, attr_t *err) {
    error_report_t *r = (error_report_t *)err->value;

    fprintf(fptr, "#[ERROR] ");
    print_mote_error_code(fptr, r->err_code);
    fprintf(fptr, "@ ");
    print_mote_error_location(fptr, r->err_loc);
    if (r->err_loc2 != 0xffff) {
        if (r->err_code == ERR_INVALID_ATTRIBUTE)
            fprintf(fptr, " (ATTRIBUTE_TAG %d)", r->err_loc2);
        else
            fprintf(fptr, " (ELEMENT_INDEX %d)", r->err_loc2);
    }
    fprintf(fptr, "\n");
}

char* get_mote_error_code_string(uint16_t err_code) { 
    switch(err_code) {
        case ERR_INSTALL_FAILURE:
            sprintf(err_code_str, "ERR_INSTALL_FAILURE ");
            break;
        case ERR_CONSTRUCT_FAILURE:
            sprintf(err_code_str, "ERR_CONSTRUCT_FAILURE ");
            break;
        case ERR_INVALID_TASK_DESCRIPTION:
            sprintf(err_code_str, "ERR_INVALID_TASK_DESCRIPTION ");
            break;
        case ERR_INVALID_TASK_PARAMETER:
            sprintf(err_code_str, "ERR_INVALID_TASK_PARAMETER ");
            break;
        case ERR_MALLOC_FAILURE:
            sprintf(err_code_str, "ERR_MALLOC_FAILURE ");
            break;
        case ERR_INVALID_ATTRIBUTE:
            sprintf(err_code_str, "ERR_INVALID_ATTRIBUTE ");
            break;
        case ERR_INVALID_OPERATION:
            sprintf(err_code_str, "ERR_INVALID_OPERATION ");
            break;
        case ERR_NULL_TASK:
            sprintf(err_code_str, "ERR_NULL_TASK ");
            break;
        case ERR_NULL_ACTIVE_TASK:
            sprintf(err_code_str, "ERR_NULL_ACTIVE_TASK ");
            break;
        case ERR_RESOURCE_BUSY:
            sprintf(err_code_str, "ERR_RESOURCE_BUSY ");
            break;
        case ERR_RUNTIME_FAILURE:
            sprintf(err_code_str, "ERR_RUNTIME_FAILURE ");
            break;
        case ERR_NOT_SUPPORTED:
            sprintf(err_code_str, "ERR_NOT_SUPPORTED ");
            break;
        case ERR_MALFORMED_ACTIVE_TASK:
            sprintf(err_code_str, "ERR_MALFORMED_TASK ");
            break;
        case ERR_DATA_REMOVE:
            sprintf(err_code_str, "ERR_DATA_REMOVE ");
            break;
        case ERR_NO_ROUTE:
            sprintf(err_code_str, "ERR_NO_ROUTE ");
            break;
        case ERR_QUEUE_OVERFLOW:
            sprintf(err_code_str, "ERR_QUEUE_OVERFLOW ");
            break;
        case ERR_SENSOR_ERROR:
            sprintf(err_code_str, "ERR_SENSOR_ERROR ");
            break;
        case ERR_TIMESYNC_FAILURE:
            sprintf(err_code_str, "ERR_TIMESYNC_FAILURE ");
            break;
        default:
            sprintf(err_code_str, "!! UNKNOWN ERROR CODE (%d)!!", err_code);
            break;
    }
    return err_code_str;
}

void print_mote_error_code(FILE *fptr, uint16_t err_code) {
    fprintf(fptr, "%s", get_mote_error_code_string(err_code));
}

char* get_mote_error_location_string(uint16_t err_loc) {

    switch(err_loc) {
        case ELEMENT_INSTALL:
            sprintf(err_location_str, "TASK_INSTALLER ");
            break;
        case ELEMENT_GET:
            sprintf(err_location_str, "ELEMENT_GET ");
            break;
        case ELEMENT_COMPARISON:
            sprintf(err_location_str, "ELEMENT_COMPARISON ");
            break;
        case ELEMENT_STATS:
            sprintf(err_location_str, "ELEMENT_STATS ");
            break;
        case ELEMENT_SAMPLE:
            sprintf(err_location_str, "ELEMENT_SAMPLE ");
            break;
        case ELEMENT_FASTSAMPLE:
            sprintf(err_location_str, "ELEMENT_FASTSAMPLE ");
            break;
        case ELEMENT_USERBUTTON:
            sprintf(err_location_str, "ELEMENT_USERBUTTON ");
            break;
        case ELEMENT_REBOOT:
            sprintf(err_location_str, "ELEMENT_REBOOT ");
            break;
        case ELEMENT_COUNT:
            sprintf(err_location_str, "ELEMENT_COUNT ");
            break;
        case ELEMENT_SENDPKT:
            sprintf(err_location_str, "ELEMENT_SENDPKT ");
            break;
        case ELEMENT_SENDSTR:
            sprintf(err_location_str, "ELEMENT_SENDSTR ");
            break;
        case ELEMENT_SENDRCRT:
            sprintf(err_location_str, "ELEMENT_SENDRCRT ");
            break;
        case ELEMENT_SAMPLEMDA400:
            sprintf(err_location_str, "ELEMENT_SAMPLEMDA400 ");
            break;
        case ELEMENT_ONSETDETECTOR:
            sprintf(err_location_str, "ELEMENT_ONSETDETECTOR ");
            break;
        case ELEMENT_SAMPLERSSI:
            sprintf(err_location_str, "ELEMENT_SAMPLERSSI ");
            break;
        case ELEMENT_DELETEATTRIBUTEIF:
            sprintf(err_location_str, "ELEMENT_DELETEATTRIBUTEIF ");
            break;
        case ELEMENT_DELETEACTIVETASKIF:
            sprintf(err_location_str, "ELEMENT_DELETEACTIVETASKIF ");
            break;
        case ELEMENT_DELETETASKIF:
            sprintf(err_location_str, "ELEMENT_DELETETASKIF ");
            break;
        case ELEMENT_MEMORYOP:
            sprintf(err_location_str, "ELEMENT_MEMORYOP ");
            break;
        case ELEMENT_ISSUE:
            sprintf(err_location_str, "ELEMENT_ISSUE ");
            break;
        case ELEMENT_ACTUATE:
            sprintf(err_location_str, "ELEMENT_ACTUATE ");
            break;
        case ELEMENT_LOGICAL:
            sprintf(err_location_str, "ELEMENT_LOGICAL ");
            break;
        case ELEMENT_BIT:
            sprintf(err_location_str, "ELEMENT_BIT ");
            break;
        case ELEMENT_ARITH:
            sprintf(err_location_str, "ELEMENT_ARITH ");
            break;
        case ELEMENT_STORAGE:
            sprintf(err_location_str, "ELEMENT_STORAGE ");
            break;
        case ELEMENT_IMAGE:
            sprintf(err_location_str, "ELEMENT_IMAGE ");
            break;
        case ELEMENT_PACK:
            sprintf(err_location_str, "ELEMENT_PACK ");
            break;
        case ELEMENT_ATTRIBUTE:
            sprintf(err_location_str, "ELEMENT_ATTRIBUTE ");
            break;
        case ELEMENT_FIRLPFILTER:
            sprintf(err_location_str, "ELEMENT_FIRLPFILTER ");
            break;
        case ELEMENT_RLE:
            sprintf(err_location_str, "ELEMENT_RLE ");
            break;
        case ELEMENT_PACKBITS:
            sprintf(err_location_str, "ELEMENT_PACKBITS ");
            break;
        case ELEMENT_VECTOR:
            sprintf(err_location_str, "ELEMENT_VECTOR ");
            break;
        default:
            sprintf(err_location_str, "!! NOT REGISTERED ELEMENT ID (%d)!!", err_loc);
            break;
    }
    return err_location_str;
}

void print_mote_error_location(FILE *fptr, uint16_t err_loc) {
    fprintf(fptr, "%s", get_mote_error_location_string(err_loc));
}

uint16_t get_last_mote_error_code() {
    return last_err_code;
}

uint16_t get_last_mote_error_location() {
    return last_err_loc;
}

uint16_t get_last_mote_error_location2() {
    return last_err_loc2;
}

int check_error_response(unsigned char *packet) {
    if (packet) {
        attr_t *attr = (attr_t *)packet;
        if (attr->type == ERROR_ATTRIBUTE) {
            error_report_t *r = (error_report_t *)attr->value;
            last_err_code = r->err_code;
            last_err_loc = r->err_loc;
            last_err_loc2 = r->err_loc2;
            return 1;
        }
    }
    return 0;
}

int print_error_response(FILE *fptr, unsigned char *packet, int addr) {
    if (check_error_response(packet)) {
        attr_t *attr = (attr_t *)packet;
        time_t m_time = time(NULL);
        fprintf(fptr, "\n");
        fprintf(fptr, "%s ", asctime(localtime(&m_time)));
        fprintf(fptr, "[Node %d] ", addr);
        print_error_attribute(stderr, attr);
        return 1;
    }
    return 0;
}

