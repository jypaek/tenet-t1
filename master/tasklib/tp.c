/*
* "Copyright (c) 2006-2008 University of Southern California.
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
 * This file is part of Tenet parse system.
 * Given a string, it parse into tasklets and its parameters.
 * To add a tasklet, see below comments.
 **/

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "nx.h"
#include "tp.h"
#include "y.tab.h"
#include "tenet_task.h"
#include "element_usage.h"
#include "element_construct.h"

extern void yyparse();
extern void yyrestart(FILE*);

char tp_taskdesc[TP_MAX_TASKLEN];   /* Task description: yylex uses this */
int tp_taskpos;                     /* Current position: yylex uses this */
int tp_args[TP_MAX_ARGS];           /* Function args scanned in: yyparse fills this */
int tp_argpos;                      /* Position of args: yyparse touches this */
int tp_is_constant;/*Indicates if there is a constant. yyparse touches this*/
char tp_byteString[TP_MAX_ARGS][255];/*string as argument*/
int tp_arg_byteString;

unsigned char* tp_packetbuf;        /* Packet buffer given by caller */

int tp_length;          /* length (in bytes) of the task packet */
int tp_num_elements;    /* number of elements in the task */

void tp_process_init();
void tp_process_finalize();

int abort_due_to_error;

/*
#ifdef __CYGWIN__

// ascii to long long

long long atoll(char *str){
        long long result = 0;
        int negative=0;

        while (*str == ' ' || *str == '\t')
                str++;
        if (*str == '+')
                str++;
        else if (*str == '-') {
                negative = 1;
                str++;
        }

        while (*str >= '0' && *str <= '9') {
                result = (result*10) + (*str++ - '0');
        }

        return negative ? result : -result;
}

#endif
*/

static void
tp_doit(unsigned char* taskbuf, char* task)
{
    tp_packetbuf = taskbuf;
    if (strlen(task) >= TP_MAX_TASKLEN) {
        fprintf(stderr, "FATAL ERROR: Task description longer than expected\n");
        exit(1);
    }
    strcpy(tp_taskdesc, task);
    tp_taskpos = 0;
    tp_length = 0;
    tp_num_elements = 0;
    abort_due_to_error = 0;
    tp_init_args();
    tp_process_init();
    yyrestart(NULL);
    yyparse();
    tp_process_finalize();
}

void
tp_init_args()
{
    int i;
    for(i = 0; i < TP_MAX_ARGS; i++) {
        tp_args[i] = 0;
    }
    tp_argpos = -1;
    tp_is_constant=0;
    tp_arg_byteString=0;
}

void
tp_add_arg(int num)
{
    if (++tp_argpos >= TP_MAX_ARGS) {
        fprintf(stderr, "FATAL ERROR: Too many args.");
        exit(1);
    }
    tp_args[tp_argpos] = num;
}

void tp_add_byteString(char *string){
    if ((tp_arg_byteString+1) >= TP_MAX_ARGS) {
        fprintf(stderr, "FATAL ERROR: Too many args.");
        exit(1);
    }
  strcpy(tp_byteString[tp_arg_byteString],string);
  tp_arg_byteString++;
}

void tp_set_constant(){
    tp_is_constant=1;
}


/*************************************************************************/
void
tp_process_init()
{
    if (tp_argpos+1 != 0) {
        fprintf(stderr, "Warning: incorrect number of args for init\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("\n construct_init();\n");
#else
    tp_length += 
    construct_init(
            tp_packetbuf);
#endif        
}

void
tp_process_finalize()
{
    if (tp_argpos+1 != 0) {
        fprintf(stderr, "Warning: incorrect number of args for finalize\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf(" construct_finalize(%d);\n\n",
           tp_num_elements);
#else
    tp_length += 
    construct_finalize(
        tp_packetbuf, tp_num_elements);
#endif        
}

/***********************ADDITIONS TO TASK LIBRARY*************************/
/* Add support for a new construct_xxx() function here. Here is what you
   need to do:
   - add a tp_process_ function for the constructor
   - add an "if" clause for the tp_call_constructor() function below.
   - add a 'print_usage_xxx' function in element_usage.c
*/

/*************************************************************************
    ISSUE (wait, repeat, alarm, globalrepeat)
*************************************************************************/
static void
tp_process_issue()
{
    if (tp_argpos+1 != 3) { /* this is native 'Issue' */
        fprintf(stderr, "Warning: incorrect number of args for issue\n");
        print_usage_issue();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_issue(%u, %u, %d);\n", tp_args[0], tp_args[1], tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_issue(tp_packetbuf, tp_length, &tp_num_elements, 
           (uint32_t)tp_args[0], (uint32_t)tp_args[1], tp_args[2]);
#endif        
}

static void
tp_process_repeat()
{
    uint32_t period;
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for repeat\n");
        print_usage_repeat();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_repeat(%u);\n", tp_args[0]);
    tp_num_elements++;
#else

    period = (uint32_t)tp_args[0];

    tp_length +=
    construct_issue(    /* aliased to issue */
           tp_packetbuf, tp_length, &tp_num_elements, 
	   /* starttime, period, absolute time */
           period, period, 0);
#endif        
}

static void
tp_process_wait()
{
    uint32_t period;

    if (tp_argpos+1 == 1) {     // one-shot wait
        period = 0;
    } else if (tp_argpos+1 == 2) {  // for backward compatibility (will be decprecated)
        if (tp_args[1] == 1) {
            period = (uint32_t)tp_args[0];
        } else {
            period = 0;
        }
    } else {
        fprintf(stderr, "Warning: incorrect number of args for wait\n");
        print_usage_wait();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_wait(%u, %u);\n",
           tp_args[0], period);
    tp_num_elements++;
#else

    tp_length +=
    construct_issue(    /* aliased to issue */
           tp_packetbuf, tp_length, &tp_num_elements, 
	   /* starttime, period, absolute time */
           (uint32_t)tp_args[0], period, 0);
#endif        
}

static void
tp_process_wait_n_repeat()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for wait_n_repeat\n");
        print_usage_wait();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_wait_n_repeat(%u, %u);\n", tp_args[0], tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_issue(tp_packetbuf, tp_length, &tp_num_elements, 
           (uint32_t)tp_args[0], (uint32_t)tp_args[1], 0);
#endif        
}

static void
tp_process_alarm()
{
    if (tp_argpos+1 != 1) { /* this must be alarm/absolute-wait */
        fprintf(stderr, "Warning: incorrect number of args for alarm\n");
        print_usage_alarm();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_alarm(%u);\n",
           tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_issue(    /* aliased to issue */
            tp_packetbuf, tp_length, &tp_num_elements, 
	    /* starttime, period, absolute time */
            (uint32_t)tp_args[0], (uint32_t)0, 1);
#endif        
}

static void
tp_process_globalrepeat()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for globalrepeat\n");
        print_usage_globalrepeat();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_globalrepeat(%u, %u);\n", tp_args[0], tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_issue(tp_packetbuf, tp_length, &tp_num_elements, 
           (uint32_t)tp_args[0], (uint32_t)tp_args[1], 1);
#endif        
}

