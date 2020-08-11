configuration TestSampler {

}
implementation {
  components Main, TestSamplerM, LedsC, TimerC, SamplerC;

  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> TestSamplerM.StdControl;
  
  TestSamplerM.Timer -> TimerC.Timer[unique("Timer")];
  TestSamplerM.Leds -> LedsC;
  TestSamplerM.Sample -> SamplerC;
  TestSamplerM.SamplerControl -> SamplerC;
}
