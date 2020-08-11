/**
 * Author 	Junaith Ahemed
 * Date		January 25, 2007
 */

includes UniqueSequenceID;
configuration UniqueSequenceIDC
{
  provides
  {
    interface StdControl;
    interface UniqueSequenceID;
  }
}

implementation
{
  components UniqueSequenceIDM, 
             FlashLoggerC as FSPtr,
             FormatStorageC as CreatePtr;

  StdControl = UniqueSequenceIDM;
  UniqueSequenceID = UniqueSequenceIDM;
  //Main.StdControl -> UniqueSequenceIDM;

  UniqueSequenceIDM.FCreate -> CreatePtr;
  UniqueSequenceIDM.FOpen -> FSPtr.FileMount [SEQID];
  UniqueSequenceIDM.FRead -> FSPtr.FileRead [SEQID];
  UniqueSequenceIDM.FWrite -> FSPtr.FileWrite [SEQID];
}