/*************************************************************************
    STORAGE (store, retrieve)
*************************************************************************/
static void
tp_process_storage()
{
    if (tp_argpos+1 != 3) {  /* this must be original 'Storage' */
        fprintf(stderr, "Warning: incorrect number of args for storage\n");
        print_usage_storage();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_storage(%d,%d,%d);\n",
           (uint16_t) tp_args[0], (uint16_t)tp_args[1], (uint8_t)tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_storage(
            tp_packetbuf, tp_length, &tp_num_elements,
           (uint16_t) tp_args[0], (uint16_t)tp_args[1], (uint8_t)tp_args[2]);
#endif
}

static void
tp_process_store()
{
    uint16_t arg1;
    if (tp_argpos+1 == 2) {        /* store with in/out tag */
        arg1 = (uint16_t)tp_args[1];
    } else if (tp_argpos+1 == 1) { /* store with one tag  */
        arg1 = (uint16_t)tp_args[0];
    } else {
        arg1 = (uint16_t)tp_args[1];
        fprintf(stderr, "Warning: incorrect number of args for storage/store/retrieve/etc\n");
        print_usage_storage();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_store(%d,%d);\n",
           (uint16_t) tp_args[0], arg1);
    tp_num_elements++;
#else
    tp_length +=
    construct_storage(
            tp_packetbuf, tp_length, &tp_num_elements,
           (uint16_t) tp_args[0], arg1, 1);
#endif
}

static void
tp_process_retrieve()
{
    uint16_t arg1;
    if (tp_argpos+1 == 2) {        /* retrieve with in/out tag */
        arg1 = (uint16_t)tp_args[1];
    } else if (tp_argpos+1 == 1) { /* retrieve with one tag  */
        arg1 = (uint16_t)tp_args[0];
    } else {
        arg1 = (uint16_t)tp_args[1];
        fprintf(stderr, "Warning: incorrect number of args for storage/store/retrieve/etc\n");
        print_usage_storage();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_retrieve(%d,%d);\n",
           (uint16_t) tp_args[0], arg1);
    tp_num_elements++;
#else
    tp_length +=
    construct_storage(
            tp_packetbuf, tp_length, &tp_num_elements,
           (uint16_t) tp_args[0], arg1, 0);
#endif
}

/*************************************************************************
    COUNT (count, constant)
*************************************************************************/
static void
tp_process_count()
{
    int16_t value, rate;
    if (tp_argpos+1 == 1) {     /* 'count' alias */
        value = 0;
        rate = 1;
    } else if (tp_argpos+1 == 3) {     /* original 'count' */
        value = tp_args[1];
        rate = tp_args[2];
    } else  {     /* original 'count' */
        fprintf(stderr, "Warning: incorrect number of args for count\n");
        print_usage_count();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_count(%d, %d, %d);\n",
           tp_args[0], value, rate);
    tp_num_elements++;
#else
    tp_length +=
    construct_count(
        tp_packetbuf, tp_length, &tp_num_elements, 
        tp_args[0], tp_args[1], tp_args[2]);
#endif        
}

static void
tp_process_constant()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for constant\n");
        print_usage_constant();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_constant(%d, %d);\n",
           tp_args[0], tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_count(    /* aliased to count */
        tp_packetbuf, tp_length, &tp_num_elements, 
        tp_args[0], tp_args[1], 0);
#endif        
}

/*************************************************************************
    ACTUATE (set_leds, set_rfpower)
*************************************************************************/
static void
tp_process_actuate()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 2) {          /* this is native actuate */
        fprintf(stderr,"Warning: incorrect number of args for actuate\n");
        print_usage_actuate();
        exit(1);
    }

#ifdef TP_STANDALONE
    printf("    + construct_actuate(%d,%d,%d);\n",
        (uint8_t)tp_args[0], argtype, (uint16_t)tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint8_t)tp_args[0], argtype, (uint16_t)tp_args[1]);
#endif
}

static void
tp_process_set_leds()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr,"Warning: incorrect number of args for set_leds\n");
        print_usage_set_leds();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_set_leds(%d,%d);\n",
        argtype, (uint16_t)tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_LEDS, argtype, (uint16_t)tp_args[0]);
#endif
}

static void
tp_process_toggle_leds()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr,"Warning: incorrect number of args for toggle_leds\n");
        print_usage_toggle_leds();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_toggle_leds(%d,%d);\n",
        argtype, (uint16_t)tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_LEDS_TOGGLE, argtype, (uint16_t)tp_args[0]);
#endif
}

static void
tp_process_leds0toggle()
{
    tp_is_constant = 1;
    tp_argpos = 0;
    tp_args[0] = 1;
    tp_process_toggle_leds();
}
static void
tp_process_leds1toggle()
{
    tp_is_constant = 1;
    tp_argpos = 0;
    tp_args[0] = 2;
    tp_process_toggle_leds();
}
static void
tp_process_leds2toggle()
{
    tp_is_constant = 1;
    tp_argpos = 0;
    tp_args[0] = 4;
    tp_process_toggle_leds();
}

static void
tp_process_set_rfpower()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr,"Warning: incorrect number of args for set_rfpower\n");
        print_usage_set_rfpower();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_set_rfpower(%d,%d);\n",
        argtype, (uint16_t)tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_RADIO, argtype, (uint16_t)tp_args[0]);
#endif
}

static void
tp_process_sounder()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr,"Warning: incorrect number of args for sounder\n");
        print_usage_sounder();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_sounder(%d,%d);\n",
        argtype, (uint16_t)tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_SOUNDER, argtype, (uint16_t)tp_args[0]);
#endif
}

static void
tp_process_reset_parent()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 0) {
        fprintf(stderr,"Warning: incorrect number of args for reset_parent\n");
        print_usage_reset_parent();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_reset_parent();\n");
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_ROUTE_RESET, 0, 0);
#endif
}

static void
tp_process_hold_parent()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 0) {
        fprintf(stderr,"Warning: incorrect number of args for hold_parent\n");
        print_usage_hold_parent();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("    + construct_hold_parent();\n");
    tp_num_elements++;
#else
    tp_length +=
    construct_actuate(
        tp_packetbuf, tp_length, &tp_num_elements,
        ACTUATE_ROUTE_HOLD, 0, 0);
#endif
}

/*************************************************************************
    LOGICAL (and, or, not, etc)
*************************************************************************/
static void
tp_process_logical()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 4) {
        fprintf(stderr, "Warning: incorrect number of args for logical\n");
        print_usage_logical();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_logical(%d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], argtype, tp_args[3]);
    tp_num_elements++;
#else
    tp_length +=
    construct_logical(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], tp_args[2], argtype, tp_args[3]);
#endif
}

static void
tp_process_logical_and()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for and\n");
        print_usage_logical();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_logical(%d, %d, AND, %d, %d);\n",
        tp_args[0], tp_args[1], argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_logical(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], LAND, argtype, tp_args[2]);
#endif
}

static void
tp_process_logical_or()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for or\n");
        print_usage_logical();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_logical(%d, %d, OR, %d, %d);\n",
        tp_args[0], tp_args[1], argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_logical(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], LOR, argtype, tp_args[2]);
#endif
}

static void
tp_process_logical_not()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for not\n");
        print_usage_logical();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_logical(%d, %d, NOT, %d, %d);\n",
        tp_args[0], tp_args[1], argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_logical(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], LNOT, argtype, 1);
#endif
}

/*************************************************************************
    BIT (and, or, not, shift, etc)
*************************************************************************/
static void
tp_process_bit()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 4) {
        fprintf(stderr, "Warning: incorrect number of args for bit\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], argtype, tp_args[3]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], tp_args[2], argtype, tp_args[3]);
#endif
}

static void
tp_process_bit_and()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for bit_and\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], AND, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], AND, argtype, tp_args[2]);
#endif
}

static void
tp_process_bit_or()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for bit_or\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], OR, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], OR, argtype, tp_args[2]);
#endif
}

static void
tp_process_bit_not()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for bit_not\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], NOT, argtype, 1);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], NOT, argtype, 1);
#endif
}

static void
tp_process_bit_xor()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for bit_xor\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], XOR, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], XOR, argtype, tp_args[2]);
#endif
}

static void
tp_process_bit_nand()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for bit_nand\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], NAND, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], NAND, argtype, tp_args[2]);
#endif
}

static void
tp_process_bit_nor()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for nor\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], NOR, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], NOR, argtype, tp_args[2]);
#endif
}

