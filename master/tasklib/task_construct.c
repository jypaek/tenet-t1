
/**
 * Task Construct.
 *
 * Given a task string, call the parser, 
 * and transform it to a tasking packet format for motes.
 *
 *
 * Embedded Networks Laboratory, University of Southern California
 * @modified 6/23/2007
 **/

#include <string.h>
#include "task_construct.h"
#include "element_construct.h"
#ifdef BUILDING_PC_SIDE
#include "tp.h"
#endif

/**
 * Given a task string, transform it to a tasking packet
 **/
int construct_task(unsigned char *buf, char *task_string) {
    int l = -1;
    
    l = parse_test_task_string(buf, task_string); // for testing only.

#ifdef BUILDING_PC_SIDE
    if (l < 0)
        l = tp_parse_task(buf, task_string);    // actual task parser
#endif

    return l;
}



/**********************************************************************
 Functions below this line are/were used for testing task construction.
 They are deprecated, but the code let's you understand how tasking
 packets are constructed by the parser 'tp_parse_task'.
 **********************************************************************/

int parse_test_task_string(unsigned char *buf, char *task_name) {
    int l;
    if (!strcasecmp(task_name,"Blink"))
        l = blink_packet(buf);
    else if (!strcasecmp(task_name,"CntToLedsAndRfm"))
        l = cnt_to_leds_and_rfm_packet(buf);
    else if (!strcasecmp(task_name,"SenseToRfm"))
        l = sense_to_rfm_packet(buf);
    else if (!strcasecmp(task_name, "Reboot"))
        l = reboot_packet(buf);
    else
        l = -1;
    return l;
}

int blink_packet(unsigned char *buf) {
    int len = 0, num_elements = 0;
    len = construct_init(buf);
    len += construct_issue(buf, len, &num_elements, 1000, 500, 0);
    len += construct_count(buf, len, &num_elements, 0x111, 0, 1);
    len += construct_actuate(buf, len, &num_elements, ACTUATE_LEDS, ARGTYPE_ATTRIBUTE, 0x111);
    len += construct_finalize(buf, num_elements);
    return len;
}

int cnt_to_leds_and_rfm_packet(unsigned char *buf){
    int len = 0, num_elements = 0;
    len = construct_init(buf);
    len += construct_issue(buf, len, &num_elements, 1000, 500, 0);
    len += construct_count(buf, len, &num_elements, 0x44, 0, 1);
    len += construct_actuate(buf, len, &num_elements, ACTUATE_LEDS, ARGTYPE_ATTRIBUTE, 0x44);
    len += construct_send(buf, len, &num_elements, 0);
    len += construct_finalize(buf, num_elements);
    return len;
}

int sense_to_rfm_packet(unsigned char *buf){
    int len = 0, num_elements = 0;
    len = construct_init(buf);
    len += construct_issue(buf, len, &num_elements, 1000, 500, 0);
    //len += construct_simplesample(buf, len, &num_elements, TEMPERATURE, 0x55);
    len += construct_sample(buf, len, &num_elements, 0, 1, 0, TEMPERATURE, 0x55);
    len += construct_send(buf, len, &num_elements, 0);
    len += construct_finalize(buf, num_elements);
    return len;
}

int reboot_packet(unsigned char *buf) {
    int len = 0, num_elements = 0;
    len = construct_init(buf);
    len += construct_reboot(buf, len, &num_elements);
    len += construct_finalize(buf, num_elements);
    return len;
}

