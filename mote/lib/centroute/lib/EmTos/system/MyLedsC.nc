configuration MyLedsC {
  provides interface Leds;
}

implementation {
  components 
#ifdef DISABLE_LEDS
  NoLeds;
#else
  LedsC;
#endif

#ifdef DISABLE_LEDS
  Leds = NoLeds;
#else
  Leds = LedsC;
#endif
}


