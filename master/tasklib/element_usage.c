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
 * Functions that display how to use each tasklet in Tenet.
 * When creating a new tasklet, you should also add it in this file.
 *
 * @author Jeongyeup Paek
 * @author Omprakash Gnawali
 * @author Marcos Mviera
 * @author Ki-Young Jang
 * @modified 7/2/2007
 **/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "element_usage.h"

void print_usage_sample() {
    printf(" sample(interval, count, repeat, channel, out),\n");
    printf(" sample(interval, count, channel, out),\n");
    printf(" sample(interval, channel, out),\n");
    printf(" sample(channel, out) :\n");
    printf("            - Read ADC channel 'channel' every 'interval' millisec and\n");
    printf("              output 'count' number of samples in an attribute 'out'.\n");
    printf("              Repeat this process if 'repeat'.\n");
    printf("            - Syntax:\n");
    printf("              - sample() tasklet provides four different APIs :\n");
    printf("                [1] sample(interval, count, repeat, channel, out) :\n");
    printf("                    - default API\n");
    printf("                [2] sample(interval, count, channel, out) :\n");
    printf("                    - does not repeat.\n");
    printf("                [3] sample(interval, channel, out) :\n");
    printf("                    - sample 'channel' repeatedly every 'interval'\n");
    printf("                      and output one sample at a time in an attribute.\n");
    printf("                [4] sample(channel, out) :\n");
    printf("                    - sample 'channel' once. one sample, no repeat\n");
    printf("            - Channel list:\n");
    printf("              - Telosb mote\n");
    printf("                - 20 = Humididty Sensor\n");
    printf("                - 21 = Temperature Sensor\n");
    printf("                - 22 = Total Solar Radiation Light Sensor\n");
    printf("                - 23 = Photosynthetically Acitve Radiation Light Sensor\n");
    printf("                - 24 = Internal Temperature Sensor\n");
    printf("                - 25 = Internal Voltage Sensor\n");
    printf("              - MicaZ mote with micasb,\n");
    printf("                - 21 = Temperature Sensor\n");
    printf("                - 25 = Internal Voltage Sensor\n");
    printf("                - 26 = Photo Sensor\n");
    printf("                - 27 = Acceleration Sensor X\n");
    printf("                - 28 = Acceleration Sensor Y\n");
    printf("            - Example: get one sample every 1 sec\n");
    printf("              - sample(1000,1,1,22,0x10)\n");
}
void print_usage_voltage() {
    printf(" voltage(out)             : sample voltage and return in 'out' attribute.\n");
}
/****************************************************************/
void print_usage_count() {
    printf(" count(attr, value, rate) : create an attribute with value 'value'.\n");
    printf("                            increment 'value' by 'rate' everytime it runs.\n");
    printf(" count(attr)              : create an attribute that has scalar value starting\n");
    printf("                            at '0' and incremented by '1' everytime it runs.\n");
}
void print_usage_constant() {
    printf(" constant(attr, value)    : create an attribute with a constant 'value'.\n");
}
/****************************************************************/
void print_usage_issue() {
    printf(" issue(starttime, period, abs) :\n");
    printf("                          - execute rest of the task after 'starttime',\n");
    printf("                            and periodially with period 'period'.\n");
    printf("                          - 'starttime' is in mote ticks (32768kHz),\n");
    printf("                            'period' is in millisecodns.\n");
    printf("                          - if 'abs' is 1, starttime is globaltime.\n");
}
void print_usage_wait() {
    printf(" wait(period)             : wait for 'period' ms once.\n");
    printf("\n");
    printf(" wait(period, repeat)     : ## deprecated. exists for backward compatibility.\n");
    printf("                            if 'repeat', run every 'period' ms\n");
    printf("                            else, wait for 'period' once.\n");
    printf("\n");
    printf(" wait_n_repeat(firstwait, period) :\n");
    printf("                          - wait for 'firstwait' ms,\n");
    printf("                            and then run every 'period' ms.\n");
}
void print_usage_repeat() {
    printf(" repeat(period)           : repeat rest of the task every 'period' ms\n");
}
void print_usage_alarm() {
    printf(" alarm(gtime)             : waits until (alarms at) global time 'gtime'\n");
}
void print_usage_globalrepeat() {
    printf(" globalrepeat(start, period) :\n");
    printf("                          - waits until (alarms at) global time 'start',\n");
    printf("                            and then run every global 'period'.\n");
    printf("                          - 'period' is ms synchronized by timesync\n");
}
/****************************************************************/
void print_usage_actuate() {
    printf(" actuate(channel, value)  : actuates a particular channel'channel'.\n");
    printf("                            legal 'channel' are defined in 'tenet_task.h'\n");
}
void print_usage_set_leds() {
    printf(" set_leds(value)          : set leds to constant 'value' or attribute value\n");
}
void print_usage_toggle_leds() {
    printf(" toggle_leds(value)       : toggle leds based on three LSB of 'value' or attribute value\n");
    printf(" leds0toggle()            : toggle led 0\n");
    printf(" leds1toggle()            : toggle led 1\n");
    printf(" leds2toggle()            : toggle led 2\n");
}
void print_usage_set_rfpower() {
    printf(" set_rfpower(value)       : set rfpower to 'value' (3~31) or attribute value\n");
}
void print_usage_sounder() {
    printf(" sounder(value)           : start sounder if 'value' > 0 or attribute value > 0. otherwise stop. \n");
}
void print_usage_reset_parent() {
    printf(" reset_parent()           : reset routing state \n");
}
void print_usage_hold_parent() {
    printf(" hold_parent()            : hold routing state \n");
}
/****************************************************************/
void print_usage_logical() {
    printf(" logical(result, attr, optype, value) : \n");
    printf("                          - Perform logical operation specified by optype\n");
    printf("                          - Legal values for 'optype' are :\n");
    printf("                            - 11 or &&   : Logical AND\n");
    printf("                            - 12 or ||   : Logical OR\n");
    printf("                            - 13 or !    : Logical NOT\n");
    printf(" \n");
    printf(" logical_and(result, attr1, arg)\n");
    printf(" = and(result, attr1, arg) :\n");
    printf("                          - result = attr1 AND arg (constant or attribute)\n");
    printf(" logical_or(result, attr1, arg)\n");
    printf(" = or(result, attr1, arg) :\n");
    printf("                          - result = attr1 OR arg (constant or attribute)\n");
    printf(" logical_not(result, arg)\n");
    printf(" = not(result, arg) :\n");
    printf("                          - result = NOT arg (constant or attribute)\n");
}
/****************************************************************/
void print_usage_bit() {
    printf(" bit(result, attr, optype, value) : \n");
    printf("                          - Perform the bit operation specified by optype\n");
    printf("                          - Legal values for 'optype' are :\n");
    printf("                            - 1 or &   : Bitwise AND\n");
    printf("                            - 2 or |   : Bitwise OR\n");
    printf("                            - 3 or !   : Bitwise NOT\n");
    printf("                            - 4        : Bitwise XOR\n");
    printf("                            - 5        : Bitwise NAND\n");
    printf("                            - 6        : Bitwise NOR\n");
    printf("                            - 7 or <<  : Shift left\n");
    printf("                            - 8 or >>  : Shifh right\n");
    printf(" \n");
    printf(" bit_and(result, attr1, arg)\n");
    printf("                          - result = attr1 AND arg (constant or attribute)\n");
    printf(" bit_or(result, attr1, arg)\n");
    printf("                          - result = attr1 OR arg (constant or attribute)\n");
    printf(" bit_not(result, arg)\n");
    printf("                          - result = NOT arg (constant or attribute)\n");
    printf(" bit_xor(result, attr1, arg)\n");
    printf("                          - result = attr1 XOR arg (constant or attribute)\n");
    printf(" bit_nand(result, attr1, arg)\n");
    printf("                          - result = attr1 NAND arg (constant or attribute)\n");
    printf(" bit_nor(result, attr1, arg)\n");
    printf("                          - result = attr1 NOR arg (constant or attribute)\n");
    printf(" shiftleft(result, attr1, arg)\n");
    printf("                          - result = attr1 << arg (constant or attribute) \n");
    printf(" shiftright(result, attr1, arg)\n");
    printf("                          - result = attr1 >> arg (constant or attribute) \n");
}
/****************************************************************/
void print_usage_arith() {
    printf(" arith(result, attr, optype, arg) :\n");
    printf("                          - Perform arithmetic operation \n");
    printf("                          - Legal values for 'optype' are :\n");
    printf("                            - 1 or +   : ADD\n");
    printf("                            - 2 or -   : SUB\n");
    printf("                            - 3 or *   : MULT\n");
    printf("                            - 4 or /   : DIV\n");
    printf("                            - 5        : DIFF\n");
    printf("                            - 6 or %%  : MOD\n");
    printf("                            - 7 or ^   : POW\n");
    printf(" \n");
}
void print_usage_add() {
    printf(" add(result, attr1, arg)  : result = attr1 + arg (constant or attribute)\n");
}
void print_usage_sub() {
    printf(" sub(result, attr1, arg)  : result = attr1 - arg (constant or attribute)\n");
}
void print_usage_div() {
    printf(" div(result, attr1, arg)  : result = attr1 / arg (constant or attribute)\n");
}
void print_usage_mult() {
    printf(" mult(result, attr1, arg) : result = attr1 * arg (constant or attribute)\n");
}
void print_usage_diff() {
    printf(" diff(result, attr1, arg) : result = |attr1 - arg| (constant or attribute)\n");
}
void print_usage_mod() {
    printf(" mod(result, attr1, arg)  : result = attr1 mod arg (constant or attribute)\n");
}
void print_usage_pow() {
    printf(" pow(result, attr1, arg)  : result = attr1 ^ arg (constant or attribute)\n");
}
/****************************************************************/
void print_usage_get() {
    printf(" get(attr, value)         : get system value 'value' and put it in attr\n");
    printf("                          : legal 'value's are defined in 'tenet_task.h'\n");
}
void print_usage_nexthop() {
    printf(" nexthop(attr)            : put next-hop (routing parent) into attr\n");
}
void print_usage_neighbors() {
    printf(" neighbors(attr)          : put list of neighbors into attr\n");
}
void print_usage_children() {
    printf(" children(attr)           : put list of routing children into attr\n");
}
void print_usage_globaltime() {
    printf(" globaltime(attr)         : put 32bit global time (timesynch'ed) into attr\n");
}
void print_usage_localtime() {
    printf(" localtime(attr)          : put 32-bit local time of the mote into attr\n");
}
void print_usage_rfpower() {
    printf(" rfpower(attr)            : put RF power into attr\n");
}
void print_usage_rfchannel() {
    printf(" rfchannel(attr)          : put RF channel into attr\n");
}
void print_usage_memory_stats() {
    printf(" memory_stats(attr)       : put memory stats (RAM,RAMptr,maxRAM,maxRAMptr) in attr\n");
}
void print_usage_leds() {
    printf(" leds(attr)               : put the state of the LEDs into attr\n");
}
void print_usage_num_tasks() {
    printf(" num_tasks(attr)          : put number of tasks in the mote into attr\n");
}
void print_usage_num_active_tasks() {
    printf(" num_active_tasks(attr)   : put number of active tasks in the mote into attr\n");
}
void print_usage_istimesync() {
    printf(" is_timesync(attr)        : put 1 or 0 (whether time synch'ed) into attr\n");
}
void print_usage_nodeid() {
    printf(" nodeid(attr)             : put TOS_LOCAL_ADDRESS into attr\n");
    printf(" local_address(attr)      : put TOS_LOCAL_ADDRESS into attr\n");
}
void print_usage_platform() {
    printf(" platform(attr)           : put platform ('1' for telosb, '2' for micaz) into attr\n");
}
void print_usage_clock_freq() {
    printf(" clock_freq(attr)         : put clock frequency into attr\n");
}
void print_usage_master() {
    printf(" master(attr)             : put current routing master into attr\n");
}
void print_usage_hopcount() {
    printf(" hopcount(attr)           : put current routing hopcount into attr\n");
}
void print_usage_rssi() {
    printf(" rssi(attr)               : put parent rssi(dbm, int16_t) to attr\n");
}
void print_usage_linkquality() {
    printf(" linkquality(attr)        : put parent link quality into attr\n");
}
/****************************************************************/
void print_usage_send() {
    printf(" send(type)               : send response using 'type' transport\n");
    printf("                            - 0 : best-effort transport\n");
    printf("                            - 1 : reliable packet transport (E2E_ACK)\n");
    printf("                            - 2 : reliable stream transport\n");
    printf("                            - 3 : rcrt (if compiled with)\n");
}
void print_usage_sendpkt() {
    printf(" sendpkt(type)            : send response using 'type' packet transport\n");
    printf("                            - 0 : best-effort transport\n");
    printf("                            - 1 : reliable packet transport (E2E_ACK)\n");
}
void print_usage_sendstr() {
    printf(" sendstr()                : send response using stream transport\n");
}
void print_usage_sendrcrt() {
    printf(" sendrcrt(irate)          : send response using rate-controlled reliable transport\n");
    printf("                          : 'irate' is the minimum inter-packet interval in millisec\n");
}
/****************************************************************/
void print_usage_storage() {
    printf(" storage(attr1, attr2, store) :\n");
    printf("                          - store if 'store', otherwise retrieve.\n");
    printf("                          - get 'attr1' and put it in 'attr2'.\n");
    printf("                          - storage is valid within a task, across active tasks\n");
    printf(" \n");
    printf(" store(attr1)             : store 'attr1' into storage.\n");
    printf(" store(attr1, attr2)      : store 'attr1' into storage with new name 'attr2'.\n");
    printf(" retrieve(attr1)          : retrieve 'attr1' from storage.\n");
    printf(" retrieve(attr1, attr2)   : retrieve 'attr1' from storage with new name 'attr2'.\n");
}
/****************************************************************/
void print_usage_comparison() {
    printf(" comparison(result, attr, optype, arg),\n");
    printf(" = compare(result, attr, optype, arg) :\n");
    printf("                          - perform comparison operation \n");
    printf("                          - legal 'optype' is defined in 'tenet_task.h'\n");
    printf("                            - 11 or <    : Less than\n");
    printf("                            - 12 or >    : Greater than\n");
    printf("                            - 13 or ==   : Equal\n");
    printf("                            - 14 or <=   : Less than or equal\n");
    printf("                            - 15 or >=   : Greater than or equal\n");
    printf("                            - 16 or !=   : Not equal\n");
    printf("                            - 21         : Count less than\n");
    printf("                            - 22         : Count greater than\n");
    printf("                            - 23         : Count equal\n");
    printf("                            - 24         : Count less than or equal\n");
    printf("                            - 25         : Count greater than or equal\n");
    printf("                            - 26         : Count not equal\n");
    printf(" \n");
}
void print_usage_lt() {
    printf(" lt(result, attr, arg)      : if ( attr < arg ) result = 1,\n");
    printf("                              else result = 0\n");
}
void print_usage_gt() {
    printf(" gt(result, attr, arg)      : if ( attr > arg ) result = 1,\n");
    printf("                              else result = 0\n");
}
void print_usage_eq() {
    printf(" eq(result, attr, arg)      : if ( attr == arg ) result = 1\n");
    printf("                              else result = 0\n");
}
void print_usage_leq() {
    printf(" leq(result, attr, arg)     : if ( attr <= arg ) result = 1,\n");
    printf("                              else result = 0\n");
}
void print_usage_geq() {
    printf(" geq(result, attr, arg)     : if ( attr >= arg ) result = 1,\n");
    printf("                              else result = 0\n");
}
void print_usage_neq() {
    printf(" neq(result, attr, arg)     : if ( attr != arg ) result = 1,\n");
    printf("                              else result = 0\n");
}
void print_usage_count_lt() {
    printf(" count_lt(result, attr, arg) : result = number of data in attr that (data < arg)\n");
}
void print_usage_count_gt() {
    printf(" count_gt(result, attr, arg) : result = number of data in attr that (data > arg)\n");
}
void print_usage_count_eq() {
    printf(" count_eq(result, attr, arg) : result = number of data in attr that (data == arg )\n");
}
void print_usage_count_leq() {
    printf(" count_leq(result, attr, arg) : result = number of data in attr that (data <= arg )\n");
}
void print_usage_count_geq() {
    printf(" count_geq(result, attr, arg) : result = number of data in attr that (data >= arg)\n");
}
void print_usage_count_neq() {
    printf(" count_neq(result, attr, arg) : result = number of data in attr that(data != arg)\n");
}
/****************************************************************/
void print_usage_stats() {
    printf(" stats(result, attr, optype) :\n");
    printf("                          - perform statistical operation \n");
    printf("                          - legal 'optype' is defined in 'tenet_task.h'\n");
    printf("                            - 1 : Sum\n");
    printf("                            - 2 : Minimum\n");
    printf("                            - 3 : Maximum\n");
    printf("                            - 4 : Average\n");
//    printf("                          - 5 : Standard deviation\n");
    printf("                            - 6 : Count\n");
    printf(" \n");
}
void print_usage_sum() {
    printf(" sum(result, attr)        : result = sum of the data in attr\n");
}
void print_usage_min() {
    printf(" min(result, attr)        : result = minimum of the data in attr\n");
}
void print_usage_max() {
    printf(" max(result, attr)        : result = maximum of the data in attr\n");
}
void print_usage_avg() {
    printf(" avg(result, attr)        : result = average of the data in attr\n");
}
void print_usage_std() {
//    printf(" std(result, attr)      : result = standard deviation of the data in attr\n");
}
void print_usage_cnt() {
    printf(" cnt(result, attr)        : result = count of the data in attr\n");
}
void print_usage_meandev() {
    printf(" meandev(result, attr)    : result = mean deviation of the data in attr\n");
}

