
configuration DupCheckerC
{
    provides {
        interface StdControl;
        interface DupCheckerI;
    }
}


implementation {

    components
        DupCheckerM;

    StdControl = DupCheckerM.StdControl;

    DupCheckerI = DupCheckerM.DupCheckerI;
}