static void
tp_process_shiftleft()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for shift left\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], SHL, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], SHL, argtype, tp_args[2]);
#endif
}

static void
tp_process_shiftright()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for shift right\n");
        print_usage_bit();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_bit(%d, %d, %d, %d, %d);\n",
        tp_args[0], tp_args[1], SHR, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_bit(
        tp_packetbuf, tp_length, &tp_num_elements,
        tp_args[0], tp_args[1], SHR, argtype, tp_args[2]);
#endif
}

/*************************************************************************
    ARITH (add, sub, mul, etc)
*************************************************************************/
static void
tp_process_arith()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 4) {         /* this must be original 'Arith' */
        fprintf(stderr, "Warning: incorrect number of args for arith\n");
        print_usage_arith();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], argtype, tp_args[3]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],(uint16_t) tp_args[1],(uint8_t) tp_args[2],argtype,(uint16_t) tp_args[3]
        );
#endif
}

static void
tp_process_add()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for add\n");
        print_usage_add();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_ADD, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_ADD, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_sub()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for sub\n");
        print_usage_sub();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_SUB, argtype, (uint16_t) tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_SUB, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_mult()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for mult\n");
        print_usage_mult();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_MULT, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_MULT, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_div()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for div\n");
        print_usage_div();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_DIV, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_DIV, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_diff()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for diff\n");
        print_usage_diff();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_DIFF, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0], (uint16_t) tp_args[1], A_DIFF, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_mod()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for mod\n");
        print_usage_mod();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_MOD, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t)tp_args[0], (uint16_t)tp_args[1], A_MOD, argtype, (uint16_t)tp_args[2]);
#endif
}

static void
tp_process_pow()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {         
        fprintf(stderr, "Warning: incorrect number of args for pow\n");
        print_usage_pow();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_arith(%d, %d, %d, %d, %d);\n",
            tp_args[0], tp_args[1], A_POW, argtype, tp_args[2]);
    tp_num_elements++;
#else
    tp_length +=
    construct_arith(
            tp_packetbuf, tp_length, &tp_num_elements,
            tp_args[0], tp_args[1], A_POW, argtype, tp_args[2]);
#endif
}

/*************************************************************************
    GET (time, nexthop, etc)
*************************************************************************/
static void
tp_process_get()
{
    if (tp_argpos+1 != 2) {         /* this must be original 'Get' */
        fprintf(stderr, "Warning: incorrect number of args for get\n");
        print_usage_get();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_get(%d,%d);\n",
        (uint16_t) tp_args[0], (uint16_t)tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t)tp_args[1]);
#endif
}

static void
tp_process_nexthop()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for nexthop/parent\n");
        print_usage_nexthop();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_nexthop(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_PARENT);
#endif
}

static void
tp_process_neighbors()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for neighbors\n");
        print_usage_neighbors();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_neighbors(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_NEIGHBORS);
#endif
}

static void
tp_process_children()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for children\n");
        print_usage_children();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_children(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_CHILDREN);
#endif
}

static void
tp_process_globaltime()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for globaltime\n");
        print_usage_globaltime();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_globaltime(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_GLOBAL_TIME);
#endif
}

static void
tp_process_globaltime_ms()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for globaltime_ms (16-bit, in milliseconds)\n");
        print_usage_globaltime();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_globaltime_ms(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_GLOBAL_TIME_MS);
#endif
}

static void
tp_process_localtime()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for localtime\n");
        print_usage_localtime();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_localtime(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_LOCAL_TIME);
#endif
}

static void
tp_process_localtime_ms()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for localtime_ms\n");
        print_usage_localtime();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_localtime_ms(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_LOCAL_TIME_MS);
#endif
}

static void
tp_process_rfpower()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for rfpower/get_rfpower\n");
        print_usage_rfpower();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_rfpower(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_RF_POWER);
#endif
}

static void
tp_process_rfchannel()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for rfchannel/get_rfchannel\n");
        print_usage_rfchannel();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_rfchannel(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_RF_CHANNEL);
#endif
}

static void
tp_process_leds()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for get_leds\n");
        print_usage_leds();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_leds(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_LEDS);
#endif
}

static void
tp_process_nodeid()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for nodeid\n");
        print_usage_nodeid();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_nodeid(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_TOS_LOCAL_ADDRESS);
#endif
}

static void
tp_process_memory_stats()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for memory_stats\n");
        print_usage_memory_stats();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_memory_stats(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_MEMORY_STATS);
#endif
}

static void
tp_process_num_tasks()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for num_tasks\n");
        print_usage_num_tasks();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_num_tasks(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_NUM_TASKS);
#endif
}

static void
tp_process_num_active_tasks()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for num_active_tasks\n");
        print_usage_num_active_tasks();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_num_active_tasks(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_NUM_ACTIVE_TASKS);
#endif
}

static void
tp_process_istimesync()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for istimesync\n");
        print_usage_istimesync();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_istimesync(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_IS_TIMESYNC);
#endif
}

static void
tp_process_platform()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for platform\n");
        print_usage_platform();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_platform(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_PLATFORM);
#endif
}

static void
tp_process_clock_freq()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for clock_freq\n");
        print_usage_clock_freq();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_clock_freq(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_CLOCK_FREQ);
#endif
}

static void
tp_process_master()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for master\n");
        print_usage_master();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_master(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_MASTER);
#endif
}

static void
tp_process_hopcount()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for hopcount\n");
        print_usage_hopcount();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_hopcount(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_HOPCOUNT);
#endif
}

static void
tp_process_rssi()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for rssi\n");
        print_usage_rssi();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_rssi(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_PARENT_RSSI);
#endif
}

static void
tp_process_linkquality()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for linkquality\n");
        print_usage_linkquality();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_linkquality(%d);\n",
        (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_get(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], GET_ROUTING_PARENT_LINKQUALITY);
#endif
}

/*************************************************************************
    COMPARISON (eq, lt, gt, etc)
*************************************************************************/
static void
tp_process_comparison()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 4) {         /* this must be original 'Comparison' */
        fprintf(stderr, "Warning: incorrect number of args for comparison\n");
        print_usage_comparison();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint8_t) tp_args[2],
            argtype,
            (uint16_t) tp_args[3]
        );
#endif
}

static void
tp_process_lt()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for lt\n");
        print_usage_lt();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], LT, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_gt()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for gt\n");
        print_usage_gt();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], GT, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_eq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for eq\n");
        print_usage_eq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], EQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_leq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for leq\n");
        print_usage_leq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], LEQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_geq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for geq\n");
        print_usage_geq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], GEQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_neq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for neq\n");
        print_usage_neq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], NEQ, argtype, (uint16_t) tp_args[2]);
#endif
}

static void
tp_process_count_lt()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_lt\n");
        print_usage_count_lt();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_LT, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_count_gt()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_gt\n");
        print_usage_count_gt();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_GT, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_count_eq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_eq\n");
        print_usage_count_eq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_EQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_count_leq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_leq\n");
        print_usage_count_leq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_LEQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_count_geq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_geq\n");
        print_usage_count_geq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_GEQ, argtype, (uint16_t) tp_args[2]);
#endif
}
static void
tp_process_count_neq()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for count_neq\n");
        print_usage_count_neq();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_comparison(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], COUNT_NEQ, argtype, (uint16_t) tp_args[2]);
#endif
}
/*************************************************************************
    STATS (min, max, avg, etc)
*************************************************************************/
static void
tp_process_stats()
{
    if (tp_argpos+1 != 3) {         /* this must be original 'Stats' */
        fprintf(stderr, "Warning: incorrect number of args for stats\n");
        print_usage_stats();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint16_t) tp_args[2]
        );
#endif
}
static void
tp_process_sum()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for sum\n");
        print_usage_sum();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], SUMM);
