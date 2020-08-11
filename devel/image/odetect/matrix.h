
/*
 *Authors: 
 * Obi Iroezi: obimdina@seas.ucla.edu
 * Juan Carlos Garcia: yahualic@ucla.edu
 * Mohammad Rahimi: mhr@cens.ucla.edu
 *
 *
 *This document will define the necessary macro definitions for the matrix
  library support for matrix operations*/

#ifndef MATRIX_H
#define MATRIX_H

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

//****************************************************************************
//MATRIX
//****************************************************************************

//MATRIX-Depth
enum {CYCLOPS_1BIT=0,CYCLOPS_1BYTE=1,CYCLOPS_2BYTE=2, CYCLOPS_2BYTES=2,CYCLOPS_4BYTE=4};

//structure representation of a matrix
typedef struct{
    uint8_t depth;    //stores how many bytes are in each elemnt, CYCLOPS_XBYTE where X is the num of bytes in each element
    union
    {
        uint8_t* ptr8;    //for matrices of uint8 elements
        uint16_t* ptr16;
        uint32_t* ptr32;
    } data;
    uint16_t rows; //number of rows
    uint16_t cols; //number of columns
} CYCLOPS_Matrix;


#endif
