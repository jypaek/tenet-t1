#ifndef __DOWNSAMPLE_H__
#define __DOWNSAMPLE_H__

typedef short downsampleTempBuffer_t __attribute__ ((aligned(8)));

typedef struct {
  short states88a[88];
  short states88b[88];
  short states168[168];
  downsampleTempBuffer_t *tempbuf;
} downsampleStates_t __attribute__ ((aligned(8)));

int downsampleInit(downsampleStates_t *downsampSt, downsampleTempBuffer_t *tempBuf);
int downsample(downsampleStates_t *downsampSt, short int *inbuf, long int Nsamp,
                short int *outbuf, short int K);

#endif
