
configuration FastSampleC {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Schedule;
        interface Memory;
        interface Leds;
    }
}
implementation {
  components FastSample
           , MemoryM
           , TimerC
#ifdef PLATFORM_TELOSB
           , MSP430DMAC
           , MSP430ADC12C
#endif
           , new AsyncToSyncQueue() as FSQ0
           , new AsyncToSyncQueue() as FSQ1
           , new AsyncToSyncQueue() as FSQ2
           ;

    StdControl = FastSample;
    Element = FastSample;
    TenetTask = FastSample;
    Schedule = FastSample;
    Memory = FastSample;
    Leds = FastSample;

    FastSample.Q0->FSQ0;
    FastSample.Q1->FSQ1;
    FastSample.Q2->FSQ2;
    FSQ0.Memory -> MemoryM;
    FSQ1.Memory -> MemoryM;
    FSQ2.Memory -> MemoryM;
    #ifdef PLATFORM_TELOSB
        FastSample.DMAControl -> MSP430DMAC;
        FastSample.DMA0 -> MSP430DMAC.MSP430DMA[unique("MSP430DMA")];
        FastSample.DMA1 -> MSP430DMAC.MSP430DMA[unique("MSP430DMA")];
        FastSample.DMA2 -> MSP430DMAC.MSP430DMA[unique("MSP430DMA")];
        FastSample.ADC -> MSP430ADC12C.MSP430ADC12MultipleChannel[unique("MSP430ADC12")];
        FastSample.ADCControl -> MSP430ADC12C;
    #else
        #ifdef PLATFORM_PC
            FastSample.Timer -> TimerC.Timer[unique("Timer")];
            StdControl = TimerC;
        #endif // PLATFORM_PC
    #endif // PLATFORM_TELOSB

}

