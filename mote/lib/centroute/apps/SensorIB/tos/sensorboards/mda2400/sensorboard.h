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
 * History:   created 08/14/2003
 *
 */

#ifndef SENSORBOARD_H
#define SENSORBOARD_H

// Sampler defines
#define MAX_SAMPLERECORD 15
#define ADC_ERROR 0xffff

/*
 *DAQ specific defines
 */
// Always 4 bytes per reading
#define BYTES_PER_READING 4
// There are 8 possible channels
#define MAX_DAQ_CHANNELS 8
// Channel read commands start at 30
#define SAMPLE_CHANNEL_ZERO 30
// Time in ms to wait for voltage setting
#define VOLTAGE_SET_TIME 200
// Time in ms to wait for voltage stabalization
#define VOLTAGE_STABLE_TIME 200
// Time to timeout a reading
#define TIMEOUT_TIME (10000L)  

// Voltage commands for channel six
#define CHANNEL_SIX_ENABLE_VOLTAGE 60
#define CHANNEL_SIX_DISABLE_VOLTAGE 61
#define CHANNEL_SIX_SEND_VOLTAGE 63
// Voltage commands for channel seven
#define CHANNEL_SEVEN_ENABLE_VOLTAGE 65
#define CHANNEL_SEVEN_DISABLE_VOLTAGE 66
#define CHANNEL_SEVEN_SEND_VOLTAGE 68

// Possible states for Daq module
enum {
  IDLE,
  PICK_CHANNEL,
  GET_SAMPLE,
  CONTINUE_SAMPLE,
  START_CONVERSION_PROCESS
};

// DAQ channel parameters
enum {
  SAMPLER_DEFAULT =0x00,
  AVERAGE_FOUR = 0x01,
  AVERAGE_EIGHT = 0x02,
  AVERAGE_SIXTEEN = 0x04,
  EXCITATION_25 = 0x08,
  EXCITATION_33 = 0x10,
  EXCITATION_50 = 0x20,
  EXCITATION_ALWAYS_ON = 0x40,
  DELAY_BEFORE_MEASUREMENT = 0x80
};

// Different channel types available
enum {
  ANALOG=0,
  BATTERY=1,
  TEMPERATURE=2,
  HUMIDITY=3,
  DIGITAL=4,
  COUNTER=5,
  DAQ=6,
  NOT_USED=7
};

enum {
  SAMPLE_RECORD_FREE=-1,
  SAMPLE_ONCE=-2
};

#endif
