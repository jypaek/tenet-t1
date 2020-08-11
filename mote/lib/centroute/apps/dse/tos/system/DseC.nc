#ifdef SYMPATHY_DSE
includes Sympathy;
#endif

configuration DseC
{
  provides {
    interface QeAcceptQueryI;
    interface ChAcceptCmdI;
  }
}
implementation
{
  components 
    Main,
    QueryEngineM,
    QueryTableM,
    DataMapM,
    TransformManagerM,
    ConfigurationM,
#ifdef NOISE_WINDOW
    TimerC,
#endif
    MyLedsC as LedsC,

#ifdef SYMPATHY_DSE
    SReturnStateM,
#endif

#ifdef NODE_HEALTH
    NodeHealthC,
#endif
    dspSamplerC as dseSamplerC;

  QeAcceptQueryI = QueryEngineM;
  ChAcceptCmdI = ConfigurationM;

  QueryEngineM.ChAcceptCmdI -> ConfigurationM;
#ifdef NOISE_WINDOW
  QueryEngineM.Timer -> TimerC.Timer[unique("Timer")];
#endif

  Main.StdControl -> QueryTableM.StdControl;
  Main.StdControl -> TransformManagerM.StdControl;
  Main.StdControl -> DataMapM.DataMapControl;
  Main.StdControl -> ConfigurationM.ConfigControl;

  ConfigurationM.DataMapControl -> DataMapM.DataMapControl;
  ConfigurationM.DmUpdateTableI -> DataMapM.DmUpdateTableI;
  ConfigurationM.ADCReset -> dseSamplerC.ADCReset;

  QueryEngineM.QueryTableI -> QueryTableM.QueryTableI;
  QueryEngineM.DmAcceptMnAndTI -> DataMapM.DmAcceptMnAndTI;
  QueryEngineM.Leds -> LedsC;
#ifdef SYMPATHY_DSE
  QueryEngineM.ProvideCompMetrics -> SReturnStateM.ProvideCompMetrics[SCOMP_STATS4];
#endif

  DataMapM.SamplerControl -> dseSamplerC.SamplerControl;
  DataMapM.SampleRequest -> dseSamplerC.SampleRequest;

  dseSamplerC.SampleReply <- TransformManagerM.SampleReply;
  TransformManagerM.DmMappingI -> DataMapM.DmMappingI;
  TransformManagerM.QeAcceptDataI -> QueryEngineM.QeAcceptDataI;

#ifdef NODE_HEALTH
   Main.StdControl -> NodeHealthC.StdControl;
  QueryEngineM.NodeHealthI -> NodeHealthC.NodeHealthI;
#endif

}
