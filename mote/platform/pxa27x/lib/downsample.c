// This is the implementation for the decimation algorithm by factors 
// 2 to 256, in powers of 2.

#include "wmmx.h"
#include "downsample.h"
#include "coef.inc"
#include <string.h>

#define WMMX_ENABLE 1

//downsampleTempBuffer_t *tempbuf;
extern void firdecim_s(short int factor_M, long int H_size, short int* p_H,
		       short int* p_Z, long int num_inp, short int *p_inp, 
		       short int *p_out, short int sc);


int downsampleInit(downsampleStates_t *st, downsampleTempBuffer_t *tempBuf){
  int i;
#if WMMX_ENABLE
  startWMMX();
#endif
  for (i=0; i<88; i++) {
    st->states88a[i]=0;
    st->states88b[i]=0;
  }
  for (i=0; i<168; i++) {
    st->states168[i]=0;
  }
  st->tempbuf = tempBuf;
  return 1;
}

// FUNCTION:    firdecim
// DECRIPTION:  Decimates an input sequence by factor_M, using anti-aliasing
//              filter specified by pointer p_H.
// PARAMS:
//  FIR decimation filter
//  factor_M:    decimation factor
//  H_size:      length of FIR filter
//  p_H:         pointer to FIR filter
//  p_Z:         pointer to tap delay line
//  num_inp:     number of input data points (assume multiple of factor_M)
//  p_inp:       pointer to input data buffer
//  p_out:       pointer to output data buffer
//  sc:          scaling factor
//
// Jonathan Huang
// 5/17/05
#ifndef WMMX_ENABLE
void firdecim(short int factor_M, long int H_size, short int* p_H,
           short int* p_Z, long int num_inp, short int *p_inp, 
           short int *p_out, short int sc)
{
    int tap, num_out, sh;
    //    long int sum;
    long long sum;

    /* this implementation assuems num_inp is a multiple of factor_M */
    //assert(num_inp % factor_M == 0);
    sh = sc+7;
    num_out = 0;
    //printf("number of input samples:  %d\n",num_inp);
    while (num_inp >= factor_M) {
        /* shift Z delay line up to make room for next samples */
        for (tap = H_size - 1; tap >= factor_M; tap--) {
            p_Z[tap] = p_Z[tap - factor_M];
        }

        /* copy next samples from input buffer to bottom of Z delay line */
        for (tap = factor_M - 1; tap >= 0; tap--) {
            p_Z[tap] = *p_inp++;
        }
        num_inp -= factor_M;

        /* calculate FIR sum */
        sum = 0;
        for (tap = 0; tap < H_size; tap++) {
	  //sum += (p_H[tap] * p_Z[tap])>>sh;
	  sum += (p_H[tap] * p_Z[tap]);
        }
	//        *p_out++ = (short int)(sum >> 9);     /* store sum and point to next output */
        *p_out++ = (short int)(sum >> (sc+16));     /* store sum and point to next output */
        num_out++;
    }

    //*p_num_out = num_out;   /* pass number of outputs back to caller */

}
#endif



