
module DummyRadioC {
	provides interface RadioControl;
}
implementation {
    uint8_t m_power = 0xff;
    uint8_t m_channel = 11;
    
    command result_t RadioControl.TunePreset(uint8_t channel) {
        m_channel = channel;
        return SUCCESS;
    }
    command uint8_t RadioControl.GetPreset() {
        return m_channel;
    }
    command result_t RadioControl.SetRFPower(uint8_t power) {
        m_power = power;
        return SUCCESS;
    }
	command uint8_t RadioControl.GetRFPower() {
		return m_power;
	}
}	

