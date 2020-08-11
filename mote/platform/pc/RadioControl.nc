
/* Dummy RadioControl interface for TOSSIM */

interface RadioControl {

    /**
     * Tune the radio to one of the 802.15.4 present channels.
     * Valid channel values are 11 through 26.
     * The channels are calculated by:
     *  Freq = 2405 + 5(k-11) MHz for k = 11,12,...,26
     * 
     * @param freq requested 802.15.4 channel
     * 
     * @return Status of the tune operation
     */
    command result_t TunePreset(uint8_t channel); 

    /**
     * Get the current channel of the radio
     *
     * WARNING: If running the CC2420 on a non-standard IEEE 802.15.4
     * frequency, this function will return the closest possible 
     * valid IEEE 802.15.4 channel even if the current frequency in use is not
     * a valid IEEE 802.15.4 frequency
     *
     * @return The current CC2420 channel (k=11..26)
     */
    command uint8_t GetPreset();

    /**
     * Set the transmit RF power value.  
     * The input value is simply an arbitrary
     * index that is programmed into the CC2420 registers.  
     * The output power is set by programming the power amplifier.
     * Valid values are 1 through 31 with power of 1 equal to
     * -25dBm and 31 equal to max power (0dBm)
     *
     * @param power A power index between 1 and 31
     * 
     * @result SUCCESS if the radio power was adequately set.
     *
     */
    command result_t SetRFPower(uint8_t power);	

    /**
     * Get the present RF power index.
     *
     * @result The power index value.
     */
    command uint8_t  GetRFPower();		
}


