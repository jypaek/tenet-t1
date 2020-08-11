/*
* "Copyright (c) 2006-2007 University of Southern California.
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
 * Header file for how to use each tasklet function.
 *
 */
void print_usage_sample();
void print_usage_voltage();
void print_usage_temperature();
void print_usage_photo_sensor();

void print_usage_count();
void print_usage_constant();

void print_usage_issue();
void print_usage_repeat();
void print_usage_wait();
void print_usage_alarm();
void print_usage_globalrepeat();

void print_usage_actuate();
void print_usage_set_leds();
void print_usage_set_rfpower();
void print_usage_sounder();
void print_usage_toggle_leds();
void print_usage_reset_parent();
void print_usage_hold_parent();

void print_usage_logical();

void print_usage_bit();

void print_usage_arith();
void print_usage_add();
void print_usage_sub();
void print_usage_mult();
void print_usage_div();
void print_usage_diff();
void print_usage_mod();
void print_usage_pow();

void print_usage_get();
void print_usage_nexthop();
void print_usage_children();
void print_usage_neighbors();
void print_usage_globaltime();
void print_usage_localtime();
void print_usage_rfpower();
void print_usage_rfchannel();
void print_usage_memory_stats();
void print_usage_leds();
void print_usage_num_tasks();
void print_usage_num_active_tasks();
void print_usage_istimesync();
void print_usage_nodeid();
void print_usage_platform();
void print_usage_clock_freq();
void print_usage_master();
void print_usage_hopcount();
void print_usage_rssi();
void print_usage_linkquality();

void print_usage_send();
void print_usage_sendpkt();
void print_usage_sendstr();
void print_usage_sendrcrt();

void print_usage_storage();

void print_usage_comparison();
void print_usage_lt();
void print_usage_gt();
void print_usage_eq();
void print_usage_leq();
void print_usage_geq();
void print_usage_neq();
void print_usage_count_lt();
void print_usage_count_gt();
void print_usage_count_eq();
void print_usage_count_leq();
void print_usage_count_geq();
void print_usage_count_neq();

void print_usage_stats();
void print_usage_sum();
void print_usage_min();
void print_usage_max();
void print_usage_avg();
void print_usage_std();
void print_usage_cnt();
void print_usage_meandev();

void print_usage_attribute();
void print_usage_exist();
void print_usage_not_exist();
void print_usage_length();

void print_usage_deleteattributeif();
void print_usage_deleteattribute();
void print_usage_deletetaskif();
void print_usage_deleteactivetaskif();

void print_usage_image();
void print_usage_image_snap();
void print_usage_image_get();
void print_usage_image_detect();
void print_usage_image_detect_params();
void print_usage_image_set_capture_params();
void print_usage_image_get_capture_params();
void print_usage_image_reboot();
void print_usage_image_getrle();
void print_usage_image_getpackbits();

void print_usage_reboot();
void print_usage_pack();
void print_usage_user_button();

void print_usage_onset_detector();
void print_usage_firlpfilter();
void print_usage_rle();
void print_usage_packbits();
void print_usage_vector();

void print_tasklet_usage_guess(char *func, int n);
void print_tasklet_usage_all();