// FUNCTION:    downsample
// DESCRIPTION:
//   Decimates a sequence of samples by a factor K.  This implementation
//   assumes 16-bit filter coefficients, so the maximum stopband attenuation
//   is -80 dB.  The passband has ripple of no more than 0.01 dB, and starts
//   to roll off at 0.4 * final sampling rate.
// PARAMS:      
//   DownsampStates *d  := filter states of decimation filters
//   short int *inbuf   := pointer to input buffer  : must be aligned on an 8 byte boundary 
//   long int Nsamp     := number of input samples  : must be a power of and  an integer multiple of K
//   short int *outbuf  := pointer to output buffer : no restriction on alignment
//                         (output length is Nsamp/K)
//   short int K        := decimation factor (from 2 to 256, powers of 2 only)
// RETURN VALUES:
//   -1 := error, number of input samples not divisible by K
//   -2 := error, value of K invalid
//   1  := decimation successful
// 
// Jonathan Huang
// 5/17/05
int downsample(downsampleStates_t *d, short int *inbuf, long int Nsamp,
                short int *outbuf, short int K) {
  int status;
  status = 1;
    if ((Nsamp%K) != 0) status = -1;
    switch(K) {
    case 1:
      memcpy(outbuf,inbuf,2*Nsamp);
      break;
#ifdef WMMX_ENABLE
    case 2:
      firdecim_s(2,LEN2X88,h2x88,d->states88a,Nsamp,inbuf,
		 outbuf,SC2X88);
      break;
    case 4:
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp,inbuf,
		 outbuf,SC4X168);
      break;
    case 8:
      firdecim_s(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC4X56);
      firdecim_s(2,LEN2X88,h2x88,d->states88b,Nsamp/4,d->tempbuf,
		 outbuf,SC2X88);
      break;
    case 16:
      firdecim_s(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC4X56);
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp/4,d->tempbuf,
		 outbuf,SC4X168);
      break;
    case 32:
      firdecim_s(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC8X88);
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp/8,d->tempbuf,
		 outbuf,SC4X168);
      break;
    case 64:
      firdecim_s(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC4X56);
      firdecim_s(4,LEN4X56,h4x56,d->states88b,Nsamp/4,d->tempbuf,
		 inbuf,SC4X56);
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp/16,inbuf,
		 outbuf,SC4X168);
      break;
    case 128:
      firdecim_s(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC8X88);
      firdecim_s(4,LEN4X56,h4x56,d->states88b,Nsamp/8,d->tempbuf,
		 inbuf,SC4X56);
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp/32,inbuf,
		 outbuf,SC4X168);
      break;
    case 256:
      firdecim_s(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
		 d->tempbuf,SC8X88);
      firdecim_s(8,LEN8X88,h8x88,d->states88b,Nsamp/8,d->tempbuf,
		 inbuf,SC8X88);
      firdecim_s(4,LEN4X168,h4x168,d->states168,Nsamp/64,inbuf,
		 outbuf,SC4X168);
      break;
#else
    case 2:
      firdecim(2,LEN2X88,h2x88,d->states88a,Nsamp,inbuf,
	       outbuf,SC2X88);
      break;
    case 4:
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp,inbuf,
	       outbuf,SC4X168);
      break;
    case 8:
      firdecim(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC4X56);
      firdecim(2,LEN2X88,h2x88,d->states88b,Nsamp/4,d->tempbuf,
	       outbuf,SC2X88);
      break;
    case 16:
      firdecim(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC4X56);
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp/4,d->tempbuf,
	       outbuf,SC4X168);
      break;
    case 32:
      firdecim(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC8X88);
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp/8,d->tempbuf,
	       outbuf,SC4X168);
      break;
    case 64:
      firdecim(4,LEN4X56,h4x56,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC4X56);
      firdecim(4,LEN4X56,h4x56,d->states88b,Nsamp/4,d->tempbuf,
	       inbuf,SC4X56);
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp/16,inbuf,
	       outbuf,SC4X168);
      break;
    case 128:
      firdecim(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC8X88);
      firdecim(4,LEN4X56,h4x56,d->states88b,Nsamp/8,d->tempbuf,
	       inbuf,SC4X56);
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp/32,inbuf,
	       outbuf,SC4X168);
      break;
    case 256:
      firdecim(8,LEN8X88,h8x88,d->states88a,Nsamp,inbuf,
	       d->tempbuf,SC8X88);
      firdecim(8,LEN8X88,h8x88,d->states88b,Nsamp/8,d->tempbuf,
	       inbuf,SC8X88);
      firdecim(4,LEN4X168,h4x168,d->states168,Nsamp/64,inbuf,
	       outbuf,SC4X168);
      break;
#endif
    default:
      status = -2;
    }
    return status;
}

