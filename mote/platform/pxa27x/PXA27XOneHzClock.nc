/**
   @author Robbie Adler
**/

interface PXA27XOneHzClock{



    /**
     command to init the One Hz clock event.  This command must only be called once
     @param none
  **/  
  
  command result_t init();

  /**
     command to enabled the One Hz clock event
     @param none
  **/  
  
  command result_t enable();

  /**
     command to disable the one Hz clock event
     @param none
  **/  
  
  command result_t disable();
  
  /**
     event that indicates that a one Hz timer event has occured
     @param none
  **/  
  async event void OneHzClockFired();
  
}
