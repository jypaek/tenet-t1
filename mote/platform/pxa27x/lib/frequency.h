#ifndef __FREQUENCY_H__
#define __FREQUENCY_H__

#include "inttypes.h"

uint32_t getSystemFrequency();
uint32_t getSystemBusFrequency();
void writeCLKCFG(uint32_t value);
uint32_t readCLKCFG();


#endif // __FREQUENCY_H__
