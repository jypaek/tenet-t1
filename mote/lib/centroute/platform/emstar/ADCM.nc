// $Id: ADCM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $
/* -*- Mode: C; tab-width:4; c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=8 expandtab shiftwidth=4 softtabstop=4: */

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis, Phil Buonadonna
 * Date last modified:  $Id: ADCM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $
 *
 */

/*  OS component abstraction of the analog to digital converter
 *  It provides an asynchronous interface that schedules access to 
 *  separate virtual ADC ports in a round-robin fashion.
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 * @author Phil Buonadonna
 */


includes tos_emstar;
// includes sensorboard;
// #include "../../tos-contrib/sensorIB/tos/sensorboards/mda300ca/sensorboard.h"


module ADCM 
{
  provides {
    interface ADC[uint8_t port];
    interface ADCControl;
  }
}

implementation
{

uint16_t ReqPort;
uint16_t ReqVector;
uint16_t ContReqMask;


void AdcDataReady(uint8_t port, uint16_t data)
{
    signal ADC.dataReady[port](data);
}


command result_t ADCControl.init() 
{
    fp_list_t *fplist=get_fplist();

    fplist->AdcDataReady=AdcDataReady;

    return emtos_adc_init(fplist);

}

command result_t ADCControl.setSamplingRate(uint8_t rate) 
{
    return SUCCESS;
}


command result_t ADCControl.bindPort(uint8_t port, uint8_t adcPort) {
    return emtos_adc_register_port(port, 0, NULL, NULL);
}


default async event result_t ADC.dataReady[uint8_t port](uint16_t data) 
{
    return FAIL; // ensures ADC is disabled if no handler
}


async command result_t ADC.getData[uint8_t port]() 
{
    return emtos_adc_get_data(port, 0);
}


async command result_t ADC.getContinuousData[uint8_t port]() 
{
    // return emtos_adc_get_continuous_data(port);
    return FAIL;    // not supported
}

}
