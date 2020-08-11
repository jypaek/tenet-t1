
#ifndef _OBJECTDETECTION_M_H
#define _OBJECTDETECTION_M_H

#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <stddef.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif

void ObjectDetection_init();          
int ObjectDetection_detect(int performseg);
void ObjectDetection_resetBackground();
void ObjectDetection_setBackground();
int ObjectDetection_setImgRes(uint8_t sizex, uint8_t sizey, uint8_t imgtype);
void ObjectDetection_setRACoeff(uint8_t newRAcoeff);   
void ObjectDetection_setSkip(uint8_t newSkip);
void ObjectDetection_setIlluminationCoeff(double newIllCoeff);
void ObjectDetection_setRange(uint8_t newRange);
void ObjectDetection_setDetectThresh(uint8_t newThresh);
int ObjectDetection_getSegmentResult();

#endif

