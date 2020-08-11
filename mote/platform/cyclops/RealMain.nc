includes sched;

module RealMain {
  uses {
    command result_t hardwareInit();
    interface StdControl;
    interface StdControl as cpldControl;
  }
}
implementation
{
  int main() __attribute__ ((C, spontaneous)) {

      call hardwareInit();
      call cpldControl.init();
      call cpldControl.start();
      TOSH_CYCLOPS_RESET_DIRECT_MEMORY_ACCESS();
      TOSH_sched_init();
      
      call StdControl.init();
      call StdControl.start();
      __nesc_enable_interrupt();
      
      while(1) 
          {
              TOSH_run_task();
          }
  }
}
