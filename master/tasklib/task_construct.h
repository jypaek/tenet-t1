/*
 * Header File
 * Given a string, call  the parse, and transform it to packet format for motes
 */
#ifndef TASK_CONSTRUCT_H
#define TASK_CONSTRUCT_H

int construct_task(unsigned char *buf, char *task_name);

int parse_test_task_string(unsigned char *buf, char *task_name);
int blink_packet(unsigned char *buf);
int cnt_to_leds_and_rfm_packet(unsigned char *buf);
int sense_to_rfm_packet(unsigned char *buf);
int reboot_packet(unsigned char *buf);

#endif

