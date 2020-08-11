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
 * @author Marcos Augusto Menezes Vieira
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

/**
 * Collect application works for Telos and MicaZ nodes.
 * It continously read and display sensor information .
 * It may take a few moments before displaying data.
 *
 * TELOSB SENSORS:
 * --------------
 * -Sensirion Relative Humidity Sensor
 * -Sensirion Temperature Sensor
 * -Hamamatsu Photosynthetically Active Radiation Light Sensor
 * -Hamamatsu Total Solar Radiation Light Sensor
 * -TI MSP430 Internal Temperature Sensor
 * -TI MSP430 Internal Voltage Sensor
 *
 * MICAZ SENSORS: sensorboard 310
 * -------------
 * -Internal Voltage Sensor
 * -Photo Sensor
 * -Acceleration Sensor X
 * -Acceleartion Sensor Y
 *
 **/
 
/**
 * How to interpret sensor readings was based on:
 * http://www.moteiv.com/community/Getting_Data_from_Tmote_Sky%27s_Sensors
 **/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <math.h>
#include "tenet.h"

int tid = 0;
int tid2 = 0;
int verbosemode=0;

void print_usage() {
    printf("Collect continously display sensor information from Telos nodes.\n\n");
    printf("Usage: collect [-hrvTHSLVIXY] [-n host] [-p port] \n\n");
    printf("  h : display this help message\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  t : modify inter-sample time in seconds (default 30sec)\n");
    printf("  r : display raw sensor value.\n");
    printf("  T : disable reading Temperature sensor (Celsius).\n");
    printf("  H : disable reading Humidity sensor (%%RH). Telosb\n");
    printf("  S : disable reading total Solar radiation light sensor, which includes infrared (Lux). Telosb and Micaz\n");
    printf("  L : enable reading photosynthetically active radiation Light sensor (Lux). Telosb\n");
    printf("  V : enable reading Voltage sensor. The internal voltage sensor monitors mote's supply voltage Vcc/2.\n");
    printf("  I : enable reading Internal temperature sensor. Telosb\n");
    printf("  X : enable reading acceleration sensor X. Micaz\n");
    printf("  Y : enable reading acceleration sensor Y. Micaz\n");
    printf("  n : host on which transport is running.Default is localhost\n");
    printf("  p : port on which transport is listening for connection. Default is port 9998.\n");
    printf("\nMicaZ may not return correct results (tinyos-1.x/tos/platform/micaz/README)\n");
}

void sig_int_handler(int signo) {
    if (tid) delete_task(tid);
    if (tid2) delete_task(tid2);
    exit(0);
}

