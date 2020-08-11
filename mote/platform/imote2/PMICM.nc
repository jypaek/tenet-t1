/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2002 Intel Corporation 
 *  All rights reserved. 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 * 
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * 
 */

/*
 *
 * Authors:  Lama Nachman, Robert Adler
 */

#define MAX_BLOCKING_WAIT_COUNT (1000)

#define START_RADIO_LDO 1
#define START_SENSOR_BOARD_LDO 1

/*
 * VCC_MEM is connected to LDO by default, 
 * If the imote2 board has R49 on and R40 off then ENABLE_BUCK2 can be set t0 0
 * This is assumed to be the default setting.
 * If the imote2 board has R49 off and R40 on, you need to set ENABLE_BUCK2 
 * to 1 when making the app.  
 */
#ifndef ENABLE_BUCK2 
#define ENABLE_BUCK2 0	
#endif

includes trace;

module PMICM{
  provides{
    interface StdControl;
    interface BluSH_AppI as BatteryVoltage; 
    interface BluSH_AppI as ManualCharging;
    interface BluSH_AppI as ChargingStatus;
    interface BluSH_AppI as ReadPMIC;
    interface BluSH_AppI as WritePMIC;
    interface BluSH_AppI as SetCoreVoltage;
    interface PMIC;
  }
  uses {
    interface PXA27XInterrupt as PI2CInterrupt;
    interface PXA27XGPIOInt as PMICInterrupt;
    interface Timer as chargeMonitorTimer;
    interface Timer as batteryMonitorTimer;
    interface Reset;
    interface StdControl as GPIOIRQControl;
    interface Leds;
  }
}