/****************************************************************/
void print_usage_reboot() {
    printf(" reboot()                 : reboot the mote\n");
}
/****************************************************************/
void print_usage_user_button() {
    printf(" user_button(repeat)      : task awaits on an input to the user-button (on telosb only)\n");
    printf("                          : if (repeat == 1), task repeats at every user button pressed\n");
}
/****************************************************************/
void print_usage_deleteattributeif() {
    printf(" deleteattributeif(arg, attr) :\n");
    printf("                          - delete the attribute attr if arg is non 0\n");
    printf(" deleteattribute(attr) :\n");
    printf("                          - delete the attribute attr\n");
    printf(" deleteallattributeif(arg) :\n");
    printf("                          - delete all attributes if arg is non 0\n");
}
void print_usage_deletetaskif() {
    printf(" deletetaskif(arg)        : delete the task including all active instances\n");
    printf("                            if arg is non 0\n");
}
void print_usage_deleteactivetaskif() {
    printf(" deleteactivetaskif(arg)  : delete active instance of this task if arg != 0\n");
}
/****************************************************************/
void print_usage_pack() {
    printf(" pack(attr, size)         : pack scalar value 'attr' into a vector of 'size'.\n");
    printf("                            when the vector is full, output it as 'attr'.\n");
    printf("                            otherwise, proceed without any output.\n");
    printf(" pack(attr, size, block)  : same as 'pack(attr, size)' but deletes(blocks)\n");
    printf("                            the active instance if 'block == 1'.\n");
    printf(" pack_n_wait(attr, size)  : same as 'pack(attr, size, 1)'\n");
}
/****************************************************************/
void print_usage_attribute() {
    printf(" attribute(result, attr, optype) :\n");
    printf("                          - check an attribute \n");
    printf("                          - legal 'optype' is defined in 'tenet_task.h'\n");
    printf("                            - 1 : Exist     (result = 1 if attr exists)\n");
    printf("                            - 2 : Not-exist (result = 1 if attr does not exist)\n");
    printf("                            - 3 : Length    (result = length of attr vector(in uint16, not bytes))\n");
}
void print_usage_exist(){
    printf(" exist(result, attr)      : result = 1, if attr exists\n");
}
void print_usage_not_exist(){
    printf(" not_exist(result, attr)  : result = 1, if attr does not exist\n");
}
void print_usage_length(){
    printf(" length(result, attr)     : result = length of attr vector\n");
}
/****************************************************************/
void print_usage_image() {
    printf(" image(enFlash, fragSize, imgType, xSize, ySize, out0)\n");
    printf("                               : take a new image and get it from cyclops.\n");
    printf("                                  'enFlash'    - 1 = enable, 0 = disable\n");
    printf("                                  'fragSize'   - num.data.bytes per fragment\n");
    printf("                                  'imgType'    - 16 = B/W, 17 = Color\n");
    printf("                                  'xSize'      - in pixels. e.g. 128\n");
    printf("                                  'ySize'      - in pixels. e.g. 128\n");
    printf("                                  'out0'       - attr_t tag for return data\n");
}
void print_usage_image_snap() {
    printf(" image_snap(flash, imgtype, x, y, out0)\n");
    printf("                               : take an image of 'imgtype' and size (x,y),\n");
    printf("                               : and store it in cyclops-local memory.\n");
    printf("                               : use flash if 'flash'\n");
}
void print_usage_image_get() {
    printf(" image_get(newImage, enFlash, fragSize, imgType, xSize, ySize, out0)\n");
    printf("                               : get image from cyclops.\n");
    printf("                                  'newImage'   - 0 = take new, 1 = from memory\n");
    printf("                                  'enFlash'    - 1 = enable, 0 = disable\n");
    printf("                                  'fragSize'   - num.data.bytes per fragment\n");
    printf("                                  'imgType'    - 16 = B/W, 17 = Color\n");
    printf("                                  'xSize'      - in pixels. e.g. 128\n");
    printf("                                  'ySize'      - in pixels. e.g. 128\n");
    printf("                                  'out0'       - attr_t tag for return data\n");
}
void print_usage_image_detect() {
    printf(" image_detect(type, use_segment, flash, imgres, out0)\n");
    printf("                               : perform background-subtraction-base object detection\n");
}
void print_usage_image_detect_params() {
    printf(" image_detect_params(ImsgRes, RACoeff, skip, illCoeff, range, detectThresh)\n");
    printf("                               : set parameters for object detection alg.\n");
}
void print_usage_image_set_capture_params() {
    printf(" image_set_capture_params(offset_x, offset_y, inputSize_x, inputSize_y, testMode, \n");
    printf("                  exposurePeriod, analog_red, analog_green, analog_blue, \n");
    printf("                  digital_red, digital_green, digital_blue, runTime, \n");
    printf("                  out_tag)\n");
}
void print_usage_image_get_capture_params() {
    printf(" image_get_capture_params(out_tag)\n");
}
void print_usage_image_reboot() {
    printf(" image_reboot()                : reboot cyclops. (cyclops only, not the host mote)\n");
}
void print_usage_image_getrle() {
    printf(" image_getRle(newImage, enFlash, fragSize, imgType, xSize, ySize, threshold, out0)\n");
    printf("                               : get image from cyclops.\n");
    printf("                                  'newImage'   - 0 = take new, 1 = from memory\n");
    printf("                                  'enFlash'    - 1 = enable, 0 = disable\n");
    printf("                                  'fragSize'   - num.data.bytes per fragment\n");
    printf("                                  'imgType'    - 16 = B/W, 17 = Color\n");
    printf("                                  'xSize'      - in pixels. e.g. 128\n");
    printf("                                  'ySize'      - in pixels. e.g. 128\n");
    printf("                                  'threshold'  - Lossy RLE threshold (e.g. 20)\n");
    printf("                                  'out0'       - attr_t tag for return data\n");
}
void print_usage_image_getpackbits() {
    printf(" image_getPackBits(newImage, enFlash, fragSize, imgType, xSize, ySize, threshold, out0)\n");
    printf("                               : get image from cyclops.\n");
    printf("                                  'newImage'   - 0 = take new, 1 = from memory\n");
    printf("                                  'enFlash'    - 1 = enable, 0 = disable\n");
    printf("                                  'fragSize'   - num.data.bytes per fragment\n");
    printf("                                  'imgType'    - 16 = B/W, 17 = Color\n");
    printf("                                  'xSize'      - in pixels. e.g. 128\n");
    printf("                                  'ySize'      - in pixels. e.g. 128\n");
    printf("                                  'threshold'  - Lossy RLE threshold (e.g. 20)\n");
    printf("                                  'out0'       - attr_t tag for return data\n");
}
/****************************************************************/
void print_usage_onset_detector(){
    printf(" onset_detector(noiseThres, signalThres, startDelay, tag_in, tag_out, tag_info, adaptiveMean)\n");
    printf("                          - perform onset-detection on data with 'tag_in'.\n");
    printf("                          - output filtered data to 'tag_out', and information to 'tag_info'.\n");
    printf("                          - 'startDelay' is the number of learning samples.\n");
    printf("                          - noise mean is updated even in onset state if 'adaptiveMean' is true.\n");
}
void print_usage_firlpfilter(){
    printf(" firlpfilter(tag_in, tag_out)\n");
}
void print_usage_rle() {
    printf(" rle(result, attr, thresh): result = run-length encoding of data in attr\n");
}
void print_usage_packbits() {
    printf(" packbits(result, attr, thresh): result = packbits run-length encoding of data in attr\n");
}
void print_usage_vector() {
    printf(" vector(result, length, pattern): generate a dummy vector of 'length' with 'pattern'\n");
}


