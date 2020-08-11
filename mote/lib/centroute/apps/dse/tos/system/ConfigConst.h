/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 01/06/2004
 *
 */

//max number of measurement names.
#define MAX_CONFIG 15            

struct sensorConfig_s 
{
  uint8_t hardwareAddress;
  uint8_t measurementName;
  uint8_t sensorType;
  uint8_t channelParameter;
}__attribute__((packed));
typedef struct sensorConfig_s sensorConfig_t;

struct sensorConfig_eprom_s 
{
  sensorConfig_t sensorConfig;
  uint8_t sensor_Attached_Flag;
}__attribute__((packed)); 
typedef struct sensorConfig_eprom_s sensorConfig_eprom_t;

//definition of the hardware addresses, their 
//number and their location in eeprom
enum {
  ADC0_HARDWARE_ADDRESS=0,
  ADC1_HARDWARE_ADDRESS=1,
  ADC2_HARDWARE_ADDRESS=2,
  ADC3_HARDWARE_ADDRESS=3,
  ADC4_HARDWARE_ADDRESS=4,
  ADC5_HARDWARE_ADDRESS=5,
  ADC6_HARDWARE_ADDRESS=6,
  ADC7_HARDWARE_ADDRESS=7,
  ADC8_HARDWARE_ADDRESS=8,
  ADC9_HARDWARE_ADDRESS=9,
  ADC10_HARDWARE_ADDRESS=10,
  ADC11_HARDWARE_ADDRESS=11,
  ADC12_HARDWARE_ADDRESS=12,
  ADC13_HARDWARE_ADDRESS=13,
  COUNTER_HARDWARE_ADDRESS=14,
  TEMP_HARDWARE_ADDRESS=15,
  HUM_HARDWARE_ADDRESS=16,
  BATTEREY_HARDWARE_ADDRESS=17,
  DIG0_HARDWARE_ADDRESS=18,
  DIG1_HARDWARE_ADDRESS=19,
  DIG2_HARDWARE_ADDRESS=20,
  DIG3_HARDWARE_ADDRESS=21,
  DIG4_HARDWARE_ADDRESS=22,
  DIG5_HARDWARE_ADDRESS=23,
  DAQ0_HARDWARE_ADDRESS=24,
  DAQ1_HARDWARE_ADDRESS=25,
  DAQ2_HARDWARE_ADDRESS=26,
  DAQ3_HARDWARE_ADDRESS=27,
  DAQ4_HARDWARE_ADDRESS=28,
  DAQ5_HARDWARE_ADDRESS=29,
  DAQ6_HARDWARE_ADDRESS=30,
  DAQ7_HARDWARE_ADDRESS=31,
  NO_HARDWARE_ADDRESS=32
};

//number of hardware addresses
#define NUMBER_OF_HARDWARE_ADDRESSES 24 
#define NO_MEASUREMENT_NAME 0
#define SIZE_OF_MEASUREMENT_NAME 1

enum
{
  CONFIG_GET_COMMAND=0x55,
  CONFIG_GET_HWADDR_COMMAND=0x77,
  CONFIG_PUT_COMMAND=0xaa,
  CONFIG_ERASE_COMMAND=0x33,
  CONFIG_RESET_ADC_COMMAND=0xcc
};

struct ConfigHeader_s 
{
  uint8_t ConfigType;
}__attribute__((packed));
typedef struct ConfigHeader_s ConfigHeader_t;


enum {
  VALID_SENSOR_RECORD = 0xaa,
  INVALID_SENSOR_RECORD = 0x55
};
