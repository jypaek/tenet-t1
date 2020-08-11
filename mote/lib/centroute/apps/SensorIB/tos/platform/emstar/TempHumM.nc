/* -*- Mode: C; tab-width: 8;c-basic-indent: 2; indent-tabs-mode: nil -*- */
/* ex: set tabstop=8 expandtab shiftwidth=2 softtabstop=2: */

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
 * History:   created @ 01/14/2003 
 * Last Modified:     @ 11/14/2003
 * 
 * driver for sensirion temperature and humidity sensor 
 *
 */
includes sensorboard;
includes tos_emstar;

module TempHumM {
  provides {
    interface StdControl;
    interface ADConvert as TempSensor;
    interface ADConvert as HumSensor;
    interface ADConvert as Battery;
  }
  uses {
    interface Leds;
  }
}
implementation {
#include "../../../dse/tos/lib/StdDbg.h"    

typedef struct _private_data {
  uint16_t recvData;
  uint8_t recvPort;
} private_data_t;


void dataReady()
{
  private_data_t *priv;
  priv = (private_data_t *)emtos_get_task_data();

  if (priv!=NULL) {
    switch (priv->recvPort) {
      case TEMPERATURE:
        stddbg("Temperature data ready (%d)", priv->recvData);     
        signal TempSensor.dataReady(priv->recvData);
        break;
      case HUMIDITY:
        stddbg("Humidity data ready (%d)", priv->recvData);     
        signal HumSensor.dataReady(priv->recvData);
        break;
      case BATTERY:
        stddbg("Battery data ready (%d)", priv->recvData);
        signal Battery.dataReady(priv->recvData);
        break;
      default:
        stddbg("Unknown port??? (%d)", priv->recvPort);
        break;
    }
    free(priv);
  } 
}

// Implicit that the type is ANALOG, NOT AdcDataReady!
void OnBoardDataReady(uint8_t port, uint16_t data)
{
  private_data_t *priv;
  priv = malloc(sizeof(private_data_t));

  if (priv==NULL) {
    printf("NULL pointer, malloc failed?");
    return;
  }

  priv->recvPort=port;
  priv->recvData=data;

  stddbg("OnBoardDataReady called, port=%d, data=%d", port, data);  
  emtos_post_task(dataReady, (void *)priv);
}


command result_t StdControl.init() 
{ 
    
    fp_list_t *fplist=get_fplist();
    fplist->OnBoardDataReady=OnBoardDataReady;
    emtos_adc_init(fplist);

    emtos_adc_register_port(TEMPERATURE, TEMPERATURE, NULL, "Temperature");
    emtos_adc_register_port(HUMIDITY, HUMIDITY, NULL, "Humidity");
    emtos_adc_register_port(BATTERY, BATTERY, NULL, "Battery");

    return SUCCESS;
}
command result_t StdControl.start() {
  return SUCCESS;
}

command result_t StdControl.stop() {
  return SUCCESS;
}


default event result_t TempSensor.dataReady(uint16_t tempData) 
{
    return SUCCESS;
}

default event result_t HumSensor.dataReady(uint16_t humData) 
{
    return SUCCESS;
}


default event result_t Battery.dataReady(uint16_t humData) 
{
    return SUCCESS;
}

command result_t TempSensor.getData()
{
    emtos_adc_get_data(TEMPERATURE, TEMPERATURE);
    return SUCCESS;
}

command result_t HumSensor.getData()
{
    emtos_adc_get_data(HUMIDITY, HUMIDITY);
    return SUCCESS;
}


command result_t Battery.getData()
{
  emtos_adc_get_data(BATTERY, BATTERY);
  return SUCCESS;
}

command result_t TempSensor.getContinuousData(){
  return FALSE;
}

command result_t HumSensor.getContinuousData(){
  return FALSE;
}

command result_t Battery.getContinuousData()
{
  return FALSE;
}
}