/****************************************************************/

/* ADD MORE HERE */


/****************************************************************/
void print_tasklet_usage_guess(char *func, int n) {
    /* trying to find the help message...  */

    if (strncasecmp(func, "sample", n) == 0) print_usage_sample();
    if (strncasecmp(func, "voltage", n) == 0) print_usage_voltage();
    
    if (strncasecmp(func, "count", n) == 0) print_usage_count();
    if (strncasecmp(func, "constant", n) == 0) print_usage_constant();
    
    if (strncasecmp(func, "send", n) == 0) print_usage_send();
    if (strncasecmp(func, "sendpkt", n) == 0) print_usage_sendpkt();
    if (strncasecmp(func, "sendstr", n) == 0) print_usage_sendstr();
    if (strncasecmp(func, "sendrcrt", n) == 0) print_usage_sendrcrt();
    
    if (strncasecmp(func, "issue", n) == 0) print_usage_issue();
    if (strncasecmp(func, "wait", n) == 0) print_usage_wait();
    if (strncasecmp(func, "repeat", n) == 0) print_usage_repeat();
    if (strncasecmp(func, "alarm", n) == 0) print_usage_alarm();
    if (strncasecmp(func, "globalrepeat", n) == 0) print_usage_globalrepeat();
    
    if (strncasecmp(func, "get", n) == 0) print_usage_get();
    if (strncasecmp(func, "nexthop", n) == 0) print_usage_nexthop();
    if (strncasecmp(func, "parent", n) == 0) print_usage_nexthop();
    if (strncasecmp(func, "neighbors", n) == 0) print_usage_neighbors();
    if (strncasecmp(func, "localtime", n) == 0) print_usage_localtime();
    if (strncasecmp(func, "globaltime", n) == 0) print_usage_globaltime();
    if (strncasecmp(func, "rfpower", n) == 0) print_usage_rfpower();
    if (strncasecmp(func, "rfchannel", n) == 0) print_usage_rfchannel();
    if ((strncasecmp(func, "memory_stats", n) == 0) ||
        (strncasecmp(func, "memorystats", n) == 0)) print_usage_memory_stats();
    if (strncasecmp(func, "leds", n) == 0) print_usage_leds();
    if (strncasecmp(func, "is_timesync", n) == 0) print_usage_istimesync();
    if ((strncasecmp(func, "local_address", n) == 0) ||
        (strncasecmp(func, "nodeid", n) == 0)) print_usage_nodeid();
    if (strncasecmp(func, "platform", n) == 0) print_usage_platform();
    if (strncasecmp(func, "clock_freq", n) == 0) print_usage_clock_freq();
    if (strncasecmp(func, "master", n) == 0) print_usage_master();
    if (strncasecmp(func, "hopcount", n) == 0) print_usage_hopcount();
    if (strncasecmp(func, "rssi", n) == 0) print_usage_rssi();
    if (strncasecmp(func, "linkquality", n) == 0) print_usage_linkquality();

    if (strncasecmp(func, "actuate", n) == 0) print_usage_actuate();
    if ((strncasecmp(func, "set_leds", n) == 0) ||
        (strncasecmp(func, "setleds", n) == 0)) print_usage_set_leds();
    if (strncasecmp(func, "set_rfpower", n) == 0) print_usage_set_rfpower();
    if (strncasecmp(func, "sounder", n) == 0) print_usage_set_rfpower();
    if ((strncasecmp(func, "toggle_leds", n) == 0) ||
        (strncasecmp(func, "leds0toggle", n) == 0) ||
        (strncasecmp(func, "leds1toggle", n) == 0) ||
        (strncasecmp(func, "leds2toggle", n) == 0) ||
        (strncasecmp(func, "leds_toggle", n) == 0) ||
        (strncasecmp(func, "toggleleds", n) == 0)) print_usage_toggle_leds();
    if (strncasecmp(func, "reset_parent", n) == 0) print_usage_reset_parent();

    if ((strncasecmp(func, "storage", n) == 0) ||
        (strncasecmp(func, "store", n) == 0) ||
        (strncasecmp(func, "retrieve", n) == 0) ||
        (strncasecmp(func, "restore", n) == 0)) print_usage_storage();
    
    if ((strncasecmp(func, "comparison", n) == 0) ||
        (strncasecmp(func, "compare", n) == 0)) print_usage_comparison();
    if (strncasecmp(func, "lt", n) == 0) print_usage_lt();
    if (strncasecmp(func, "gt", n) == 0) print_usage_gt();
    if (strncasecmp(func, "eq", n) == 0) print_usage_eq();
    if (strncasecmp(func, "leq", n) == 0) print_usage_leq();
    if (strncasecmp(func, "geq", n) == 0) print_usage_geq();
    if (strncasecmp(func, "neq", n) == 0) print_usage_neq();
    if (strncasecmp(func, "count_lt", n) == 0) print_usage_count_lt();
    if (strncasecmp(func, "count_gt", n) == 0) print_usage_count_gt();
    if (strncasecmp(func, "count_eq", n) == 0) print_usage_count_eq();
    if (strncasecmp(func, "count_leq", n) == 0) print_usage_count_leq();
    if (strncasecmp(func, "count_geq", n) == 0) print_usage_count_geq();
    if (strncasecmp(func, "count_neq", n) == 0) print_usage_count_neq();

    if (strncasecmp(func, "stats", n) == 0) print_usage_stats();
    if (strncasecmp(func, "sum", n) == 0) print_usage_sum();
    if (strncasecmp(func, "min", n) == 0) print_usage_min();
    if (strncasecmp(func, "max", n) == 0) print_usage_max();
    if (strncasecmp(func, "avg", n) == 0) print_usage_avg();
    //if (strncasecmp(func, "std", n) == 0) print_usage_std();
    if (strncasecmp(func, "cnt", n) == 0) print_usage_cnt();
    if (strncasecmp(func, "meandev", n) == 0) print_usage_meandev();

    if (strncasecmp(func, "attribute", n) == 0) print_usage_attribute();
    if (strncasecmp(func, "exist", n) == 0) print_usage_exist();
    if (strncasecmp(func, "not_exist", n) == 0) print_usage_not_exist();
    if (strncasecmp(func, "length", n) == 0) print_usage_length();

    if (strncasecmp(func, "reboot", n) == 0) print_usage_reboot();
    if (strncasecmp(func, "pack", n) == 0) print_usage_pack();
    if (strncasecmp(func, "user_button", n) == 0) print_usage_user_button();
    //if (strncasecmp(func, "memoryop", n) == 0) print_usage_memoryop();

    if ((strncasecmp(func, "logical", n) == 0) ||
        (strncasecmp(func, "logical_and", n) == 0) ||
        (strncasecmp(func, "logical_or", n) == 0) ||
        (strncasecmp(func, "logical_not", n) == 0) ||
        (strncasecmp(func, "and", n) == 0) ||
        (strncasecmp(func, "or", n) == 0) ||
        (strncasecmp(func, "not", n) == 0)) print_usage_logical();

    if ((strncasecmp(func, "bit", n) == 0) ||
        (strncasecmp(func, "bit_and", n) == 0) ||
        (strncasecmp(func, "bit_or", n) == 0) ||
        (strncasecmp(func, "bit_not", n) == 0) ||
        (strncasecmp(func, "bit_xor", n) == 0) ||
        (strncasecmp(func, "bit_nand", n) == 0) ||
        (strncasecmp(func, "bit_nor", n) == 0) ||
        (strncasecmp(func, "shiftleft", n) == 0) ||
        (strncasecmp(func, "shiftright", n) == 0)) print_usage_bit();

    if (strncasecmp(func, "arith", n) == 0) print_usage_arith();
    if (strncasecmp(func, "add", n) == 0) print_usage_add();
    if (strncasecmp(func, "sub", n) == 0) print_usage_sub();
    if (strncasecmp(func, "mult", n) == 0) print_usage_mult();
    if (strncasecmp(func, "div", n) == 0) print_usage_div();
    if (strncasecmp(func, "diff", n) == 0) print_usage_diff();
    if (strncasecmp(func, "mod", n) == 0) print_usage_mod();
    if (strncasecmp(func, "pow", n) == 0) print_usage_pow();
    
    if ((strncasecmp(func, "deleteattributeif", n) == 0) ||
        (strncasecmp(func, "deleteattribute", n) == 0) ||
        (strncasecmp(func, "deleteallattributeif", n) == 0)) print_usage_deleteattributeif();
    if (strncasecmp(func, "deletetaskif", n) == 0) print_usage_deletetaskif();
    if (strncasecmp(func, "deleteactivetaskif", n) == 0) print_usage_deleteactivetaskif();
    
    if (strncasecmp(func, "image", n) == 0) print_usage_image();
    if (strncasecmp(func, "image_snap", n) == 0) print_usage_image_snap();
    if (strncasecmp(func, "image_get", n) == 0) print_usage_image_get();
    if (strncasecmp(func, "image_detect", n) == 0) print_usage_image_detect();
    if (strncasecmp(func, "image_detect_params", n) == 0) print_usage_image_detect_params();
    if (strncasecmp(func, "image_set_capture_params", n) == 0) print_usage_image_set_capture_params();
    if (strncasecmp(func, "image_get_capture_params", n) == 0) print_usage_image_get_capture_params();
    if (strncasecmp(func, "image_reboot", n) == 0) print_usage_image_reboot();
    if (strncasecmp(func, "image_getrle", n) == 0) print_usage_image_getrle();
    if (strncasecmp(func, "image_getpackbits", n) == 0) print_usage_image_getpackbits();
    
    if (strncasecmp(func, "onset_detector", n) == 0) print_usage_onset_detector();
    if (strncasecmp(func, "firlpfilter", n) == 0) print_usage_firlpfilter();
    if ((strncasecmp(func, "rle", n) == 0) ||
        (strncasecmp(func, "runlengthencoding", n) == 0)) print_usage_rle();
    if ((strncasecmp(func, "packbits", n) == 0) ||
        (strncasecmp(func, "runlengthencoding", n) == 0) ||
        (strncasecmp(func, "rle", n) == 0)) print_usage_packbits();
    if (strncasecmp(func, "vector", n) == 0) print_usage_vector();
    printf("\n");
}

