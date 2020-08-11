configuration Main {
  uses interface StdControl;
}
implementation
{
  components RealMain, HPLInit, cpldC;

  StdControl = RealMain.StdControl;
  RealMain.hardwareInit -> HPLInit;
  RealMain.cpldControl -> cpldC.cpldControl;
}
