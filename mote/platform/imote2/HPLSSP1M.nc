//@author Robbie Adler

module HPLSSP1M {
  provides {
    interface HPLSSP;
  }	
}

implementation {

  //we are SSP1...do some #defining to make things easier in the future
  #define _SSCR0 SSCR0_1
  #define _SSCR1 SSCR1_1
  #define _SSPSP SSPSP_1
  #define _SSTO SSTO_1
  #define _SSITR SSITR_1
  #define _SSSR SSSR_1
  #define _SSDR SSDR_1

  async command result_t HPLSSP.setSSCR0(uint32_t newVal){
    atomic{
      _SSCR0 = newVal;
    }
    return SUCCESS;

  }
  async command uint32_t HPLSSP.getSSCR0(){
    uint32_t temp;
    atomic{
      temp = _SSCR0;
    }
    return temp;
  }
  
  async command result_t HPLSSP.setSSCR1(uint32_t newVal){
    atomic{
      _SSCR1 = newVal;
    }
    return SUCCESS;
  }

  async command uint32_t HPLSSP.getSSCR1(){
    uint32_t temp;
    atomic{
      temp = _SSCR1;
    }
    return temp;
  }

  
  async command result_t HPLSSP.setSSPSP(uint32_t newVal){
    atomic{
      _SSPSP = newVal;
    }
    return SUCCESS;
  }
  
  async command uint32_t HPLSSP.getSSPSP(){
    uint32_t temp;
    atomic{
      temp = _SSPSP;
    }
    return temp;
  }
  
  async command result_t HPLSSP.setSSTO(uint32_t newVal){
    atomic{
      _SSTO = newVal;
    }
    return SUCCESS;
  }
  async command uint32_t HPLSSP.getSSTO(){
    uint32_t temp;
    atomic{
      temp = _SSCR1;
    }
    return temp;
  }

  async command result_t HPLSSP.setSSITR(uint32_t newVal){
    atomic{
      _SSITR = newVal;
    }
    return SUCCESS;
  }
  
  async command uint32_t HPLSSP.getSSITR(){
    uint32_t temp;
    atomic{
      temp = _SSITR;
    }
    return temp;
  }
  
  async command result_t HPLSSP.setSSSR(uint32_t newVal){
    atomic{
      _SSSR = newVal;
    }
    return SUCCESS;
  }
  
  async command uint32_t HPLSSP.getSSSR(){
    uint32_t temp;
    atomic{
      temp = _SSSR;
    }
    return temp;
  }
  
  async command result_t HPLSSP.setSSDR(uint32_t newVal){
    atomic{
      _SSDR = newVal;
    }
    return SUCCESS;
  }
  
  async command uint32_t HPLSSP.getSSDR(){
    uint32_t temp;
    atomic{
      temp = _SSDR;
    }
    return temp;
  }
          
}
