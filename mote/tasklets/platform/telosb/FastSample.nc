/*
 * Samples up to three channels at high rates using the DMA for reduced CPU
 * overhead and jitter.
 *
 * @author Ben Greenstein
 * @author August Joki
*/

includes tenet_task;

module FastSample {
  provides {
    interface StdControl;
    interface Element;
  }
  uses {
    interface Schedule;
    interface TenetTask;
    interface Memory;

    interface Leds;
    interface AsyncToSync as Q0;
    interface AsyncToSync as Q1;
    interface AsyncToSync as Q2;

    interface StdControl as ADCControl;

    interface MSP430DMAControl as DMAControl;
    interface MSP430DMA as DMA0;
    interface MSP430DMA as DMA1;
    interface MSP430DMA as DMA2;
    interface MSP430ADC12MultipleChannel as ADC;

  }
}
implementation {
#include "tenet_debug.h"
#include "MSP430ADC12.h"

#define INPUTMEM0 (ADC12MEM0_)
#define INPUTMEM1 (ADC12MEM1_)
#define INPUTMEM2 (ADC12MEM2_)

  MSP430REG_NORACE(DMA0CTL);
  MSP430REG_NORACE(DMA1CTL);
  MSP430REG_NORACE(DMA2CTL);
  MSP430REG_NORACE(DMA0DA);
  MSP430REG_NORACE(DMA1DA);
  MSP430REG_NORACE(DMA2DA);
  MSP430REG_NORACE(ADC12CTL0);
  MSP430REG_NORACE(ADC12CTL1);
  MSP430REG_NORACE(ADC12IFG);
  MSP430REG_NORACE(ADC12IV);

  enum {
    ADC_OFF,
    ADC_ON,
    ADC_COLLECTING
  };

  typedef struct {
    element_t e;
    uint16_t rate;
    uint16_t count;
    uint32_t sampleNumber;
    uint8_t numChannels;
    uint8_t chansDone;
    result_t sampleResult;
    uint8_t dataAddedMask;
    uint8_t channel[FAST_CHANNELS];
    tag_t outputName[FAST_CHANNELS];
  } __attribute__((packed)) fastSample_element_t;

  typedef struct {
      uint32_t sampleNumber;
      uint16_t data[0];
  } __attribute__((packed)) data_buffer_t;

  typedef struct {
    data_buffer_t *onDeck;
    data_buffer_t *currentSet;
    uint32_t sampleNumber;
  } __attribute__((packed)) channel_request_t;

  void start_sampling();
  void restart_sampling();
  void transferDone(uint8_t channel, result_t s);

  inline void repeat_transfers(data_buffer_t *ss0, data_buffer_t *ss1, data_buffer_t *ss2);
  inline data_buffer_t *prepare_data_buffer(uint8_t channel);

  element_t *fastSample_construct(task_t *t, void *data, int length);
  sched_action_t fastSample_run(active_task_t *active_task);
  void fastSample_suicide(task_t *t);

  /* Platform dependent */
  void adc_start() {
    call ADCControl.start();
  }

  void adc_stop() {
    call ADCControl.stop(); // maybe this will work
  }
/*
  result_t adc_init() {
    int ii;
    for (ii = 0; ii < FAST_CHANNELS; ii++) {
      m_channelRequest[ii].currentSet = NULL;
    }

    TOSH_SEL_ADC0_MODFUNC(); //XXX these need to be guarded or we might be
    TOSH_MAKE_ADC0_INPUT();  //XXX setting a pin to input when something
    TOSH_SEL_ADC1_MODFUNC(); //XXX else wants to output on the pin.
    TOSH_MAKE_ADC1_INPUT();  
    TOSH_SEL_ADC2_MODFUNC(); //XXX Is the # of channels know before this
    TOSH_MAKE_ADC2_INPUT();  //XXX point?

    return call ADCControl.init();
	}
*/
	/* ======================== */

  uint8_t m_state;
  norace channel_request_t m_channelRequest[FAST_CHANNELS];

  active_task_t *m_a, *m_aClone;
  fastSample_element_t *m_e;



  element_t *fastSample_construct(task_t *t, void *data, int length) {
    fastSample_element_t *e;
    fastSample_params_t *p = (fastSample_params_t *)data;
    if (data == NULL || length < sizeof(fastSample_params_t)) {
      tlog(LOG_ERR,"bad params %x length = %d\n",data,length);
      return NULL;
    }
    if ((e = (fastSample_element_t *)call Memory.malloc(sizeof(fastSample_element_t))) == NULL) {
      tlog(LOG_ERR,"allocation failed\n");
      return NULL;
    }
    call TenetTask.element_construct(t, (element_t *)e,
                                ELEMENT_FASTSAMPLE,
                                fastSample_run,
                                fastSample_suicide);
    e->rate = p->rate;
    e->count = p->count;
    e->numChannels = p->numChannels;
    e->channel[0] = p->channel[0];
    e->channel[1] = p->channel[1];
    e->channel[2] = p->channel[2];
    e->outputName[0] = p->outputName[0];
    e->outputName[1] = p->outputName[1];
    e->outputName[2] = p->outputName[2];
    e->sampleNumber = 0;
    e->chansDone = 0;
    e->sampleResult = SUCCESS;
    e->dataAddedMask = 0;
    tlog(LOG_DEBUG,"rate %d count %d numChannels %d chan0 %d name0 %d chan1 %d name1 %d chan2 %d name2 %d\n",
         e->rate,e->count,e->numChannels,
         e->channel[0],e->outputName[0],
         e->channel[1],e->outputName[1],
         e->channel[2],e->outputName[2]);
    return (element_t *)e;
  }

  /*
    TODO: This component can support at most one active task.
   */

  sched_action_t fastSample_run(active_task_t *active_task) {
    if (!m_a) {
      m_a = active_task;
      m_e = (fastSample_element_t *)call TenetTask.element_this(active_task);
    }
    if (m_state == ADC_OFF) {
      m_state = ADC_COLLECTING;
			adc_start();
      start_sampling();
    }

    return SCHED_STOP;
  }
  
  void fastSample_suicide(task_t *t) {
    if (m_state == ADC_ON || m_state == ADC_COLLECTING) {
      m_state = ADC_OFF;
			adc_stop();
    }
    if (m_a) {
      call TenetTask.active_task_delete(m_a);
      m_a = NULL;
      m_e = NULL;
    }
  }

  /* hooks to tinyos */

  command result_t StdControl.init() {
    uint8_t ii;
    m_a = NULL;
    
    m_state = ADC_OFF;

    //return adc_init();
    for (ii = 0; ii < FAST_CHANNELS; ii++) {
      m_channelRequest[ii].currentSet = NULL;
    }

    TOSH_SEL_ADC0_MODFUNC(); //XXX these need to be guarded or we might be
    TOSH_MAKE_ADC0_INPUT();  //XXX setting a pin to input when something
    TOSH_SEL_ADC1_MODFUNC(); //XXX else wants to output on the pin.
    TOSH_MAKE_ADC1_INPUT();  
    TOSH_SEL_ADC2_MODFUNC(); //XXX Is the # of channels know before this
    TOSH_MAKE_ADC2_INPUT();  //XXX point?

    return call ADCControl.init();
  }

  command result_t StdControl.start() { return SUCCESS; }
  command result_t StdControl.stop() { return SUCCESS; }

  command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
    return fastSample_construct(t, data, length);
  } 

  async event void DMA0.transferDone(result_t s) { transferDone(0,s); }
  async event void DMA1.transferDone(result_t s) { transferDone(1,s); }
  async event void DMA2.transferDone(result_t s) { transferDone(2,s); }


  /* With DMA, never called but still has to be implemented*/
  async event uint16_t* ADC.dataReady(uint16_t *data, uint16_t length) {
    return data;
  }


  inline void repeat_transfers(data_buffer_t *ss0, data_buffer_t *ss1, data_buffer_t *ss2) {
	
  	void *buf0, *buf1, *buf2;
    uint8_t numChannels;
    uint16_t count;
    tlog(LOG_DEBUG,"entered\n");
    if (!m_e) { 
      tlog(LOG_DEBUG, "element is null\n");
      call Leds.redToggle(); 
      return; 
    }
    numChannels = m_e->numChannels;

  	buf0 = buf1 = buf2 = NULL;

  	if (numChannels >= 1) {
  		if ((buf0 = ss0->data) == NULL) { call Leds.redToggle(); return; }
  	}
  	if (numChannels >= 2) {
  		if ((buf1 = ss1->data) == NULL) { call Leds.redToggle(); return; }
  	}
  	if (numChannels >= 3) {
  		if ((buf2 = ss2->data) == NULL) { call Leds.redToggle(); return; }
  	}

    call ADC.pauseSampling();
/*     ADC12CTL1 &= ~0x0006;             // fast stop adc by setting CONSEQx to 00 */
/*     ADC12CTL0 &= ~ENC;               // also need to clear ENC for fast stop */


    count = m_e ? m_e->count : 0;

    switch (numChannels) {
    case 1:
      call DMA0.repeatTransfer((void *)INPUTMEM0,buf0,count);
/*   		DMA0DA = (uint16_t)buf0; */
/*   		DMA0CTL |= DMAEN;				// restart DMA0 */
  	  break;
    case 2:
      call DMA0.repeatTransfer((void *)INPUTMEM0,buf0,count);
      call DMA1.repeatTransfer((void *)INPUTMEM1,buf1,count);
/*   		DMA0DA = (uint16_t)buf0; */
/*   		DMA1DA = (uint16_t)buf1; */
/*     	DMA0CTL |= DMAEN;				// restart DMA0 */
/*     	DMA1CTL |= DMAEN;				// restart DMA1 */
    	break;
    case 3:
      call DMA0.repeatTransfer((void *)INPUTMEM0,buf0,count);
      call DMA1.repeatTransfer((void *)INPUTMEM1,buf1,count);
      call DMA2.repeatTransfer((void *)INPUTMEM2,buf2,count);
/*   		DMA0DA = (uint16_t)buf0; */
/*   		DMA1DA = (uint16_t)buf1; */
/*   		DMA2DA = (uint16_t)buf2; */
/*   		DMA0CTL |= DMAEN;				// restart DMA0 */
/*   		DMA1CTL |= DMAEN;				// restart DMA1 */
/*   		DMA2CTL |= DMAEN;				// restart DMA2 */
  	  break;
    default:
      call Leds.redToggle();
      return;
    }
    call ADC.resumeSampling();
/*     ADC12CTL1 |= 0x0006;             //set CONSEQx to 11 for multiple repeat */
/*     ADC12CTL0 |= ENC;                // repeat. */
    tlog(LOG_DEBUG,"starting transfer\n");
  }

  inline data_buffer_t *prepare_data_buffer(uint8_t channel) {
    uint16_t c;
    data_buffer_t *db;
    tlog(LOG_DEBUG,"entered\n");
    if (!m_e) { 
      tlog(LOG_DEBUG, "element is null\n");
      return NULL; 
    }
    c = m_e->count;
    c <<= 1; //each sample requires 2 bytes
    if ((db = (data_buffer_t *)call Memory.malloc(sizeof(data_buffer_t) + c)) == NULL) {
      tlog(LOG_ERR,"allocation failed\n");
      return NULL;
    }
    db->sampleNumber = m_e->sampleNumber;
    //XXX need a seqNo somewhere... is it?
    return db;
  }


  void add_to_task(data_buffer_t *db, uint8_t channelNum) {
    uint16_t bufSize;
    call Leds.greenToggle();
    if (channelNum >= m_e->numChannels) { // channelNum: 0-2 =~ numChannels 1-3
      call Memory.free(db);
      return;
    }

    if (m_e->dataAddedMask == 0) {
      m_aClone = call TenetTask.active_task_clone(m_a);
    }

    tlog(LOG_DEBUG,"mask %d channelNum %d shift %d and %d\n",
         m_e->dataAddedMask, channelNum, (1<<channelNum),
         m_e->dataAddedMask & (1<<channelNum));

    if (m_e->dataAddedMask & (1<<channelNum)) { // already in active task
      call Memory.free(db);
    }
    else {
      bufSize = m_e->count;
      bufSize *= 2;
      bufSize += sizeof(data_buffer_t);
/*       if (bufSize != 24) call Leds.redToggle(); */
      call 
        TenetTask.data_push(m_a,
                            call TenetTask.data_new_copy(m_e->outputName[channelNum],
                                                         bufSize,
                                                         db));
      call Memory.free(db);
/*       if (m_a->data->attr.length == 24) call Leds.redToggle(); */
      m_e->dataAddedMask |= (1<<channelNum);    
      if (m_e->dataAddedMask + 1 == (1<<(m_e->numChannels))) { // done
        m_e->dataAddedMask = 0;
        call Schedule.next(m_a);
        m_a = m_aClone;
        m_aClone = NULL;
      }    
    }    
  }

  event void Q0.popped(void *data) {
    tlog(LOG_DEBUG,"entered\n");
    add_to_task((data_buffer_t *)data,0); 
  }
  event void Q1.popped(void *data) { add_to_task((data_buffer_t *)data,1); }
  event void Q2.popped(void *data) { add_to_task((data_buffer_t *)data,2); }

  void transferDone(uint8_t channel, result_t s) {
    uint8_t i;
    uint8_t numChannels = m_e->numChannels;
    tlog(LOG_DEBUG,"entered\n");
    tlog(LOG_DEBUG,"channel %d\n", channel);
    if (!m_e) {
      tlog(LOG_DEBUG, "element is null\n");
      for (i = 0; i < FAST_CHANNELS; i++) { //XXX unnecessary free's when not using all channels
        call Memory.free(m_channelRequest[i].currentSet);
        // TODO: cleanup
      }
      return;
    }

    m_e->chansDone |= 0x2 << channel;
    m_e->sampleResult = rcombine(m_e->sampleResult, s);
    if ((numChannels == 1 && m_e->chansDone == 0x2) ||
        (numChannels == 2 && m_e->chansDone == 0x6) ||
        (numChannels == 3 && m_e->chansDone == 0xE)) {
      if (m_e->sampleResult == SUCCESS) {
        call Leds.yellowToggle();
      }
      else {
        call Leds.redToggle();
      }
      repeat_transfers(m_channelRequest[0].onDeck, 
                       m_channelRequest[1].onDeck, 
                       m_channelRequest[2].onDeck);

      m_e->sampleNumber += m_e->count;

      if (numChannels >= 1) {
        if (call Q0.push(m_channelRequest[0].currentSet) == FAIL) {
          call Memory.free(m_channelRequest[0].currentSet);
          call Leds.redToggle();
        }
        m_channelRequest[0].currentSet = m_channelRequest[0].onDeck;
        m_channelRequest[0].onDeck = prepare_data_buffer(0);
      }
      else if (numChannels >= 2) {
        if (call Q1.push(m_channelRequest[1].currentSet) == FAIL) {
          call Memory.free(m_channelRequest[1].currentSet);
          call Leds.redToggle();
        }
        m_channelRequest[1].currentSet = m_channelRequest[1].onDeck;
        m_channelRequest[1].onDeck = prepare_data_buffer(1);
      }
      else if (numChannels >= 3) {
        if (call Q2.push(m_channelRequest[2].currentSet) == FAIL) {
          call Memory.free(m_channelRequest[2].currentSet);
          call Leds.redToggle();
        }
        m_channelRequest[2].currentSet = m_channelRequest[2].onDeck;
        m_channelRequest[2].onDeck = prepare_data_buffer(2);
      }
      m_e->chansDone = 0;
      m_e->sampleResult = SUCCESS;
    }
  }

  void start_sampling() {
    uint8_t i;
    uint16_t count;

    tlog(LOG_DEBUG,"entered\n");

    for (i = 0; i < m_e->numChannels; i++){
      if ((m_channelRequest[i].currentSet = prepare_data_buffer(i)) == NULL){
        tlog(LOG_ERR,"out of memory\n");
        // TODO: cleanup previous channels
      }
    }

    count = m_e->count;
    
    call DMAControl.init();
    call DMAControl.setFlags(FALSE,FALSE,FALSE);
    
    // for adc's internal reference use: REFERENCE_VREFplus_AVss,
    call ADC.bind(ADC12_GLOBAL_SETTINGS(SAMPLE_HOLD_4_CYCLES,
                                        SHT_SOURCE_ADC12OSC,
                                        SHT_CLOCK_DIV_2,
                                        SAMPCON_SOURCE_SMCLK,
                                        SAMPCON_CLOCK_DIV_1,
                                        REFVOLT_LEVEL_2_5));

    //XXX eventually selectable inputs need to be configured here
  	if (m_e->numChannels >= 1) {
      call ADC.bindPin(ADC12_PIN_SETTINGS(m_e->channel[0],
                                          REFERENCE_AVcc_AVss));
      call DMA0.setupTransfer(DMA_SINGLE_TRANSFER,
                              DMA_TRIGGER_ADC12IFGx,
                              DMA_EDGE_SENSITIVE,
                              (void *)INPUTMEM0,
                              m_channelRequest[0].currentSet->data,
                              count,
                              DMA_WORD, DMA_WORD,
                              DMA_ADDRESS_UNCHANGED,
                              DMA_ADDRESS_INCREMENTED);
      m_channelRequest[0].onDeck = prepare_data_buffer(0);
  	}
    if (m_e->numChannels >= 2) {
      call ADC.bindPin(ADC12_PIN_SETTINGS(m_e->channel[1],
                                          REFERENCE_AVcc_AVss));
      call DMA1.setupTransfer(DMA_SINGLE_TRANSFER,
                              DMA_TRIGGER_ADC12IFGx,
                              DMA_EDGE_SENSITIVE,
                              (void *)INPUTMEM1,
                              m_channelRequest[1].currentSet->data,
                              count,
                              DMA_WORD, DMA_WORD,
                              DMA_ADDRESS_UNCHANGED,
                              DMA_ADDRESS_INCREMENTED);
      m_channelRequest[1].onDeck = prepare_data_buffer(1);
  	}
    if (m_e->numChannels >= 3) {
      call ADC.bindPin(ADC12_PIN_SETTINGS(m_e->channel[2],
                                          REFERENCE_AVcc_AVss));
      call DMA2.setupTransfer(DMA_SINGLE_TRANSFER,
                              DMA_TRIGGER_ADC12IFGx,
                              DMA_EDGE_SENSITIVE,
                              (void *)INPUTMEM2,
                              m_channelRequest[2].currentSet->data,
                              count,
                              DMA_WORD, DMA_WORD,
                              DMA_ADDRESS_UNCHANGED,
                              DMA_ADDRESS_INCREMENTED);
      m_channelRequest[2].onDeck = prepare_data_buffer(2);
  	}
    
    restart_sampling();
  }
  
  
  void restart_sampling() {
    tlog(LOG_DEBUG,"entered\n");
    if (!m_e) {
      tlog(LOG_DEBUG, "element is null\n");
      return;
    }

    switch (m_e->numChannels) {
    case 1:
      tlog(LOG_DEBUG,"starting transfer\n");
      call DMA0.startTransfer();
      call DMA1.startTransfer();
      break;
    case 2:
      tlog(LOG_DEBUG,"starting transfer\n");
      call DMA0.startTransfer();
      call DMA1.startTransfer();
      break;
    case 3:
      tlog(LOG_DEBUG,"starting transfer\n");
      call DMA0.startTransfer();
      call DMA1.startTransfer();
      call DMA2.startTransfer();
      break;
    default:
      tlog(LOG_DEBUG,"invalid number of channels %d\n",m_e->numChannels);
      return;
      break;
    }

    m_state = ADC_COLLECTING;
    call ADC.startSampling(m_e->rate);
  }


}