implementation {
#include "pmic.h"

#define MIN_BATTERY_VOLTAGE (3.3)
#define CHARGER_TURN_ON_BATTERY_VOLTAGE (3.4)
#define CHARGER_TURN_OFF_BATTERY_VOLTAGE (4.0)
#define BATTERY_MONITOR_PERIOD (60*5*1000)  //5 minutes
  
#define CHARGER_VOLTAGE_TARGET  (70)
#define CHARGER_VOLTAGE(val) (((val)*6) * .01035)
#define BATTERY_VOLTAGE(val) (((val) * .01035) + 2.65)
#define CHARGER_MONITOR_PERIOD (60*5*1000)  //5 minutes
  
  bool gotReset = FALSE;

  TOSH_ASSIGN_PIN(PMIC_TXON, A, 108);

  result_t readPMIC(uint8_t address, uint8_t *value, uint8_t numBytes);
  result_t writePMIC(uint8_t address, uint8_t value);
  result_t getPMICADCVal(uint8_t channel, uint8_t *val);
  
  bool accessingPMIC = FALSE;

  bool getPI2CBus(){
      
    if(accessingPMIC == FALSE){
      accessingPMIC = TRUE;
      return TRUE;
    }
    else{
      trace(DBG_USR1,"FATAL ERROR:  Contention Error encountered while acquiring PI2C Bus\r\n");
      return FALSE;
    }
  }

  void returnPI2CBus(){
    atomic{
      accessingPMIC = FALSE;
    }
  }

  bool isChargerEnabled(){
    uint8_t chargerState;
    //get charger's state
    readPMIC(PMIC_CHARGE_CONTROL,&chargerState, 1);
       
    return (chargerState > 0) ? TRUE: FALSE;
  }    
  
  uint8_t getChargerVoltage(){
    uint8_t chargerVoltage;
    getPMICADCVal(2, &chargerVoltage);
    return chargerVoltage;
  }
  
  uint8_t getBatteryVoltage(){
    uint8_t batteryVoltage;
    getPMICADCVal(0, &batteryVoltage);
    return batteryVoltage;
  }


  command result_t StdControl.init(){
    static bool init = 0;
    
    if(init == 0){
      CKEN |= CKEN_CKEN15;
      PCFR |= PCFR_PI2C_EN;
      PICR = ICR_IUE | ICR_SCLE;
      
      TOSH_MAKE_PMIC_TXON_OUTPUT();
      TOSH_CLR_PMIC_TXON_PIN();
      
      call GPIOIRQControl.init();
      init = 1;
      call Leds.init();
      return call PI2CInterrupt.allocate();
    }
    else{
      return SUCCESS;
    }
  }
  
  void smartChargeEnable(){
    uint8_t val;
    if( isChargerEnabled() == TRUE){
      //charger is enabled
      val = getChargerVoltage();
      trace(DBG_USR1,"Charger Status:  Charger Voltage is %.3fV\r\n", CHARGER_VOLTAGE(val));
      if(val > CHARGER_VOLTAGE_TARGET){
	//charger is enabled and charger voltage is good...not sure why we got the interrupt...don't do anything
      }
      else{
	//charger is on, but the charging voltage is bad...turn off charging
	call PMIC.enableCharging(FALSE);
      }
    }
    else{
      //charget is not enabled
      if(getChargerVoltage() > CHARGER_VOLTAGE_TARGET){
	//charger voltage is good...turn on the charger
	call PMIC.enableCharging(TRUE);
      }
      else{
	//charger is off and the charging voltage is bad...not sure why we got the interrupt...don't do anything
      }
    }
  }

  
  task void printReadPMICBusError(){
    trace(DBG_USR1,"FATAL ERROR:  readPMIC() Unable to obtain bus\r\n");
  }
  
  task void printReadPMICAddresError(){
    trace(DBG_USR1,"FATAL ERROR:  readPMIC() Unable to send address\r\n");
  }
  
  task void printReadPMICSlaveAddresError(){
    trace(DBG_USR1,"FATAL ERROR: readPMIC() unable to write slave address\r\n");
  }

  task void printReadPMICReadByteError(){
    trace(DBG_USR1,"FATAL ERROR:  readPMIC() Unable to read byte from PMIC\r\n");
  }

  result_t readPMIC(uint8_t address, uint8_t *value, uint8_t numBytes){
    //send the PMIC the address that we want to read
    
    uint32_t loopCount;
    
#ifdef XDB_SIM
    return SUCCESS;
#endif    
    if(getPI2CBus() == FALSE){
      return FAIL;
    }
        
    if(numBytes > 0){
      PIDBR = PMIC_SLAVE_ADDR<<1; 
      PICR |= ICR_START;
      PICR |= ICR_TB;
      for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
      if(loopCount == MAX_BLOCKING_WAIT_COUNT){
	post printReadPMICBusError();
	returnPI2CBus();
	return FAIL;
      }
      //actually send the address terminated with a STOP
      PIDBR = address;
      PICR &= ~ICR_START;
      PICR |= ICR_STOP;
      PICR |= ICR_TB;
      
      for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
      if(loopCount == MAX_BLOCKING_WAIT_COUNT){
	post printReadPMICAddresError();
	returnPI2CBus();
	return FAIL;
      }
      PICR &= ~ICR_STOP;
      
      
      //actually request the read of the data
      PIDBR = PMIC_SLAVE_ADDR<<1 | 1; 
      PICR |= ICR_START;
      PICR |= ICR_TB;
      
      for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
      if(loopCount == MAX_BLOCKING_WAIT_COUNT){
	post printReadPMICSlaveAddresError();
	returnPI2CBus();
	return FAIL;
      }

      PICR &= ~ICR_START;
      
      //using Page Read Mode
      while (numBytes > 1){
	PICR |= ICR_TB;

	for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
	if(loopCount == MAX_BLOCKING_WAIT_COUNT){
	  post printReadPMICReadByteError();
	  returnPI2CBus();
	  return FAIL;
	}

	*value = PIDBR;
	value++;
	numBytes--;
      }
      
      PICR |= ICR_STOP;
      PICR |= ICR_ACKNAK;
      PICR |= ICR_TB;
      
      for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
      if(loopCount == MAX_BLOCKING_WAIT_COUNT){
	post printReadPMICReadByteError();
	returnPI2CBus();
	return FAIL;
      }
      
      *value = PIDBR;
      PICR &= ~ICR_STOP;
      PICR &= ~ICR_ACKNAK;
      
      returnPI2CBus();
      return SUCCESS;
    }
    else{
      returnPI2CBus();
      return FAIL;
    }
  }
  
  task void printWritePMICSlaveAddressError(){
    trace(DBG_USR1,"FATAL ERROR:  writePMIC() Unable to write slave address\r\n");
  }
  
  task void printWritePMICRegisterAddressError(){
    trace(DBG_USR1,"FATAL ERROR:  writePMIC() Unable to write target register address\r\n");
  }

  task void printWritePMICWriteError(){
    trace(DBG_USR1,"FATAL ERROR:  writePMIC() Unable to write value\r\n");
  }

  
  
  result_t writePMIC(uint8_t address, uint8_t value){
    
    uint32_t loopCount;

#ifdef XDB_SIM
    return SUCCESS;
#endif
    
    if(getPI2CBus() == FALSE){
      return FAIL;
    }
    
    PIDBR = PMIC_SLAVE_ADDR<<1;
    PICR |= ICR_START;
    PICR |= ICR_TB;
    for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
    if(loopCount == MAX_BLOCKING_WAIT_COUNT){
      post printWritePMICSlaveAddressError();
      returnPI2CBus();
      return FAIL;
    }
    
    PIDBR = address;
    PICR &= ~ICR_START;
    PICR |= ICR_TB;
    for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
    if(loopCount == MAX_BLOCKING_WAIT_COUNT){
      post printWritePMICRegisterAddressError();
      returnPI2CBus();
      return FAIL;
    }

    PIDBR = value;
    PICR |= ICR_STOP;
    PICR |= ICR_TB;
    for(loopCount = 0; ((PICR & ICR_TB) && (loopCount < MAX_BLOCKING_WAIT_COUNT)); loopCount++);
    if(loopCount == MAX_BLOCKING_WAIT_COUNT){
      post printWritePMICWriteError();
      returnPI2CBus();
      return FAIL;
    }
    PICR &= ~ICR_STOP;

    returnPI2CBus();
    return SUCCESS;
  }
  
  void startLDOs() {
    uint8_t oldVal, newVal;

#if START_SENSOR_BOARD_LDO 
    // TODO : Need to move out of here to sensor board functions
    readPMIC(PMIC_A_REG_CONTROL_1, &oldVal, 1);
    newVal = oldVal | ARC1_LDO10_EN | ARC1_LDO11_EN;	// sensor board
    writePMIC(PMIC_A_REG_CONTROL_1, newVal);

    readPMIC(PMIC_B_REG_CONTROL_2, &oldVal, 1);
    newVal = oldVal | BRC2_LDO10_EN | BRC2_LDO11_EN;
    writePMIC(PMIC_B_REG_CONTROL_2, newVal);
#endif

#if START_RADIO_LDO
    // TODO : Move to radio start
    readPMIC(PMIC_B_REG_CONTROL_1, &oldVal, 1);
    newVal = oldVal | BRC1_LDO5_EN; 
    writePMIC(PMIC_B_REG_CONTROL_1, newVal);
#endif

#if (!ENABLE_BUCK2)  // Disable BUCK2 if VCC_MEM is not configured to use BUCK2
    readPMIC(PMIC_B_REG_CONTROL_1, &oldVal, 1);
    newVal = oldVal & ~BRC1_BUCK_EN;
    writePMIC(PMIC_B_REG_CONTROL_1, newVal);
#endif

#if 0
    // Configure above LDOs, Radio and sensor board LDOs to turn off in sleep
    // TODO : Sleep setting doesn't work
    temp = BSC1_LDO1(1) | BSC1_LDO2(1) | BSC1_LDO3(1) | BSC1_LDO4(1);
    writePMIC(PMIC_B_SLEEP_CONTROL_1, temp);
    temp = BSC2_LDO5(1) | BSC2_LDO7(1) | BSC2_LDO8(1) | BSC2_LDO9(1);
    writePMIC(PMIC_B_SLEEP_CONTROL_2, temp);
    temp = BSC3_LDO12(1); 
    writePMIC(PMIC_B_SLEEP_CONTROL_3, temp);
#endif
  }
  
  
  command result_t StdControl.start(){
    //init unit
    uint8_t val[3];
    uint8_t mask;
    static bool start = 0;
    
    if(start == 0){
      call GPIOIRQControl.start();
      call PI2CInterrupt.enable();
      //irq is apparently active low...however trigger on both for now
      call PMICInterrupt.enable(TOSH_FALLING_EDGE);
      
      /*
       * Reset the watchdog, switch it to an interrupt, so we can disable it
       * Ignore SLEEP_N pin, enable H/W reset via button 
       */
      writePMIC(PMIC_SYS_CONTROL_A, 
		SCA_RESET_WDOG | SCA_WDOG_ACTION | SCA_HWRES_EN);
      
      // Disable all interrupts from PMIC except for ONKEY button
      mask = IMA_ONKEY_N | IMA_EXTON | IMA_CHIOVER;
      writePMIC(PMIC_IRQ_MASK_A, ~mask);
      mask = (IMB_TCTO | IMB_CCTO);
      writePMIC(PMIC_IRQ_MASK_B, ~mask);
      writePMIC(PMIC_IRQ_MASK_C, 0xFF);
      
      //read out the EVENT registers so that we can receive interrupts
      readPMIC(PMIC_EVENTS, val, 3);
      
      // Set default core voltage to 0.85 V
      //call PMIC.setCoreVoltage(B2R1_TRIM_P85_V);
 
      startLDOs();
      
      //    call PMIC.enableSBVoltage_High(TRUE, LDO_TRIM_3P0);
      //call PMIC.setIOVoltage(LDO_TRIM_3P0);
      
      //see if the charger is present and start if it is
      call PMIC.enableCharging(TRUE);
      
#if AUTO_BATTERY_MONITORING
      call batteryMonitorTimer.start(TIMER_REPEAT, BATTERY_MONITOR_PERIOD);
#endif      
      start = 1;
    }
      return SUCCESS;
  }
  
  command result_t StdControl.stop(){
    call PI2CInterrupt.disable();
    call PMICInterrupt.disable();
    CKEN &= ~CKEN_CKEN15;
    PICR = 0;
    
    return SUCCESS;
  }
  
  async event void PI2CInterrupt.fired(){
    uint32_t status, update=0;
    status = PISR;
    if(status & ISR_ITE){
      update |= ISR_ITE;
      //trace(DBG_USR1,"sent data");
    }

    if(status & ISR_BED){
      update |= ISR_BED;
      //trace(DBG_USR1,"bus error");
    }
    PISR = update;
  }
  
  task void handlePMICIrq(){
    uint8_t events[3];
    
    readPMIC(PMIC_EVENTS, events, 3);
    
    if(events[EVENTS_A_OFFSET] & EA_ONKEY_N){
      if(gotReset==TRUE){
        //eliminate error since Reset.reset is not declared as async
	call Reset.reset();
      }
      else{
	gotReset=TRUE;
      }
    }
    
    if(events[EVENTS_A_OFFSET] & EA_EXTON){
      //EXTON caused the interrupt...this is the usb plug being inserted
      trace(DBG_USR1,"USB Cable Insertion/Removal event\r\n");
      smartChargeEnable();
    }
    
    if(events[EVENTS_A_OFFSET] & EA_CHIOVER){
      //EXTON caused the interrupt...this is the usb plug being inserted
      trace(DBG_USR1,"Charger Status:  Charger Over Current Error\r\n");
      call PMIC.enableCharging(FALSE);
    }
    
    if (events[EVENTS_B_OFFSET] & EB_TCTO){
      //Total charge timeout expired...turn of charger
      trace(DBG_USR1,"Charger Status:  Total Charging Timeout Expired\r\n");
      call PMIC.enableCharging(FALSE);
    }
    
    if (events[EVENTS_B_OFFSET] & EB_CCTO){
      //Total charge timeout expired...turn off charger
      trace(DBG_USR1,"Charger Status:  Total Constant Current Charging Timeout Expired\r\n");
      call PMIC.enableCharging(FALSE);
    }
    
    //  trace(DBG_USR1,"PMIC EVENTs =%#x %#x %#x\r\n",events[0], events[1], events[2]);
  }
  
  async event void PMICInterrupt.fired(){
    
    call PMICInterrupt.clear();
    call Leds.greenToggle();
    
    post handlePMICIrq();
  }

  /*
   * The Buck2 controls the core voltage, set to appropriate trim value
   */
  command result_t PMIC.enable5V(bool enable){
    if(enable){
      writePMIC(PMIC_MISC_CONTROLB, MISC_CONTROLB_SESSION_VALID_ENABLE);
      writePMIC(PMIC_USBPUMP, (USBPUMP_USBVE | USBPUMP_EN_USBVE));
    }
    else{
      writePMIC(PMIC_MISC_CONTROLB, 0);
      writePMIC(PMIC_USBPUMP, 0);
    }
  }
  
  command result_t PMIC.setCoreVoltage(uint8_t trimValue) {
    
    call StdControl.init();  //make sure that we are init'd...otherwise this function could fail if called to early...
    
    return writePMIC(PMIC_BUCK2_REG1, (trimValue & B2R1_TRIM_MASK) | B2R1_GO);
  }
  
  command result_t PMIC.enableSBVoltage_High(bool enable, uint8_t value){
    //LDO 11
    uint8_t oldVal, newVal;
    
    //enable or disable the LDO
    readPMIC(PMIC_A_REG_CONTROL_1, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | ARC1_LDO11_EN) : (oldVal & ~ARC1_LDO11_EN);
    writePMIC(PMIC_A_REG_CONTROL_1, newVal);

    readPMIC(PMIC_B_REG_CONTROL_2, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | BRC2_LDO11_EN) : (oldVal & ~BRC2_LDO11_EN);
    writePMIC(PMIC_B_REG_CONTROL_2, newVal);

    readPMIC(PMIC_STARTUP_CONTROL, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | STARTUPCONTROL_LDO11START) : (oldVal & ~(STARTUPCONTROL_LDO11START));
    writePMIC(PMIC_STARTUP_CONTROL, newVal);

    //set the right value
    if(enable == TRUE){
      readPMIC(PMIC_LDO10_LDO11,&oldVal, 1);
      newVal = PMIC_SET_LDOHIGH_TRIM(oldVal, value);
      writePMIC(PMIC_LDO10_LDO11,newVal);
    }
  return SUCCESS;
  }
  
  command result_t PMIC.enableSBVoltage_Low(bool enable, uint8_t value){
    //LDO 10
    uint8_t oldVal, newVal;
    
    //enable or disable the LDO
    readPMIC(PMIC_A_REG_CONTROL_1, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | ARC1_LDO10_EN) : (oldVal & ~ARC1_LDO10_EN);
    writePMIC(PMIC_A_REG_CONTROL_1, newVal);

    readPMIC(PMIC_B_REG_CONTROL_2, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | BRC2_LDO10_EN) : (oldVal & ~BRC2_LDO10_EN);
    writePMIC(PMIC_B_REG_CONTROL_2, newVal);

    readPMIC(PMIC_STARTUP_CONTROL, &oldVal, 1);
    newVal = (enable == TRUE)? (oldVal | STARTUPCONTROL_LDO10START) : (oldVal & ~(STARTUPCONTROL_LDO10START));
    writePMIC(PMIC_STARTUP_CONTROL, newVal);

    
    //set the right value
    if(enable == TRUE){
      readPMIC(PMIC_LDO10_LDO11,&oldVal, 1);
      newVal = PMIC_SET_LDOLOW_TRIM(oldVal, value);
      writePMIC(PMIC_LDO10_LDO11,newVal);
    }
    
  }

  command result_t PMIC.setIOVoltage(uint8_t value){
    //LDO 18
    uint8_t oldVal, newVal;
    
    readPMIC(PMIC_LDO18_LDO19,&oldVal, 1);
    newVal = PMIC_SET_LDOLOW_TRIM(oldVal, value);
    writePMIC(PMIC_LDO18_LDO19,newVal);
    return SUCCESS;
  }
  
  
  command result_t PMIC.shutDownLDOs() {
    uint8_t oldVal, newVal;
    /* 
     * Shut down all LDOs that are not controlled by the sleep mode
     * Note, we assume here the LDO10 & LDO11 (sensor board) will be off
     * Should be moved to sensor board control
     */

    // LDO1, LDO4, LDO6, LDO7, LDO8, LDO9, LDO10, LDO 11, LDO13, LDO14

    readPMIC(PMIC_A_REG_CONTROL_1, &oldVal, 1);
    newVal = oldVal & ~ARC1_LDO13_EN & ~ARC1_LDO14_EN;
    newVal = newVal & ~ARC1_LDO10_EN & ~ARC1_LDO11_EN;	// sensor board
    writePMIC(PMIC_A_REG_CONTROL_1, newVal);

    readPMIC(PMIC_B_REG_CONTROL_1, &oldVal, 1);
    newVal = oldVal & ~BRC1_LDO1_EN & ~BRC1_LDO4_EN & ~BRC1_LDO5_EN &
             ~BRC1_LDO6_EN & ~BRC1_LDO7_EN;
    writePMIC(PMIC_B_REG_CONTROL_1, newVal);

    readPMIC(PMIC_B_REG_CONTROL_2, &oldVal, 1);
    newVal = oldVal & ~BRC2_LDO8_EN & ~BRC2_LDO9_EN & ~BRC2_LDO10_EN &
             ~BRC2_LDO11_EN & ~BRC2_LDO14_EN & ~BRC2_SIMCP_EN;
    writePMIC(PMIC_B_REG_CONTROL_2, newVal);
    
    return SUCCESS;
  }

  result_t getPMICADCVal(uint8_t channel, uint8_t *val){
    uint8_t oldval;
    result_t rval;
    
    //read out the old value so that we can reset at the end
    rval= readPMIC(PMIC_ADC_MAN_CONTROL, &oldval,1);
    rcombine(rval,writePMIC(PMIC_ADC_MAN_CONTROL, PMIC_AMC_LDO_INT_Enable));
    TOSH_uwait(20);
    rcombine(rval,writePMIC(PMIC_ADC_MAN_CONTROL, PMIC_AMC_ADCMUX(channel) | PMIC_AMC_MAN_CONV | PMIC_AMC_LDO_INT_Enable));
    rcombine(rval, readPMIC(PMIC_MAN_RES,val,1));
    //reset to old state
    rcombine(rval,writePMIC(PMIC_ADC_MAN_CONTROL, oldval));
    return rval;
  }
  
  command result_t PMIC.getBatteryVoltage(uint8_t *val){
    //for now, let's use the manual conversion mode
    return getPMICADCVal(0, val);
  }
  
  command result_t PMIC.chargingStatus(uint8_t *vBat, uint8_t *vChg, 
                                       uint8_t *iChg, uint8_t *chargeControl){
    
    if(vBat && vChg && iChg && chargeControl){
      readPMIC(PMIC_VBAT_RES,vBat,1);
      readPMIC(PMIC_VCHMIN_RES,vChg,1);
      readPMIC(PMIC_ICHAVERAGE_RES,iChg,1);
      readPMIC(PMIC_CHARGE_CONTROL,chargeControl, 1);
      return SUCCESS;
    }
    else{
      return FAIL;
    }
  }  
    
  command result_t PMIC.enableCharging(bool enable){
    //just turn on or off the LED for now!!
    uint8_t val;
    
    if(enable){
      //want to turn on the charger
      val = getChargerVoltage();
      //if charger is present due some stuff...75 should be 4.65V or so 
      if(val > CHARGER_VOLTAGE_TARGET ) {
	trace(DBG_USR1,"Enabling Charger...Charger Voltage is %.3fV\r\n", CHARGER_VOLTAGE(val));
	
	//write the total timeout to be 15 hours...15 hours should be fine for a 1.6AH battery (we'll never be that discharged)
	writePMIC(PMIC_TCTR_CONTROL,15);
	
	//enable the charger at 100mA and 4.2V...note that the datasheet is off by 1 line for the current setting
	writePMIC(PMIC_CHARGE_CONTROL,PMIC_CC_CHARGE_ENABLE | PMIC_CC_ISET(1) | PMIC_CC_VSET(4));
	//turn on the LED
	writePMIC(PMIC_LED1_CONTROL,0x80);
	//turn on the autoADC features that we care about
	writePMIC(PMIC_ADC_MAN_CONTROL,PMIC_AMC_LDO_INT_Enable);
	writePMIC(PMIC_ADC_AUTO_CONTROL,0xE);
	//start a timer to monitor our progress every 5 minutes!
	call chargeMonitorTimer.start(TIMER_REPEAT,CHARGER_MONITOR_PERIOD);
	return SUCCESS;
      }
      else{
	trace(DBG_USR1,"Charger Voltage is %.3fV...charger not enabled\r\n", CHARGER_VOLTAGE(val));
	//intentionally fall through 
      }
    }
    //we failed for some reason or want to diable the charger...
    //turn off the charger and the LED
    call PMIC.getBatteryVoltage(&val);
    trace(DBG_USR1,"Disabling Charger...Battery Voltage is %.3fV\r\n", BATTERY_VOLTAGE(val));
    //disable everything that we enabled
    writePMIC(PMIC_TCTR_CONTROL,0x0);
    writePMIC(PMIC_CHARGE_CONTROL,0x0);
    writePMIC(PMIC_LED1_CONTROL,0x0);
    writePMIC(PMIC_ADC_MAN_CONTROL,0x0);
    writePMIC(PMIC_ADC_AUTO_CONTROL,0x0);
    call chargeMonitorTimer.stop();
    return SUCCESS; 
  }  
  
  event result_t batteryMonitorTimer.fired(){
    uint8_t vBat;
    
    vBat =  getBatteryVoltage();
    trace(DBG_USR1,"Battery Status:  Current Battery Voltage is %.3fV\r\n",BATTERY_VOLTAGE(vBat));
    if(BATTERY_VOLTAGE(vBat) < CHARGER_TURN_ON_BATTERY_VOLTAGE){
      //battery voltage has dropped below the level that we want to enable the charger
      smartChargeEnable();
    }
    
    if(BATTERY_VOLTAGE(vBat) < MIN_BATTERY_VOLTAGE){
      trace(DBG_USR1,"Battery voltage is below minimum of %f....turning off mote\r\n", MIN_BATTERY_VOLTAGE);
      //need to add code to turn off MOTE
    }
    return SUCCESS;
  }
  
  event result_t chargeMonitorTimer.fired(){
    uint8_t vBat, vChg, iChg,chargeControl;
    call PMIC.chargingStatus(&vBat, &vChg, &iChg,&chargeControl);
    
    trace(DBG_USR1,"Charging Status:  vBat = %.3fV %vChg = %.3fV iChg = %.3fA chargeControl =%#x\r\n", 
	  BATTERY_VOLTAGE(vBat),
	  CHARGER_VOLTAGE(vChg), 
	  ((iChg * .01035)/1.656),
	  chargeControl);
    
    if(BATTERY_VOLTAGE(vBat) > CHARGER_TURN_OFF_BATTERY_VOLTAGE){
      trace(DBG_USR1,"Charging Status:  Battery is charged...Battery Voltage is %.3fV\r\n", BATTERY_VOLTAGE(vBat));
      call PMIC.enableCharging(FALSE);
      call chargeMonitorTimer.stop();
    }
    return SUCCESS;
  }
  
  command BluSH_result_t BatteryVoltage.getName(char *buff, uint8_t len){
    
    const char name[] = "BatteryVoltage";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
  
  command BluSH_result_t BatteryVoltage.callApp(char *cmdBuff, uint8_t cmdLen,
					      char *resBuff, uint8_t resLen){
    uint8_t val;
    if(call PMIC.getBatteryVoltage(&val)){
      trace(DBG_USR1,"Battery Voltage is %.3fV\r\n", BATTERY_VOLTAGE(val));
    }
    else{
      trace(DBG_USR1,"Error:  getBatteryVoltage failed\r\n");
    }
    return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t ChargingStatus.getName(char *buff, uint8_t len){
    
    const char name[] = "ChargingStatus";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
  
  command BluSH_result_t ChargingStatus.callApp(char *cmdBuff, uint8_t cmdLen,
					      char *resBuff, uint8_t resLen){
    uint8_t vBat, vChg, iChg,chargeControl;
    call PMIC.chargingStatus(&vBat, &vChg, &iChg,&chargeControl);
    trace(DBG_USR1,"vBat = %.3fV %vChg = %.3fV iChg = %.3fA chargeControl =%#x\r\n", BATTERY_VOLTAGE(vBat),CHARGER_VOLTAGE(vChg), ((iChg * .01035)/1.656),chargeControl);

    return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t ManualCharging.getName(char *buff, uint8_t len){
    
    const char name[] = "ManualCharging";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
   
  command BluSH_result_t ManualCharging.callApp(char *cmdBuff, uint8_t cmdLen,
					      char *resBuff, uint8_t resLen){
    smartChargeEnable();
    return BLUSH_SUCCESS_DONE;
  }

   command BluSH_result_t ReadPMIC.getName(char *buff, uint8_t len){
    
    const char name[] = "ReadPMIC";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
  
  
  command BluSH_result_t ReadPMIC.callApp(char *cmdBuff, uint8_t cmdLen,
					  char *resBuff, uint8_t resLen){
    uint32_t address;
    uint8_t data;
    if(strlen(cmdBuff) <strlen("ReadPMIC 22")){
      sprintf(resBuff,"Please enter an address to read\r\n");
      }
    else{
      sscanf(cmdBuff,"ReadPMIC %x", &address);
      readPMIC(address, &data,1);
      trace(DBG_USR1,"read %#x from PMIC address %#x\r\n",data, address);
    }
    return BLUSH_SUCCESS_DONE;
  }
  command BluSH_result_t WritePMIC.getName(char *buff, uint8_t len){
    
    const char name[] = "WritePMIC";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
  
  
  command BluSH_result_t WritePMIC.callApp(char *cmdBuff, uint8_t cmdLen,
					      char *resBuff, uint8_t resLen){
    uint32_t address, data;
    if(strlen(cmdBuff) <strlen("WritePMIC 22 22")){
      sprintf(resBuff,"Please enter an address and a value to write\r\n");
      }
    else{
      sscanf(cmdBuff,"WritePMIC %x %x", &address, &data);
      writePMIC(address, data);
      trace(DBG_USR1,"Wrote %#x to PMIC address %#x\r\n",data, address);
    }
    return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t SetCoreVoltage.getName(char *buff, uint8_t len){
    
    const char name[] = "SetCoreVoltage";
    strcpy(buff,name);
    return BLUSH_SUCCESS_DONE;
  }
  
  
  command BluSH_result_t SetCoreVoltage.callApp(char *cmdBuff, uint8_t cmdLen,
					      char *resBuff, uint8_t resLen){
    uint32_t voltage;
    uint32_t trim;
    if(strlen(cmdBuff) <strlen("SetCoreVoltage 222")){
      sprintf(resBuff,"Please enter the voltage in mV, range 850 - 1625 in 25mV steps\r\n");
      }
    else{
      sscanf(cmdBuff,"SetCoreVoltage %d", &voltage);
      if ((voltage < 850) || (voltage > 1625)) {
         trace(DBG_USR1, "Invalid voltage %d mV", voltage);
         return BLUSH_SUCCESS_DONE;
      } 
      // convert to trim value
      trim = (uint8_t) ((voltage - 850) / 25);
      call PMIC.setCoreVoltage(trim);
      trace(DBG_USR1,"Wrote voltage %d, trim %d\r\n",trim*25+850, trim);
    }
    return BLUSH_SUCCESS_DONE;
  }
}