#endif
}
static void
tp_process_min()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for min\n");
        print_usage_min();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], MIN);
#endif
}
static void
tp_process_max()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for max\n");
        print_usage_max();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], MAX);
#endif
}
static void
tp_process_avg()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for avg\n");
        print_usage_avg();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], AVG);
#endif
}
static void
tp_process_std()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for std\n");
        print_usage_std();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], STD);
#endif
}
static void
tp_process_cnt()
{
    if (tp_argpos+1 != 2) {         /* this must be original 'Stats' */
        fprintf(stderr, "Warning: incorrect number of args for cnt\n");
        print_usage_cnt();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], CNT);
#endif
}
static void
tp_process_meandev()
{
    if (tp_argpos+1 != 2) {         /* this must be original 'Stats' */
        fprintf(stderr, "Warning: incorrect number of args for meandev\n");
        print_usage_meandev();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_stats(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], MEANDEV);
#endif
}


/*************************************************************************
    ATTRIBUTE (exist, not_exist, length)
*************************************************************************/
static void
tp_process_attribute()
{
    if (tp_argpos+1 != 3) {         /* this must be original 'Stats' */
        fprintf(stderr, "Warning: incorrect number of args for attribute\n");
        print_usage_attribute();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_attribute(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint8_t) tp_args[2]
        );
#endif
}
static void
tp_process_exist()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for exist\n");
        print_usage_exist();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_attribute(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], EXIST);
#endif
}
static void
tp_process_not_exist()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for not_exist\n");
        print_usage_not_exist();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_attribute(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], NOT_EXIST);
#endif
}
static void
tp_process_length()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for length\n");
        print_usage_length();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_attribute(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], LENGTH);
#endif
}
/*************************************************************************
    REBOOT
*************************************************************************/
static void
tp_process_reboot()
{
    if (tp_argpos+1 != 0) {
        fprintf(stderr, "Warning: incorrect number of args for reboot\n");
        print_usage_reboot();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_reboot();\n");
    tp_num_elements++;
#else
    tp_length +=
    construct_reboot(
        tp_packetbuf, tp_length, &tp_num_elements);
#endif        
}

/*************************************************************************
    SECURITY
*************************************************************************/
//This is a dummy tasklet to test the string argument
//eg: security(A,B)
static void
tp_process_security()
{
    if (tp_arg_byteString!=2) {
        fprintf(stderr, "Warning: incorrect number of args for security\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_security();\n");
    printf("   argument String: %s\n", tp_byteString[0]);
    printf("   argument String: %s\n", tp_byteString[1]);
    tp_num_elements++;
#else
//    tp_length +=
//    construct_security(
//        tp_packetbuf, tp_length, &tp_num_elements, tp_byteString[0],tp_byteString[1]);
#endif
}


/*************************************************************************
    PACK
*************************************************************************/
static void
tp_process_pack()
{
    uint8_t block;
    if (tp_argpos+1 == 2) {
        block = 0;
    } else if (tp_argpos+1 == 3) {
        block = (uint8_t) tp_args[2];
    } else {
        fprintf(stderr, "Warning: incorrect number of args for pack\n");
        print_usage_pack();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_pack(%d, %d, %d);\n",
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], block);
    tp_num_elements++;
#else
    tp_length +=
    construct_pack(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], block);
#endif
}

static void
tp_process_pack_n_wait()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for pack_n_wait\n");
        print_usage_pack();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_pack(%d, %d, 1);\n",
        (uint16_t) tp_args[0], (uint16_t) tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_pack(
        tp_packetbuf, tp_length, &tp_num_elements,
        (uint16_t) tp_args[0], (uint16_t) tp_args[1], 1);
#endif
}

/*************************************************************************
    SEND
*************************************************************************/
static void
tp_process_send()
{
    uint16_t arg0 = 0;
    /* sendtype
          0    : Unreliable Send
          1    : Packet Transport (end-to-end ACK)
          2    : Stream Transport */
    if (tp_argpos+1 == 0) {
        arg0 = 0;
    } else if (tp_argpos+1 == 1) {
        arg0 = (uint16_t)tp_args[0];
    } else {
        fprintf(stderr, "Warning: incorrect number of args for send\n");
        print_usage_send();
        exit(1);
    }
    
#ifdef TP_STANDALONE
    printf("   + construct_send(%d);\n", arg0);
    tp_num_elements++;
#else
    tp_length +=
    construct_send(
        tp_packetbuf, tp_length, &tp_num_elements, arg0);
#endif        
}

static void
tp_process_sendpkt()
{
    /* sendtype
          0    : Unreliable Send
          1    : Packet Transport (end-to-end ACK) */
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for sendpkt\n");
        print_usage_sendpkt();
        exit(1);
    }
    if (tp_args[0] > 1) {
        fprintf(stderr, "Warning: incorrect args for sendpkt\n");
        print_usage_sendpkt();
        exit(1);
    }
    
#ifdef TP_STANDALONE
    printf("   + construct_sendpkt(%d);\n", tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_sendpkt(
        tp_packetbuf, tp_length, &tp_num_elements, tp_args[0]);
#endif        
}

static void
tp_process_sendstr()
{
    if (tp_argpos+1 != 0) {
        fprintf(stderr, "Warning: incorrect number of args for sendstr\n");
        print_usage_sendstr();
        exit(1);
    }
    
#ifdef TP_STANDALONE
    printf("   + construct_sendstr();\n");
    tp_num_elements++;
#else
    tp_length +=
    construct_sendstr(
        tp_packetbuf, tp_length, &tp_num_elements);
#endif        
}

static void
tp_process_sendrcrt()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for sendrcrt\n");
        print_usage_sendrcrt();
        exit(1);
    }
    
#ifdef TP_STANDALONE
    printf("   + construct_sendrcrt(%d);\n", tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_sendrcrt(
        tp_packetbuf, tp_length, &tp_num_elements, tp_args[0]);
#endif        
}

/*************************************************************************
    DELETE (attribute, active_task, task) IF
*************************************************************************/
static void
tp_process_deleteAttributeIf()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for deleteAttributeIf\n");
        print_usage_deleteattributeif();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_deleteAttributeIf(%d, %d, %d);\n",
           tp_args[0], argtype, tp_args[1]);
    tp_num_elements++;
#else
    tp_length +=
    construct_deleteAttributeIf(
           tp_packetbuf, tp_length, &tp_num_elements, 
           tp_args[0], argtype, tp_args[1], 0);
#endif        
}

static void
tp_process_deleteAttribute()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for deleteAttribute\n");
        print_usage_deleteattributeif();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_deleteAttributeIf(%d, %d, %d);\n",
           1, ARGTYPE_CONSTANT, tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_deleteAttributeIf(
           tp_packetbuf, tp_length, &tp_num_elements, 
           1, ARGTYPE_CONSTANT, tp_args[0], 0);
#endif        
}

static void
tp_process_deleteAllAttributeIf()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for deleteAllAttributeIf\n");
        print_usage_deleteattributeif();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_deleteAllAttributeIf(%d, %d);\n",
           tp_args[0], argtype);
    tp_num_elements++;
#else
    tp_length +=
    construct_deleteAttributeIf(
           tp_packetbuf, tp_length, &tp_num_elements, 
           tp_args[0], argtype, 0, 1);
#endif        
}

static void
tp_process_deleteActiveTaskIf()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for deleteActiveTaskIf\n");
	print_usage_deleteactivetaskif();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_deleteActiveTaskIf(%d, %d);\n",
           tp_args[0], argtype );
    tp_num_elements++;
#else
    tp_length +=
    construct_deleteActiveTaskIf(
           tp_packetbuf, tp_length, &tp_num_elements, 
           tp_args[0], argtype);
#endif        
}

