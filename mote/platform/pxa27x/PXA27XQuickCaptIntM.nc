/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2005 Intel Corporation 
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
 */
/**                                         
 * Description - PXA27X Quick Capture Interface module.
 * 
 * @author Konrad Lorincz
 * @version 1.0, August 10, 2005
 */
includes pxa27x_registers;
includes PXA27XQuickCaptInt;


module PXA27XQuickCaptIntM
{
    provides interface StdControl;
    provides interface PXA27XQuickCaptInt;
    
    uses interface PXA27XInterrupt as PXA27XQuickCaptIntIrq;
    uses interface PXA27XHPLDMA;
}
implementation
{
    // ======================= Data ==================================
    uint32_t nbrBytesToTransfer = Image_MAX_ROWS*Image_MAX_COLS*4;  // depends on the image size


    // ======================= Methods ===============================
    // ----------------------- DMA Helper functions ------------------

    void DMA_setSourceAddr(DMADescriptor_t* descPtr, uint32_t val)
    {
        atomic{ descPtr->DSADR = val; }
    }

    void DMA_setTargetAddr(DMADescriptor_t* descPtr, uint32_t val)
    {
        atomic{ descPtr->DTADR = val; }
    }
    
    void DMA_enableSourceAddrIncrement(DMADescriptor_t* descPtr, bool enable)
    {
        atomic{ descPtr->DCMD = (enable == TRUE) ? descPtr->DCMD | DCMD_INCSRCADDR : descPtr->DCMD & ~DCMD_INCSRCADDR; }
    }

    void DMA_enableTargetAddrIncrement(DMADescriptor_t* descPtr, bool enable)
    {
        atomic{ descPtr->DCMD = (enable == TRUE) ? descPtr->DCMD | DCMD_INCTRGADDR : descPtr->DCMD & ~DCMD_INCTRGADDR; }
    }

    void DMA_enableSourceFlowControl(DMADescriptor_t* descPtr, bool enable)
    {
        atomic{descPtr->DCMD = (enable == TRUE) ? descPtr->DCMD | DCMD_FLOWSRC : descPtr->DCMD & ~DCMD_FLOWSRC;}
    }
  
    void DMA_enableTargetFlowControl(DMADescriptor_t* descPtr, bool enable)
    {
        descPtr->DCMD = (enable == TRUE) ? descPtr->DCMD | DCMD_FLOWTRG : descPtr->DCMD & ~DCMD_FLOWTRG;
    } 
  
    void DMA_setMaxBurstSize(DMADescriptor_t* descPtr, DMAMaxBurstSize_t size)
    {
        if(size >= DMA_8ByteBurst && size <= DMA_32ByteBurst){
            atomic{
            	//clear it out since otherwise |'ing doesn't work so well
            	descPtr->DCMD &= ~DCMD_MAXSIZE;  
            	descPtr->DCMD |= DCMD_SIZE(size); 
            }
        }        
    }
  
    void DMA_setTransferLength(DMADescriptor_t* descPtr, uint16_t length)
    {
        uint16_t currentLength;
        currentLength = (length<8192) ? length: 8190;
        atomic{
            descPtr->DCMD &= ~DCMD_MAXLEN; 
            descPtr->DCMD |= DCMD_LEN(currentLength); 
        }
    }
  
    void DMA_setTransferWidth(DMADescriptor_t* descPtr, DMATransferWidth_t width)
    {
        atomic{
        	//clear it out since otherwise |'ing doesn't work so well
	        descPtr->DCMD &= ~DCMD_MAXWIDTH; 
         	descPtr->DCMD |= DCMD_WIDTH(width);
	    }        
    }

    void DMA_run()
    {
        atomic{
            uint32_t dcsr = call PXA27XHPLDMA.getDCSR(CIF_CHAN);

            call PXA27XHPLDMA.mapChannel(CIF_CHAN, DMAREQ_CIF_RECV_0);
	        call PXA27XHPLDMA.setByteAlignment(CIF_CHAN, TRUE);
            dcsr &= ~(DCSR_RUN);
            dcsr &= ~(DCSR_NODESCFETCH);
            call PXA27XHPLDMA.setDCSR(CIF_CHAN, dcsr);
            call PXA27XHPLDMA.setDDADR(CIF_CHAN,  DescArray_get(&descArray, 0) );
            call PXA27XHPLDMA.setDCSR(CIF_CHAN,  (call PXA27XHPLDMA.getDCSR(CIF_CHAN)) | DCSR_RUN );
        }
    }
          

    // ----------------------- Internal private helper functions -----
    void CIF_configurePins()
    {
        // (1) - Configure the GPIO Alt functions and direction
        // --- Template ----
        //_GPIO_setaltfn(PIN, PIN_ALTFN);
        //_GPDR(PIN) &= ~_GPIO_bit(PIN);  // input
        //_GPDR(PIN) |= _GPIO_bit(PIN);   // output
        // -----------------
        
        // CIF_MCLK
        _GPIO_setaltfn(PIN_CIF_MCLK, PIN_CIF_MCLK_ALTFN);
        //_GPDR(PIN_CIF_MCLK) &= ~_GPIO_bit(PIN_CIF_MCLK);  // input
        _GPDR(PIN_CIF_MCLK) |= _GPIO_bit(PIN_CIF_MCLK);   // output (if sensor is master)

        // CIF_PCLK 
        _GPIO_setaltfn(PIN_CIF_PCLK, PIN_CIF_PCLK_ALTFN);
        _GPDR(PIN_CIF_PCLK) &= ~_GPIO_bit(PIN_CIF_PCLK);  // input (if sensor is master)

        // CIF_FV
        _GPIO_setaltfn(PIN_CIF_FV, PIN_CIF_FV_ALTFN);
        _GPDR(PIN_CIF_FV) &= ~_GPIO_bit(PIN_CIF_FV);  // input (if sensor is master)
        //_GPDR(PIN_CIF_FV) |= _GPIO_bit(PIN_CIF_FV);   // output (if sensor is slave)

        // CIF_LV
        _GPIO_setaltfn(PIN_CIF_LV, PIN_CIF_LV_ALTFN);
        _GPDR(PIN_CIF_LV) &= ~_GPIO_bit(PIN_CIF_LV);  // input (if sensor is master)
        //_GPDR(PIN_CIF_LV) |= _GPIO_bit(PIN_CIF_LV);   // output (if sensor is slave)


        // CIF_DD0 ... CIF_DD9
        _GPIO_setaltfn(PIN_CIF_DD0, PIN_CIF_DD0_ALTFN);
        _GPDR(PIN_CIF_DD0) &= ~_GPIO_bit(PIN_CIF_DD0);  // input

        _GPIO_setaltfn(PIN_CIF_DD1, PIN_CIF_DD1_ALTFN);
        _GPDR(PIN_CIF_DD1) &= ~_GPIO_bit(PIN_CIF_DD1);  // input

        _GPIO_setaltfn(PIN_CIF_DD2, PIN_CIF_DD2_ALTFN);
        _GPDR(PIN_CIF_DD2) &= ~_GPIO_bit(PIN_CIF_DD2);  // input

        _GPIO_setaltfn(PIN_CIF_DD3, PIN_CIF_DD3_ALTFN);
        _GPDR(PIN_CIF_DD3) &= ~_GPIO_bit(PIN_CIF_DD3);  // input

        _GPIO_setaltfn(PIN_CIF_DD4, PIN_CIF_DD4_ALTFN);
        _GPDR(PIN_CIF_DD4) &= ~_GPIO_bit(PIN_CIF_DD4);  // input

        _GPIO_setaltfn(PIN_CIF_DD5, PIN_CIF_DD5_ALTFN);
        _GPDR(PIN_CIF_DD5) &= ~_GPIO_bit(PIN_CIF_DD5);  // input

        _GPIO_setaltfn(PIN_CIF_DD6, PIN_CIF_DD6_ALTFN);
        _GPDR(PIN_CIF_DD6) &= ~_GPIO_bit(PIN_CIF_DD6);  // input

        _GPIO_setaltfn(PIN_CIF_DD7, PIN_CIF_DD7_ALTFN);
        _GPDR(PIN_CIF_DD7) &= ~_GPIO_bit(PIN_CIF_DD7);  // input

        _GPIO_setaltfn(PIN_CIF_DD8, PIN_CIF_DD8_ALTFN);
        _GPDR(PIN_CIF_DD8) &= ~_GPIO_bit(PIN_CIF_DD8);  // input

        _GPIO_setaltfn(PIN_CIF_DD9, PIN_CIF_DD9_ALTFN);
        _GPDR(PIN_CIF_DD9) &= ~_GPIO_bit(PIN_CIF_DD9);  // input
    }
    
    void CIF_setAndEnableCICR0(uint32_t data)
    {
        call PXA27XQuickCaptInt.disableQuick();
        CICR0 = (data | CICR0_EN);
    }
    

    void CIF_InitDMA() 
    {
        uint8_t i = 0;
        DMADescriptor_t* descPtr = NULL;
        uint32_t bytesLeftToSchedule = nbrBytesToTransfer;


        for (i = 0; bytesLeftToSchedule > 0; ++i) {
            descPtr = DescArray_get(&descArray, i);

            DMA_setSourceAddr(descPtr, CIBR0_ADDR);
            DMA_setTargetAddr(descPtr, &image.data[ i*(MAX_DESC_TRANSFER/4) ]);
            DMA_enableSourceAddrIncrement(descPtr, FALSE);
            DMA_enableTargetAddrIncrement(descPtr, TRUE);
            DMA_enableSourceFlowControl(descPtr, TRUE);
            DMA_enableTargetFlowControl(descPtr, FALSE);
            DMA_setMaxBurstSize(descPtr, 3);      // burst size: can be 8, 16, or 32 bytes
            DMA_setTransferWidth(descPtr, 3);     // peripheral width for DMA transactions from CIF is always 8-bytes, regardless of DCMD[WIDTH]
            
            if (bytesLeftToSchedule >= MAX_DESC_TRANSFER) {
                DMA_setTransferLength(descPtr, MAX_DESC_TRANSFER);  // 16*8 *2 =256 bytes // must be an integer multiple of 8-bytes
                bytesLeftToSchedule -= MAX_DESC_TRANSFER;
            }
            else {
                DMA_setTransferLength(descPtr, bytesLeftToSchedule);
                bytesLeftToSchedule = 0;
            }

            // continue running the next descriptor
            descPtr->DDADR = DescArray_get(&descArray, i+1);
        }

        // Set the stop bit for the last descriptor
        descPtr->DDADR |= DDADR_STOP;
    }

    void CIF_init()
    { 
        //atomic enabledInterrupts = 0;

        CKEN |= CKEN24_CIF;              // enable the CIF clock
    
        call PXA27XQuickCaptIntIrq.allocate(); // generate an CIF interrupt
        call PXA27XQuickCaptIntIrq.enable();   // enable the CIF interrupt mask
        
        // ------------------------------------------------------
        // (1) - Disable the CIF interface
        call PXA27XQuickCaptInt.disableQuick();
        
        // (2) - Set the timing/clocks
        // a. Have the mote supply the MCLK to the camera sensor
        CICR4 = CICR4_DIV(CICR4, 2);  // Set the MCLK clock rate to 15 MHz
        CICR4 |= CICR4_MCLK_EN;

        // b. Have the camera suply the PCLK to the mote
        CICR4 |= CICR4_PCLK_EN;

        // c. Set the synchronization signals to be active low
        CICR4 |= CICR4_HSP;
        CICR4 |= CICR4_VSP;

        // (3) - Set the data format (nbr pixels, color space, encoding, etc.)
        CICR1 = CICR1_DW(CICR1, 4);          // Data Width:  10 bits wide data from the sensor
        CICR1 = CICR1_COLOR_SP(CICR1, 0);    // Color Space: Raw
        CICR1 = CICR1_RAW_BPP(CICR1, 2);     // Raw bits per pixel: 10
        CICR3 = CICR3_LPF(CICR3, (1024-1));  // lines per frame (rows): 1024
        CICR1 = CICR1_PPL(CICR1, (1280-1));  // pixels per line (cols): 1280            
        
        // (4) - FIFO DMA threshold level
        CIFR = CIFR_THL_0(CIFR, 0);          // 96 bytes of more in FIFO 0 causea a DMA request
                      
        // (5) - Initialize the DMA                                                 
        CIF_InitDMA();
                                  
        // (6) - Enable the CIF with DMA
        CIF_setAndEnableCICR0(CICR0 | CICR0_DMA_EN);
    }

   
    // ----------------------- StdControl interface ------------------
    command result_t StdControl.init() 
    {
        CIF_configurePins();
        CIF_init();        
        return SUCCESS;
    }

    command result_t StdControl.start() 
    {            
        return SUCCESS;
    }

    command result_t StdControl.stop() 
    {
        call PXA27XQuickCaptIntIrq.disable();   // disable the CIF interrupt mask
        return SUCCESS;
    }

    // ----------------------- PXA27XQuickCaptInt  ------------------
    command void PXA27XQuickCaptInt.enable()
    {
        uint32_t tempCICR0 = CICR0;
        tempCICR0 |= CICR0_EN;
        CICR0 = tempCICR0;
    } 

    command void PXA27XQuickCaptInt.disableQuick()
    {
        CICR0 &= ~(CICR0_EN);
        CISR |= CISR_CQD;
    } 

    command void PXA27XQuickCaptInt.startDMA()
    {
        DMA_run();
    }

    command result_t PXA27XQuickCaptInt.setImageSize(uint16_t sizeX, uint16_t sizeY)
    {
        if (sizeX > 2048 || sizeY > 2048)
            return FAIL;
        else {         
            // (1) - Set the Quick Capture Interface Size
            call PXA27XQuickCaptInt.disableQuick();
            CICR1 = CICR1_PPL(CICR1, (sizeX-1));
            CICR3 = CICR3_LPF(CICR3, (sizeY-1));
            call PXA27XQuickCaptInt.enable();

            // (2) - Set the DMA transfer size
            nbrBytesToTransfer = sizeX*sizeY*2;  // each pixel is 2 bytes

            return SUCCESS;
        }
    }



    command void PXA27XQuickCaptInt.enableStartOfFrame()       {CIF_setAndEnableCICR0(CICR0 & ~(CICR0_SOFM));}
    command void PXA27XQuickCaptInt.enableEndOfFrame()         {CIF_setAndEnableCICR0(CICR0 & ~(CICR0_EOFM));}
    command void PXA27XQuickCaptInt.enableEndOfLine()          {CIF_setAndEnableCICR0(CICR0 & ~(CICR0_EOLM));}
    command void PXA27XQuickCaptInt.enableRecvDataAvailable()  {CIF_setAndEnableCICR0(CICR0 & ~(CICR0_RDAVM));}
    command void PXA27XQuickCaptInt.enableFIFOOverrun()        {CIF_setAndEnableCICR0(CICR0 & ~(CICR0_FOM));}

    uint32_t fifoBuffer[32];

    // ---------------------- PXA27XInterrupt interface -------------------------
    async event void PXA27XQuickCaptIntIrq.fired() 
    {            
        //atomic{printfUART(">>>>>>>>>>>>>>> PXA27XQuickCaptIntIrq.fired() >>>>>>>>>>>\n", "");}
        volatile uint32_t tempCISR;
        atomic {  tempCISR = CISR; }
        // Start-Of-Frame
        if ((tempCISR & CISR_SOF) && (~(CICR0) & CICR0_SOFM)) {
            atomic CISR |= CISR_SOF;
            signal PXA27XQuickCaptInt.startOfFrame();                         
        }
        // End-Of-Frame
        if ((tempCISR & CISR_EOF) && (~(CICR0) & CICR0_EOFM)) {
            atomic CISR |= CISR_EOF;
            signal PXA27XQuickCaptInt.endOfFrame();            
        }
        // End-Of-Line
        if ((tempCISR & CISR_EOL) && (~(CICR0) & CICR0_EOLM)) {
            atomic CISR |= CISR_EOL;
            signal PXA27XQuickCaptInt.endOfLine();
        }
        // Receive-Data-Available
        if (~(CICR0) & CICR0_RDAVM) {
            if (tempCISR & CISR_RDAV_2) {  // channel 2
                atomic CISR |= CISR_RDAV_2;
                signal PXA27XQuickCaptInt.recvDataAvailable(2);        
            }
            if (tempCISR & CISR_RDAV_1) {  // channel 1
                atomic CISR |= CISR_RDAV_1;
                signal PXA27XQuickCaptInt.recvDataAvailable(1);        
            }
            if (tempCISR & CISR_RDAV_0) {  // channel 0
                atomic CISR |= CISR_RDAV_0;
                signal PXA27XQuickCaptInt.recvDataAvailable(0);
            }
        }  
        // FIFO Overrun
        if (~(CICR0) & CICR0_FOM) {
            if (tempCISR & CISR_IFO_2) {  // channel 2
                atomic CISR |= CISR_IFO_2;
                signal PXA27XQuickCaptInt.fifoOverrun(2);        
            }
            if (tempCISR & CISR_IFO_1) {  // channel 1
                atomic CISR |= CISR_IFO_1;
                signal PXA27XQuickCaptInt.fifoOverrun(1);        
            }
            if (tempCISR & CISR_IFO_0) {  // channel 0
                atomic CISR |= CISR_IFO_0;
                signal PXA27XQuickCaptInt.fifoOverrun(0);
            }
        }  

    }

}

