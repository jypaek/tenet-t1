/*
 * Authors: Jeongyeup Paek, Sumit Rangwala
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @author Sumit Rangwala
 * @modified 3/21/2005
 */

/* Usage sequence 
	(a) Power On 
	(b) Start Sampling 
	(c) Sampling Complete event 
	(d) Get Data
	(e) Data Ready event

	Data sample are received by repeating
	 (d) and (e)
*/


// IMPORTANT (-jpaek)
//	- This interface is different from that we used for Wisden.
//	- This is for Sensys05
//	- Do not mix them up

includes MDA400H;

interface MDA400I { 

	command result_t init();

	/* POWER ON */
	command result_t powerOn();
	event void powerOnDone(result_t success);

	/* POWER OFF */
	command result_t powerOff();
	event void powerOffDone(result_t success);
	
	/* START SAMPLING */
	// Vboard requires the 'sampling_period' to be specified, rather than sampling frequency
	//  - s_period: sampling period = 1/sampling_freq
	//  - ch_sel: channel select bitmat. lower 4 bits represents each channel.
	//  - num_ks_per_ch: number of kilo samples per channel

	command result_t startSampling(uint16_t s_period, 
	                               uint8_t ch_sel, 
                                   uint16_t num_ks_per_ch, 
	                               uint8_t onset_det);

	// Continuous sampling for Wisden V2
	//  - continuous sampling assumes usage of 7ksamples/channel
	//  - continuous sampling assumes onset-detection for sampling rate > 50Hz
	command result_t startContinuousSampling(uint16_t s_period,
	                                         uint8_t ch_sel, 
                                             uint8_t onset_det);

	event void startSamplingDone(result_t success);

	/* SAMPLING DONE */
	event void samplingComplete(); 

	/* STOP SAMPLING */
	command result_t stopSampling();
	event void stopSamplingDone(result_t success);
 
	/* GET SAMPLED DATA */
    command result_t getData(uint8_t ch_num, uint8_t num_samples, uint16_t sample_offset);
	// - ch_num: channel number (1,2,3,4)
	// - num_samples: number of samples (1 ~ AVAILABLE_DATA_SPACE_IN_PACKET/2)
	// - sample_offset: offset=0 is the first packet.
	event void dataReady(uint8_t num_bytes, uint8_t *data);
	
    command result_t getNextEventData(uint8_t ch_num, uint8_t num_samples);

	event void nextEventDataReady(uint8_t num_bytes, uint8_t *data, uint32_t timestamp);

    command result_t getNextAvailData(uint8_t ch_num, uint8_t num_samples);

	event void nextAvailDataReady(uint8_t num_bytes, uint8_t *data);

}

