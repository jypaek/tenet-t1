#ifndef __PROCESS_VIBRATION_H__
#define __PROCESS_VIBRATION_H__



#define PROCVIB_DONE_DEF 1
#define PROCVIB_MORE_DEF 2

enum
  {
    PROCVIB_DONE = PROCVIB_DONE_DEF,
    PROCVIB_MORE = PROCVIB_MORE_DEF
  };

typedef struct {
  // input parameters required for initialization
  unsigned short FftFlag;     // 1=>do FFT, 0=>time domain samples
  unsigned short GseFlag;     // 1=>do gSE, 0=>don't do gSE
  unsigned short DMAsize;     // size of each DMA transfer
  unsigned short Navg;	      // number of averages
  unsigned short WinFunc;     // 0=>rectangular, 1=>Hanning
  unsigned short dummy;
  unsigned long Fs;           // native sampling frequency of A/D
  unsigned long FsDesired;    // desired sampling rate
  unsigned long NumOutputPts; // FFT resolution (lines)
  unsigned long NumCaptPts;   // number of points captured @ FsDesired
                              // This parameter gives flexibility to 
                              // specify zero-padding
                              // For time-dom capts, should = NumOutputPts
  

  // parameters required for processing...these are filled in by initVibration
  unsigned long OverallAcc;   // accumulator for overall averaging
  unsigned short RtDecFactor; // realtime dec factor
  unsigned short pw;          // log2(Lfft)
  unsigned long Lfft;         // Length of FFT
  unsigned long NumRtCaptPts; // number of points captured after RT dec
  unsigned short NavgCmplt;   // number of averages completed
  short fftsh;		      // scaling factor, fftoutput * 2^(-fftsh)
  double ResampFactor;        // Fine resampling factor
  short fftidx[300];          // FFT bit-reverse indices
  
  // resampler states
  const short *Imp;           // Filter coefficients 
  const short *ImpD;          // ImpD[n] = Imp[n+1]-Imp[n] 
  unsigned short LpScl;       // Unity-gain scale factor 
  unsigned short Nwing;       // Filter table size 
  unsigned short Nmult;       // Filter length for up-conversions 
} vibStates_t;


int initVibration(vibStates_t *vibSt, short largeFilter) ;

int processVibFrame(short *x, vibStates_t *vs, long *specAvg, float *scale,
                    unsigned short *overall, unsigned short *NavgCmplt) ;


#endif
