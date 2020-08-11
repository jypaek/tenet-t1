
configuration StatsC
{
    provides {
        interface StdControl;
        interface StatsI;
    }
}


implementation {

    components

        StatsM;
        
    StdControl = StatsM.StdControl;
    StatsI = StatsM.StatsI;

}