int main(int argc, char **argv)
{
    char task_string[200], host_name[200];
    int tr_port;
    int c;

    unsigned long int sample_intval = 20000;
    unsigned long int interval_ms = sample_intval + 10000;

    int disableTemperature = 0;
    int disableHumididty = 0;
    int disableSolar = 0;
    int disableLight = 1;
    int disableVoltage = 0;
    int disableInternalTemperature = 1;
    int disableAccelX = 1;
    int disableAccelY = 1;

    int raw = 0;

    int platform = 0;
    struct response *list;
    struct attr_node* valueNode = NULL;


    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    strcpy(host_name, "127.0.0.1");
    tr_port = 9998;

    while ((c = getopt(argc, argv, "vrTHLSVIXYh:n:p:t:")) != -1)
        switch(c) {
            case 'r':
                raw = 1;
                break;
            case 't':
                sample_intval = (unsigned long int)atoi(optarg) * 1000;
                interval_ms = sample_intval +10000;
                break;
            case 'T':
                disableTemperature = 1;
                break;
            case 'H':
                disableHumididty = 1;
                break;
            case 'S':
                disableSolar = 1;
                break;
            case 'L':
                disableLight = 0;
                break;
            case 'V':
                disableVoltage = 0;
                break;
            case 'I':
                disableInternalTemperature = 0;
                break;
            case 'X':
                disableAccelX = 0;
                break;
            case 'Y':
                disableAccelY = 0;
                break;
            case 'n':
                strcpy(host_name,optarg);
                break;
            case 'p':
                tr_port = atoi(optarg);
                break;
            case 'v':
                setVerbose();
                verbosemode = 1;
                break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }


    config_transport(host_name, tr_port);

    //construct telosb task_string
    //if not telosb platform, delete task
    sprintf(task_string,"platform(0x2)->comparison(0x3,0x2,!=,'1')->deleteTaskIf(0x3)->repeat(%lu)->%s%s%s%s%s%ssend()",
        sample_intval,
        (disableHumididty)?"":"sample(20,0x10)->",
        (disableTemperature)?"":"sample(21,0x11)->",
        (disableSolar)?"":"sample(26,0x12)->",
        (disableLight)?"":"sample(23,0x13)->",
        (disableInternalTemperature)?"":"sample(24,0x14)->",
        (disableVoltage)?"":"voltage(0x15)->");

    tid = send_task(task_string);
    if (tid < 0) exit(1);

    sleep(1);

    //construct micaz task_string
    sprintf(task_string,"platform(0x2)->comparison(0x3,0x2,!=,'2')->deleteTaskIf(0x3)->repeat(%lu)->%s%s%s%s%ssend()",
        sample_intval,
        (disableTemperature)?"":"sample(21,0x21)->",
        //"",
        (disableSolar)?"":"sample(26,0x22)->",
        (disableAccelX)?"":"sample(27,0x23)->",
        (disableAccelY)?"":"sample(28,0x24)->",
        (disableVoltage)?"":"voltage(0x25)->");

    tid2 = send_task(task_string);
    if (tid2 < 0) exit(1);


    printf("\n");
    printf("Collect continously display sensor data from TelosB every %lu seconds.\n", sample_intval/1000);
    printf(" (Wait %lu seconds for the first data.)\n", sample_intval/1000);

    printf("\nPress Cntrl-C to STOP!\n");
        
    while(1) {
    
        /* receive response packets */
        list = read_response(interval_ms);

        if (list == NULL) {//did not get any attribute.
            switch(get_error_code()) {
                case TIMEOUT:
                    continue;//received last packet
                break;
                case MOTE_ERROR:
                    continue;//ignore mote error
                default:
                    fprintf(stderr,"error code %d\n",get_error_code());
                break;
            }
        }

        printf("Node=%d ",list->mote_addr);

        valueNode = response_find(list, 0x2);
        if (valueNode != NULL) platform = valueNode->value[0];


    /* TelosB sensor readings */
        if (platform == 1) { // TELOSB
        
            if (!disableVoltage) {
                valueNode = response_find(list, 0x15);
                if (valueNode != NULL) {
                    int voltage = valueNode->value[0];
                    //value/4096 * Vref
                    if (raw) printf("voltage=%d ",voltage);
                    else printf("voltage=%.3f ", voltage/1000.0);
                    //else printf("voltage=%.2f ", (voltage/4096.00) * 1.5);
                }
            }

            //check temperature first because you can correct the humidity i
            // measurement with temperature compensation
            double Tc = 0.0;
            if (!disableTemperature) {
                valueNode = response_find(list, 0x11);
                if (valueNode != NULL) {
                    int temperature = valueNode->value[0];
                    //temperature = -39.60 + 0.01*SOt
                    Tc = -39.60+temperature*0.01;
                    if (raw) printf("temperature=%d ", temperature);
                    else printf("temperature=%.2f ", Tc);
                }
            }
            if (!disableSolar) {
                if (valueNode != NULL) {
                    valueNode = response_find(list, 0x12);
                    int solar = valueNode->value[0];
                    double V = (solar/4096.0) * 1.5;
                    double I = V/100000.0;
                    // I = Vsensor / 100,000
                   //S1087-01 lx = 1e5 * I * 1000
                   if (raw) printf("infrared=%d ",solar);
                   else printf("infrared=%.2f ",1e5 * I * 1000);
                }
            }
            if (!disableLight) {
                valueNode = response_find(list, 0x13);
                if (valueNode != NULL) {
                    int light = valueNode->value[0];
                    double V = (light/4096.0) * 1.5;
                    double I = V/100000.0;
                    // I = Vsensor / 100,000
                    //S1087    lx = 1e6 * I * 1000
                    if (raw) printf("light=%d ",light);
                    else printf("light=%.2f ",1e6 * I * 1000);
                }
            }
            if (!disableHumididty) {
                valueNode = response_find(list, 0x10);
                if (valueNode != NULL) {
                    int SOrh = valueNode->value[0];
                    //humidity = -4 + 0.0405*SOrh + (-2.8 * 10^-6)*(SOrh^2)
                    double humidity = -4 + 0.0405*SOrh + (-2.8 * 1e-6)*(SOrh)*(SOrh);
                    if (raw) printf("humidity=%d ",SOrh);
                    else if (disableTemperature)
                        printf("humidity=%.2f ",humidity);
                    else {
                        //humidity_true = (Tc - 25) * (0.01 + 0.00008*SOrh) + humidity
                        printf("humidity=%.2f ", (Tc - 25) * (0.01 + 0.00008*SOrh) + humidity);
                    }
                }
            }
            if (!disableInternalTemperature) {
                valueNode = response_find(list, 0x14);
                if (valueNode != NULL) {
                    int internalTemperature = valueNode->value[0];
                    //value/4096 * Vref
                    //T =  (Vtemp - 0.986)/0.00355
                    if (raw) printf("internalTemperature=%d ",internalTemperature);
                    else printf("internalTemperature=%.2f ",
                        (((internalTemperature/4096.00)*1.5) - 0.986)/0.00355);
                }
            }
        }
    /* End of TelosB sensor readings */


    /* MicaZ sensor readings */
        if (platform == 2) { // MICAZ

            if (!disableVoltage) {
                valueNode = response_find(list, 0x25);
                if (valueNode != NULL) {
                    int voltage = valueNode->value[0];
                    printf("voltage=%.3f ",voltage/1000.0);
                }
            }
            if (!disableTemperature) {
                valueNode = response_find(list, 0x21);
                if (valueNode != NULL) {
                    int temp_adc = valueNode->value[0];
                    // contrib/xbow/tools/src/xconvert.c
                    float adc = (float)temp_adc;
                    float Rthr = 10000.0 * (1023.0-adc) / adc;
                    float a = 0.001307050, b = 0.000214381, c = 0.000000093;
                    float temperature = 1 / (a + b * log(Rthr) + c * pow(log(Rthr),3));
                    temperature -= 273.15;   // Convert from Kelvin to Celcius
                    printf("temperature=%.2f ", temperature);
                }
            }
            if (!disableSolar) {
                valueNode = response_find(list, 0x22);
                if (valueNode != NULL) {
                    int photo = valueNode->value[0];
                    printf("photo=%d ",photo);
                }
            }
            if (!disableAccelX) {
                valueNode = response_find(list, 0x23);
                if (valueNode != NULL) {
                    int accelX = valueNode->value[0];
                    printf("accelX=%d ",accelX);
                }
            }
            if (!disableAccelY) {
                valueNode = response_find(list, 0x24);
                if (valueNode != NULL) {
                    int accelY = valueNode->value[0];
                    printf("accelY=%d ",accelY);
                }
            }
        }
    /* End of MicaZ sensor readings */

        printf("\n");
        response_delete(list);
    } //end while
    return 0;
}

