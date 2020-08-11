/**
 * Author 	Junaith Ahemed
 * Date		January 25, 2007
 */
#ifndef UNIQUE_SEQUENCE_ID
#define UNIQUE_SEQUENCE_ID

enum
{
  SEQID = unique("FlashLogger"),
};

  enum
  {
    NOFILE = 2,
    OERR = 3,
    WERR = 4,
    RERR = 5,
    SERR = 6,
  };

  #define FileNameSize 9
  /* Size of the SequenceID variable which is a uint32*/
  #define FieldSize 4

#endif
