includes RnpLink;
includes Joiner;

configuration JoinerC
{
    provides {
        interface StdControl;
        interface JoinerI;
        interface JoinPayloadI[uint8_t id];
    }
}


implementation {

    components
        JoinerM,
        CentTreeC,
        RandomLFSR,
        StatsC,
        BeaconerC;
//        Beaconer_RnpC as BeaconerC;

    StdControl = JoinerM.StdControl;
    StdControl = BeaconerC;

    JoinerI = JoinerM.JoinerI;
    JoinPayloadI = JoinerM.JoinPayloadI;


    JoinerM.JoinBeacon -> BeaconerC.BeaconerI[unique("BeaconerI")];
    JoinerM.CentTreeCtrlI -> CentTreeC;
    JoinerM.Random -> RandomLFSR;
    JoinerM.StatsI -> StatsC;

}