static void
tp_process_deleteTaskIf()
{
    uint8_t argtype;
    argtype=(tp_is_constant)?ARGTYPE_CONSTANT:ARGTYPE_ATTRIBUTE;

    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for deleteTaskIf\n");
	print_usage_deletetaskif();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_deleteTaskIf(%d, %d );\n",
           tp_args[0], argtype );
    tp_num_elements++;
#else
    tp_length +=
    construct_deleteTaskIf(
           tp_packetbuf, tp_length, &tp_num_elements, 
           tp_args[0], argtype);
#endif        
}

/*************************************************************************
    SAMPLE
*************************************************************************/

static void
tp_process_sample()
{
    uint32_t interval;
    uint16_t count;
    uint8_t repeat, ch0;
    uint16_t out0;

    if (tp_argpos+1 == 5) {
        // sample(interval, count, repeat, ch0, out0)
        interval = tp_args[0];
        count = tp_args[1];
        repeat = tp_args[2];
        ch0 = tp_args[3];
        out0 = tp_args[4];
    } else if (tp_argpos+1 == 4) {
        // sample(interval, count, ch0, out0)
        interval = tp_args[0];
        count = tp_args[1];
        repeat = 0;
        ch0 = tp_args[2];
        out0 = tp_args[3];
    } else if (tp_argpos+1 == 3) {
        // sample(interval, ch0, out0)
        interval = tp_args[0];
        count = 1;
        repeat = 1;
        ch0 = tp_args[1];
        out0 = tp_args[2];
    } else if (tp_argpos+1 == 2) {
        // sample(ch0, out0)
        interval = 0;
        count = 1;
        repeat = 0;
        ch0 = tp_args[0];
        out0 = tp_args[1];
    } else {
        fprintf(stderr, "Warning: incorrect number of args for sample\n");
        print_usage_sample();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_sample(%u, %d, %d, %d, %d);\n",
            interval, count, repeat, ch0, out0);
    tp_num_elements++;
#else
// sample(interval, count, repeat, ch0, out0)

    tp_length +=
    construct_sample(
            tp_packetbuf, tp_length, &tp_num_elements, 
            interval, count, repeat, ch0, out0);
#endif        
}

static void
tp_process_voltage()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for voltage\n");
        print_usage_voltage();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_voltage(%d);\n",
           tp_args[0]);
    tp_num_elements++;
#else

    tp_length +=
    construct_voltage(
           tp_packetbuf, tp_length, &tp_num_elements, tp_args[0]);
#endif        
}

static void
tp_process_fastsample()
{
    if (tp_argpos+1 != 9) {
        fprintf(stderr, "Warning: incorrect number of args for fastsample\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_fastsample(%d, %d, %d, %d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3], tp_args[4],
           tp_args[5], tp_args[6], tp_args[7], tp_args[8]);
    tp_num_elements++;
#else
    tp_length +=
    construct_fastsample(
           tp_packetbuf, tp_length, &tp_num_elements, 
           tp_args[0], tp_args[1], tp_args[2], tp_args[3], tp_args[4],
           tp_args[5], tp_args[6], tp_args[7], tp_args[8]);
#endif        
}

/*************************************************************************
    USER BUTTON
*************************************************************************/
static void
tp_process_user_button()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for user_button\n");
        print_usage_user_button();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_user_button(%d);\n",
           tp_args[0]);
    tp_num_elements++;
#else
    tp_length +=
    construct_user_button(
        tp_packetbuf, tp_length, &tp_num_elements, 
        tp_args[0]);
#endif        
}

/*************************************************************************
    MEMORY OP
*************************************************************************/
static void
tp_process_memoryop()
{
    if (tp_argpos+1 != 4) {
        fprintf(stderr, "Warning: incorrect number of args for memoryop\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_memoryop(%d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3]);
    tp_num_elements++;
#else
    tp_length +=
    construct_memoryop(
        tp_packetbuf, tp_length, &tp_num_elements, 
        tp_args[0], tp_args[1], tp_args[2], tp_args[3]);
#endif        
}


/*************************************************************************
    PEG
*************************************************************************/
static void
tp_process_sample_rssi()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for sample_rssi\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_sample_rssi(%d);\n",
           (uint16_t) tp_args[0]);
    tp_num_elements++;
#else
    tp_length += 
    construct_sample_rssi(
            tp_packetbuf, tp_length, &tp_num_elements, 
            (uint16_t) tp_args[0]);
#endif        
}


