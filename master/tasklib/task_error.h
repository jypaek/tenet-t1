/**
 * Header File for Handling error Messages from Motes on Master side.
 *
 */
#ifndef _TASK_ERROR_H_
#define _TASK_ERROR_H_

#include <stdio.h>
#include "nx.h"
#include "common.h"
#include "tenet_task.h"

void print_error_attribute(FILE *fptr, attr_t *err);

void print_mote_error_code(FILE *fptr, uint16_t err_code);
void print_mote_error_location(FILE *fptr, uint16_t err_loc);

char* get_mote_error_code_string(uint16_t err_code);
char* get_mote_error_location_string(uint16_t err_loc);

uint16_t get_last_mote_error_code();
uint16_t get_last_mote_error_location();
uint16_t get_last_mote_error_location2();

int check_error_response(unsigned char *packet);
int print_error_response(FILE *fptr, unsigned char *packet, int addr);

#endif

