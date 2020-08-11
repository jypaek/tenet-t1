#ifndef __PROFILE_H__
#define __PROFILE_H__

typedef struct{
unsigned long IC_access, IC_miss, DC_access, DC_miss, cycles;
} profileInfo_t;

typedef enum{
  profilePrintAll =0,
    profilePrintCycles
    
    } profilePrintInfo_t;


//startProfile
//pass in a pointer to a profileInfo_t structure that you desire to contain
//the profile information.  This function will effectively init the structure
void startProfile() __attribute__ ((always_inline));

//stopProfile
//pass in a pointer to a profileInfo_t structure that you desire to contain
//the profile information.  This function will fill in the structure
void stopProfile() __attribute__ ((always_inline));

void printProfile(profilePrintInfo_t printmask);

#endif