/*************************************************************************
    MDA400
*************************************************************************/
static void
tp_process_mda400()
{
    if (tp_argpos+1 != 8) {
        fprintf(stderr, "Warning: incorrect number of args for mda400\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_mda400(%d, %d, %d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2],
           tp_args[3], tp_args[4], tp_args[5], tp_args[6], tp_args[7]);
    tp_num_elements++;
#else
    tp_length += 
    construct_mda400(
            tp_packetbuf, tp_length, &tp_num_elements, 
            (uint16_t)tp_args[0], (uint16_t)tp_args[1],
            (uint16_t)tp_args[2], (uint16_t)tp_args[3] , 
            (uint16_t)tp_args[4], (uint16_t)tp_args[5],
            (uint8_t)tp_args[6] , (uint8_t)tp_args[7]);
            //uint16_t us_sample_interval, uint16_t num_kilo_samples,
            //uint16_t tag_x, uint16_t tag_y, uint16_t tag_z,
            //uint8_t channel_select, uint8_t samples_per_buffer
#endif        
}

static void
tp_process_onset_detector()
{
    if (tp_argpos+1 != 7) {
        fprintf(stderr, "Warning: incorrect number of args for onset_detector\n");
        print_usage_onset_detector();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_onset_detector(%d, %d, %d, %d, %d, %d, %d);\n"
           , tp_args[0], tp_args[1]
           , tp_args[2], tp_args[3]
           , tp_args[4], tp_args[5]
           , tp_args[6]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_onset_detector(
            tp_packetbuf, tp_length, &tp_num_elements
            /*
            , (uint8_t)tp_args[0], (uint8_t)tp_args[1]   //int8_t alpha, int8_t beta, 
            */
            , (int8_t)tp_args[0]    // int8_t noiseThresh
            , (int8_t)tp_args[1]    // int8_t signalThresh
            , (uint16_t)tp_args[2]  // uint16_t startDelay
            , (uint16_t)tp_args[3]  // uint16_t tag_in
            , (uint16_t)tp_args[4]  // uint16_t tag_out
            , (uint16_t)tp_args[5]  // uint16_t tag_info
            , (uint8_t)tp_args[6]   // uint8_t adaptiveMean
            );
#endif        
}

/*************************************************************************
    MDA300
*************************************************************************/
static void
tp_process_mda300()
{
    if (tp_argpos+1 != 4) {
        fprintf(stderr, "Warning: incorrect number of args for mda300\n");
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_mda300(%d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2],
           tp_args[3]);
    tp_num_elements++;
#else
    tp_length += 
    construct_mda300(
            tp_packetbuf, tp_length, &tp_num_elements, 
            (uint8_t)tp_args[0], (uint8_t)tp_args[1] , 
            (tag_t)tp_args[2], (uint8_t)tp_args[3]);
#endif        
}


#ifdef INCLUDE_CYCLOPS
/*************************************************************************
    IMAGE (CYCLOPS)
*************************************************************************/
static void
tp_process_image()
{
    if (tp_argpos+1 != 7) {
        fprintf(stderr, "Warning: incorrect number of args for image\n");
        print_usage_image();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image(%d,%d,%d,%d,%d,%d,%d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3],
           tp_args[4], tp_args[5], tp_args[6]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_get(
            tp_packetbuf, tp_length, &tp_num_elements
            , 0  // imageAddr = Take New Image
            , (uint8_t)tp_args[0]  // fragmentSize
            , (uint16_t)tp_args[1] // reportRate
            , (uint8_t)tp_args[2]  // enableFlash
            , (uint8_t)tp_args[3]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[4]  // size.x
            , (uint8_t)tp_args[5]  // size.y
            , (uint16_t)tp_args[6] // out-tag
            );
#endif        
}

static void
tp_process_image_get()
{
    if (tp_argpos+1 != 8) {
        fprintf(stderr, "Warning: incorrect number of args for image_get\n");
        print_usage_image_get();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_get(%d,%d,%d,%d,%d,%d,%d,%d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3],
           tp_args[4], tp_args[5], tp_args[6], tp_args[7]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_get(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0]  // imageAddr (0=takeNewImage, 1,2,3 are old images)
            , (uint8_t)tp_args[1]  // fragmentSize
            , (uint16_t)tp_args[2] // reportRate
            , (uint8_t)tp_args[3]  // enableFlash
            , (uint8_t)tp_args[4]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[5]  // size.x
            , (uint8_t)tp_args[6]  // size.y
            , (uint16_t)tp_args[7] // out-tag
            );
#endif        
}

static void
tp_process_image_snap()
{
    if (tp_argpos+1 != 5) {
        fprintf(stderr, "Warning: incorrect number of args for image_snap\n");
        print_usage_image_snap();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_snap(%d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3], tp_args[4]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_snap(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0]  // enableFlash
            , (uint8_t)tp_args[1]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[2]  // size.x
            , (uint8_t)tp_args[3]  // size.y
            , (uint16_t)tp_args[4] // out-tag
            );
#endif 
}

static void
tp_process_image_detect()
{
    if (tp_argpos+1 != 5) {
        fprintf(stderr, "Warning: incorrect number of args for image_detect\n");
        print_usage_image_detect();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_detect(%d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3], tp_args[4]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_detect(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0] // type
            , (uint8_t)tp_args[1] // use_segment
            , (uint8_t)tp_args[2] // enableFlash
            , (uint8_t)tp_args[3] // ImgRes
            , (uint16_t)tp_args[4] // out-tag
            );
#endif 
}

#include "cyclops_query.h"
static void
tp_process_image_detect_reset()
{
#ifdef TP_STANDALONE
#else
    tp_length += construct_image_detect(
            tp_packetbuf, tp_length, &tp_num_elements
            , DETECT_RESET_BACKGROUND, 0, 0, 0, 0);
#endif
}
static void
tp_process_image_detect_set()
{
#ifdef TP_STANDALONE
#else
    tp_length += construct_image_detect(
            tp_packetbuf, tp_length, &tp_num_elements
            , DETECT_SET_BACKGROUND, 0, 0, 0, 0);
#endif
}

static void
tp_process_image_detect_params()
{
    if (tp_argpos+1 != 6) {
        fprintf(stderr, "Warning: incorrect number of args for image_detect_params\n");
        print_usage_image_detect_params();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_detect_params(%d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3], tp_args[4], tp_args[5]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_detect_params(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0] // ImgRes
            , (uint8_t)tp_args[1] // RACoeff
            , (uint8_t)tp_args[2] // skip
            , (uint8_t)tp_args[3] // illCoeff
            , (uint8_t)tp_args[4] // range
            , (uint8_t)tp_args[5] // detectThresh
            );
#endif 
}

static void
tp_process_image_set_capture_params()
{
    if (tp_argpos+1 != 14) {
        fprintf(stderr, "Warning: incorrect number of args for image_set_param\n");
        print_usage_image_set_capture_params();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_set_capture_params(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3],
           tp_args[4], tp_args[5], tp_args[6], tp_args[7],
           tp_args[8], tp_args[9], tp_args[10], tp_args[11],
           tp_args[12], tp_args[13]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_capture_params(
            tp_packetbuf, tp_length, &tp_num_elements
            , ACTIVE_EYE_SET_PARAMS
            , (int16_t)tp_args[0]   // offset.x
            , (int16_t)tp_args[1]   // offset.y
            , (uint16_t)tp_args[2]  // inputSize.x
            , (uint16_t)tp_args[3]  // inputSize.y
            , (uint8_t)tp_args[4]   // testMode
            , (uint16_t)tp_args[5]  // exposurePeriod
            , (uint8_t)tp_args[6]   // analog.red
            , (uint8_t)tp_args[7]   // analog.green
            , (uint8_t)tp_args[8]   // analog.blue
            , (uint16_t)tp_args[9]  // digital.red
            , (uint16_t)tp_args[10] // digital.green
            , (uint16_t)tp_args[11] // digital.blue
            , (uint16_t)tp_args[12] // runTime
            , (uint16_t)tp_args[13] // out-tag
            );
#endif
}

static void
tp_process_image_get_capture_params()
{
    if (tp_argpos+1 != 1) {
        fprintf(stderr, "Warning: incorrect number of args for image_get_capture_params\n");
        print_usage_image_get_capture_params();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_get_capture_params(%d);\n",
           tp_args[0]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_capture_params(
            tp_packetbuf, tp_length, &tp_num_elements
            , ACTIVE_EYE_GET_PARAMS
            , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
            , (uint16_t)tp_args[0] // out-tag
            );
#endif
}

static void
tp_process_image_reboot()
{
    if (tp_argpos+1 != 0) {
        fprintf(stderr, "Warning: incorrect number of args for image_reboot\n");
        print_usage_image_reboot();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_reboot();\n"
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_reboot(
            tp_packetbuf, tp_length, &tp_num_elements);
#endif
}

static void
tp_process_image_getRle()
{
    if (tp_argpos+1 != 9) {
        fprintf(stderr, "Warning: incorrect number of args for image_getRle\n");
        print_usage_image_getrle();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_getRle(%d, %d, %d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3],
           tp_args[4], tp_args[5], tp_args[6], tp_args[7]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_getRle(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0]  // imageAddr (0=takeNewImage, 1,2,3 are old images)
            , (uint8_t)tp_args[1]  // fragmentSize
            , (uint16_t)tp_args[2] // reportRate
            , (uint8_t)tp_args[3]  // enableFlash
            , (uint8_t)tp_args[4]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[5]  // size.x
            , (uint8_t)tp_args[6]  // size.y
            , (uint8_t)tp_args[7]  // threshold
            , (uint16_t)tp_args[8] // out-tag
            );
#endif        
}

static void
tp_process_image_getPackBits()
{
    if (tp_argpos+1 != 9) {
        fprintf(stderr, "Warning: incorrect number of args for image_getPackBits\n");
        print_usage_image_getpackbits();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_getPackBits(%d, %d, %d, %d, %d, %d, %d, %d);\n",
           tp_args[0], tp_args[1], tp_args[2], tp_args[3],
           tp_args[4], tp_args[5], tp_args[6], tp_args[7]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_getPackBits(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0]  // imageAddr (0=takeNewImage, 1,2,3 are old images)
            , (uint8_t)tp_args[1]  // fragmentSize
            , (uint16_t)tp_args[2] // reportRate
            , (uint8_t)tp_args[3]  // enableFlash
            , (uint8_t)tp_args[4]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[5]  // size.x
            , (uint8_t)tp_args[6]  // size.y
            , (uint8_t)tp_args[7]  // threshold
            , (uint16_t)tp_args[8] // out-tag
            );
#endif        
}

static void
tp_process_image_copy()
{
    if (tp_argpos+1 != 6) {
        fprintf(stderr, "Warning: incorrect number of args for image_copy\n");
        print_usage_image_snap();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_image_copy(%d,%d,%d,%d,%d,%d);\n",
           tp_args[0], tp_args[1], tp_args[2], 
           tp_args[3], tp_args[4], tp_args[5]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_image_copy(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint8_t)tp_args[0]  // fromImageAddr
            , (uint8_t)tp_args[1]  // toImageAddr
            , (uint8_t)tp_args[2]  // enableFlash
            , (uint8_t)tp_args[3]  // imageType (16:B/W, 17:Color)
            , (uint8_t)tp_args[4]  // size.x
            , (uint8_t)tp_args[5]  // size.y
            );
#endif 
}
#endif 

/*************************************************************************
    FIR Low Pass Filter
*************************************************************************/
static void
tp_process_firlpfilter()
{
    if (tp_argpos+1 != 2) {
        fprintf(stderr, "Warning: incorrect number of args for firlpfilter\n");
        print_usage_firlpfilter();
        exit(1);
    }
#ifdef TP_STANDALONE
    printf("   + construct_firlpfilter(%d, %d);\n"
           , tp_args[0], tp_args[1]
           );
    tp_num_elements++;
#else
    tp_length += 
    construct_firlpfilter(
            tp_packetbuf, tp_length, &tp_num_elements
            , (uint16_t)tp_args[0]  // uint16_t tag_in
            , (uint16_t)tp_args[1]  // uint16_t tag_out
            );
#endif        
}

/*************************************************************************
    Run-Length Encoding
*************************************************************************/
static void
tp_process_rle()
{
    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for rle\n");
        print_usage_rle();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_rle(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint16_t) tp_args[2]
        );
#endif
}
static void
tp_process_packbits()
{
    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for packbits\n");
        print_usage_packbits();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_packbits(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint16_t) tp_args[2]
        );
#endif
}

/*************************************************************************
    Dummy Vector
*************************************************************************/
static void
tp_process_vector()
{
    if (tp_argpos+1 != 3) {
        fprintf(stderr, "Warning: incorrect number of args for vector\n");
        print_usage_vector();
        exit(1);
    }
#ifdef TP_STANDALONE
    tp_num_elements++;
#else
    tp_length +=
    construct_vector(
            tp_packetbuf, tp_length, &tp_num_elements,
            (uint16_t) tp_args[0],
            (uint16_t) tp_args[1],
            (uint16_t) tp_args[2]
        );
#endif
}

/*************************************************************************
    Should be updated....
*************************************************************************/

void
tp_call_constructor (char* func)
{
    if (strcasecmp(func, "sample") == 0) tp_process_sample();
    else if (strcasecmp(func, "voltage") == 0) tp_process_voltage();
    
    /***** COUNT *********************************************************/
    else if (strcasecmp(func, "count") == 0) tp_process_count();
    else if (strcasecmp(func, "constant") == 0) tp_process_constant();
    
    /***** SEND **********************************************************/
    else if (strcasecmp(func, "send") == 0) tp_process_send();
    else if (strcasecmp(func, "sendpkt") == 0) tp_process_sendpkt();
    else if (strcasecmp(func, "sendstr") == 0) tp_process_sendstr();
    else if (strcasecmp(func, "sendrcrt") == 0) tp_process_sendrcrt();
    
    /***** GET ***********************************************************/
    else if (strcasecmp(func, "get") == 0) tp_process_get();
    else if (strcasecmp(func, "parent") == 0) tp_process_nexthop();
    else if (strcasecmp(func, "nexthop") == 0) tp_process_nexthop();
    else if (strcasecmp(func, "children") == 0) tp_process_children();
    else if (strcasecmp(func, "neighbors") == 0) tp_process_neighbors();
    else if (strcasecmp(func, "rfpower") ==0) tp_process_rfpower();
    else if (strcasecmp(func, "rfchannel") ==0) tp_process_rfchannel();
    else if (strcasecmp(func, "localtime") == 0) tp_process_localtime();
    else if (strcasecmp(func, "globaltime") == 0) tp_process_globaltime();
    else if (strcasecmp(func, "is_timesync") == 0) tp_process_istimesync();
    else if (strcasecmp(func, "memory_stats") == 0) tp_process_memory_stats();
    else if (strcasecmp(func, "leds") == 0) tp_process_leds();
    else if (strcasecmp(func, "num_tasks") == 0) tp_process_num_tasks();
    else if (strcasecmp(func, "num_active_tasks") == 0) tp_process_num_active_tasks();
    else if (strcasecmp(func, "nodeid") == 0) tp_process_nodeid();
    else if (strcasecmp(func, "local_address") == 0) tp_process_nodeid();
    else if (strcasecmp(func, "localtime_ms") == 0) tp_process_localtime_ms();
    else if (strcasecmp(func, "globaltime_ms") == 0) tp_process_globaltime_ms();
    else if (strcasecmp(func, "platform") == 0) tp_process_platform();
    else if (strcasecmp(func, "clock_freq") == 0) tp_process_clock_freq();
    else if (strcasecmp(func, "master") == 0) tp_process_master();
    else if (strcasecmp(func, "hopcount") == 0) tp_process_hopcount();
    else if (strcasecmp(func, "rssi") == 0) tp_process_rssi();
    else if (strcasecmp(func, "linkquality") == 0) tp_process_linkquality();

    /***** ISSUE *********************************************************/
    else if (strcasecmp(func, "issue") == 0) tp_process_issue();
    else if (strcasecmp(func, "repeat") == 0) tp_process_repeat();
    else if (strcasecmp(func, "wait") == 0) tp_process_wait();
    else if (strcasecmp(func, "wait_n_repeat") == 0) tp_process_wait_n_repeat();
    else if (strcasecmp(func, "globalrepeat") == 0) tp_process_globalrepeat();
    else if (strcasecmp(func, "alarm") == 0) tp_process_alarm();

    /***** ACTUATE *******************************************************/
    else if (strcasecmp(func, "actuate") ==0) tp_process_actuate();
    else if (strcasecmp(func, "set_leds") ==0) tp_process_set_leds();
    else if (strcasecmp(func, "set_rfpower") ==0) tp_process_set_rfpower();
    else if (strcasecmp(func, "sounder") ==0) tp_process_sounder();
    else if (strcasecmp(func, "toggle_leds") ==0) tp_process_toggle_leds();
    else if (strcasecmp(func, "leds0toggle") ==0) tp_process_leds0toggle();
    else if (strcasecmp(func, "leds1toggle") ==0) tp_process_leds1toggle();
    else if (strcasecmp(func, "leds2toggle") ==0) tp_process_leds2toggle();
    else if (strcasecmp(func, "reset_parent") ==0) tp_process_reset_parent();
    else if (strcasecmp(func, "hold_parent") ==0) tp_process_hold_parent();
    
    /***** STORAGE *******************************************************/
    else if (strcasecmp(func, "storage") ==0) tp_process_storage();
    else if (strcasecmp(func, "store") ==0) tp_process_store();
    else if (strcasecmp(func, "retrieve") ==0) tp_process_retrieve();
    else if (strcasecmp(func, "restore") ==0) tp_process_retrieve();
    
    /***** COMPARISON ****************************************************/
    else if (strcasecmp(func, "comparison") == 0) tp_process_comparison();
    else if (strcasecmp(func, "lt") == 0) tp_process_lt();
    else if (strcasecmp(func, "gt") == 0) tp_process_gt();
    else if (strcasecmp(func, "eq") == 0) tp_process_eq();
    else if (strcasecmp(func, "leq") == 0) tp_process_leq();
    else if (strcasecmp(func, "geq") == 0) tp_process_geq();
    else if (strcasecmp(func, "neq") == 0) tp_process_neq();
    else if (strcasecmp(func, "count_lt") == 0) tp_process_count_lt();
    else if (strcasecmp(func, "count_gt") == 0) tp_process_count_gt();
    else if (strcasecmp(func, "count_eq") == 0) tp_process_count_eq();
    else if (strcasecmp(func, "count_leq") == 0) tp_process_count_leq();
    else if (strcasecmp(func, "count_geq") == 0) tp_process_count_geq();
    else if (strcasecmp(func, "count_neq") == 0) tp_process_count_neq();
    
    /***** STATS *********************************************************/
    else if (strcasecmp(func, "stats") == 0) tp_process_stats();
    else if (strcasecmp(func, "sum") == 0) tp_process_sum();
    else if (strcasecmp(func, "min") == 0) tp_process_min();
    else if (strcasecmp(func, "max") == 0) tp_process_max();
    else if (strcasecmp(func, "avg") == 0) tp_process_avg();
    else if (strcasecmp(func, "std") == 0) tp_process_std();
    else if (strcasecmp(func, "cnt") == 0) tp_process_cnt();
    else if (strcasecmp(func, "meandev") == 0) tp_process_meandev();
    
    /***** LOGICAL *******************************************************/
    else if (strcasecmp(func, "logical") == 0) tp_process_logical();
    else if (strcasecmp(func, "logical_and") == 0) tp_process_logical_and();
    else if (strcasecmp(func, "and") == 0) tp_process_logical_and();
    else if (strcasecmp(func, "logical_or") == 0) tp_process_logical_or();
    else if (strcasecmp(func, "or") == 0) tp_process_logical_or();
    else if (strcasecmp(func, "logical_not") == 0) tp_process_logical_not();
    else if (strcasecmp(func, "not") == 0) tp_process_logical_not();

    /***** BIT ***********************************************************/
    else if (strcasecmp(func, "bit") == 0) tp_process_bit();
    else if (strcasecmp(func, "bit_and") == 0) tp_process_bit_and();
    else if (strcasecmp(func, "bit_or") == 0) tp_process_bit_or();
    else if (strcasecmp(func, "bit_not") == 0) tp_process_bit_not();
    else if (strcasecmp(func, "bit_xor") == 0) tp_process_bit_xor();
    else if (strcasecmp(func, "bit_nand") == 0) tp_process_bit_nand();
    else if (strcasecmp(func, "bit_nor") == 0) tp_process_bit_nor();
    else if (strcasecmp(func, "shiftleft") == 0) tp_process_shiftleft();
    else if (strcasecmp(func, "shiftright") == 0) tp_process_shiftright();

    /***** ARITH *********************************************************/
    else if (strcasecmp(func, "arith") == 0) tp_process_arith();
    else if (strcasecmp(func, "add") == 0) tp_process_add();
    else if (strcasecmp(func, "sub") == 0) tp_process_sub();
    else if (strcasecmp(func, "mult") == 0) tp_process_mult();
    else if (strcasecmp(func, "div") == 0) tp_process_div();
    else if (strcasecmp(func, "diff") == 0) tp_process_diff();
    else if (strcasecmp(func, "mod") == 0) tp_process_mod();
    else if (strcasecmp(func, "pow") == 0) tp_process_pow();

    /***** ATTRIBUTE *****************************************************/
    else if (strcasecmp(func, "attribute") == 0) tp_process_attribute();
    else if (strcasecmp(func, "exist") == 0) tp_process_exist();
    else if (strcasecmp(func, "not_exist") == 0) tp_process_not_exist();
    else if (strcasecmp(func, "length") == 0) tp_process_length();

    /***** DELETE*IF *****************************************************/
    else if (strcasecmp(func, "deleteattribute") == 0) tp_process_deleteAttribute();
    else if (strcasecmp(func, "deleteattributeif") == 0) tp_process_deleteAttributeIf();
    else if (strcasecmp(func, "deleteallattributeif") == 0) tp_process_deleteAllAttributeIf();
    else if (strcasecmp(func, "deleteactivetaskif") == 0) tp_process_deleteActiveTaskIf();
    else if (strcasecmp(func, "deletetaskif") == 0) tp_process_deleteTaskIf();
    
    /***** REBOOT / PACK / USER_BUTTON / MEMORY_OP ***********************/
    else if (strcasecmp(func, "reboot") == 0) tp_process_reboot();
    else if (strcasecmp(func, "pack") == 0) tp_process_pack();
    else if (strcasecmp(func, "pack_n_wait") == 0) tp_process_pack_n_wait();
    else if (strcasecmp(func, "memoryop") == 0) tp_process_memoryop();
    else if (strcasecmp(func, "userbutton") == 0) tp_process_user_button();

    /***** SECURITY ***********************/
    else if (strcasecmp(func, "security") == 0) tp_process_security();

#ifdef INCLUDE_CYCLOPS
    /***** IMAGE *********************************************************/
    else if (strcasecmp(func, "image") == 0) tp_process_image();
    else if (strcasecmp(func, "image_snap") == 0) tp_process_image_snap();
    else if (strcasecmp(func, "image_get") == 0) tp_process_image_get();
    else if (strcasecmp(func, "image_detect") == 0) tp_process_image_detect();
    else if (strcasecmp(func, "image_detect_params") == 0) tp_process_image_detect_params();
    else if (strcasecmp(func, "image_detect_reset") == 0) tp_process_image_detect_reset();
    else if (strcasecmp(func, "image_detect_set") == 0) tp_process_image_detect_set();
    else if (strcasecmp(func, "image_set_capture_params") == 0) tp_process_image_set_capture_params();
    else if (strcasecmp(func, "image_get_capture_params") == 0) tp_process_image_get_capture_params();
    else if (strcasecmp(func, "image_reboot") == 0) tp_process_image_reboot();
    else if (strcasecmp(func, "image_getRle") == 0) tp_process_image_getRle();
    else if (strcasecmp(func, "image_getPackBits") == 0) tp_process_image_getPackBits();
    else if (strcasecmp(func, "image_copy") == 0) tp_process_image_copy();
#endif
    
    /***** RLE ***********************************************************/
    else if (strcasecmp(func, "rle") == 0) tp_process_rle();
    else if (strcasecmp(func, "packbits") == 0) tp_process_packbits();
    else if (strcasecmp(func, "vector") == 0) tp_process_vector();

    /***** FILTER ********************************************************/
    else if (strcasecmp(func, "onset_detector") == 0) tp_process_onset_detector();
    else if (strcasecmp(func, "lpfilter") == 0) tp_process_firlpfilter();

    /***** PEG ***********************************************************/
    else if (strcasecmp(func, "sample_rssi") == 0) tp_process_sample_rssi();

    /***** WISDEN ********************************************************/
    else if (strcasecmp(func, "mda400") == 0) tp_process_mda400();

    /***** MDA300 ********************************************************/
    else if (strcasecmp(func, "mda300") == 0) tp_process_mda300();

    /***** OLD ***********************************************************/
    else if (strcasecmp(func, "fastsample") == 0) tp_process_fastsample();
    else {
        fprintf(stderr, "\n Warning: unknown task element %s in task chain, aborting\n\n", func);
        print_tasklet_usage_guess(func, 2);
        exit(1);
    }

    tp_init_args();
    return;
}

/****************************************/

int
yyerror (char *s)
{
  fprintf (stderr, "%s\n", s);
  abort_due_to_error = 1;
  return -1;
}

#ifdef TP_STANDALONE

/* For standalone testing: the compiled program takes the task
   description string as argument.
*/
int
main (int argc,
      char *argv[])
{
    tp_doit("", argv[1]);
    return 0;
}

#else

/* Call this function in the task library. After this function returns,
   the buf should be filled correctly.
 */
int
tp_parse_task(unsigned char* buf,   /* Pointer to packet buffer */
              char* task)           /* Task description string */
{
    tp_doit(buf, task);
    if (abort_due_to_error == 1) {
        tp_length = -1;
    } else {
    #ifdef DEBUG_PARSER
        printf("tp: length of task packet = %d\n", tp_length);
        printf("tp: number of elements    = %d\n", tp_num_elements);
    #endif
    }
    return tp_length;
}

#endif