void print_tasklet_usage_all() {
    print_usage_count();
    print_usage_constant();

    print_usage_issue();
    print_usage_wait();
    print_usage_repeat();
    print_usage_alarm();
    print_usage_globalrepeat();
    
    print_usage_get();
    print_usage_nexthop();
    print_usage_globaltime();
    print_usage_localtime();
    print_usage_rfpower();
    print_usage_rfchannel();
    print_usage_memory_stats();
    print_usage_leds();
    print_usage_num_tasks();
    print_usage_num_active_tasks();
    print_usage_istimesync();
    print_usage_nodeid();
    print_usage_platform();
    print_usage_clock_freq();
    print_usage_master();

    print_usage_logical();

    print_usage_bit();

    print_usage_arith();
    print_usage_add();
    print_usage_sub();
    print_usage_mult();
    print_usage_div();
    print_usage_diff();
    print_usage_mod();
    print_usage_pow();

    print_usage_comparison();
    print_usage_lt();
    print_usage_gt();
    print_usage_eq();
    print_usage_leq();
    print_usage_geq();
    print_usage_neq();
    print_usage_count_lt();
    print_usage_count_gt();
    print_usage_count_eq();
    print_usage_count_leq();
    print_usage_count_geq();
    print_usage_count_neq();

    print_usage_stats();
    print_usage_sum();
    print_usage_min();
    print_usage_max();
    print_usage_avg();
    //print_usage_std();
    print_usage_cnt();
    print_usage_meandev();

    print_usage_attribute();
    print_usage_exist();
    print_usage_not_exist();
    print_usage_length();

    print_usage_actuate();
    print_usage_set_rfpower();
    print_usage_set_leds();
    print_usage_sounder();
    print_usage_toggle_leds();
    print_usage_reset_parent();

    print_usage_storage();
    print_usage_pack();
    print_usage_send();
    print_usage_reboot();

    print_usage_deleteattributeif();
    print_usage_deletetaskif();
    print_usage_deleteactivetaskif();
    
    print_usage_sample();
    print_usage_voltage();
    
    print_usage_image();
    print_usage_image_snap();
    print_usage_image_get();
    print_usage_image_detect();
    print_usage_image_detect_params();
    print_usage_image_set_capture_params();
    print_usage_image_get_capture_params();
    print_usage_image_reboot();
    print_usage_image_getrle();
    print_usage_image_getpackbits();

    print_usage_onset_detector();
    print_usage_firlpfilter();
    print_usage_rle();
    print_usage_packbits();
    print_usage_vector();

    printf("\n");
}

