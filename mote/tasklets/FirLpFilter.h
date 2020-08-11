/*
* "Copyright (c) 2006~2008 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * FIR filter coefficients 
 * 
 * - four windowing types provided  --> selected at compile time
 * - two cut-off frequency provided --> selected at run time
 *   - 0.5 sampling rate, or
 *   - 0.2 sampling rate.
 * - all coefficients are scaled by 65536 (2^16).
 *
 * @modified Mar/8/2008
 *
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/


#ifndef FIR_FILTER_ORDER
#define FIR_FILTER_ORDER 32
#endif

enum {
#if (FIR_FILTER_ORDER == 32)
    FIR_ORDER = 32,
#else
    FIR_ORDER = 16,
#endif
    FIR_SIZE = FIR_ORDER + 1,
};


#if (FIR_FILTER_ORDER == 32)
    /* hamming window */
    const int32_t hamming5[FIR_SIZE] = {   0, -124, 0, 253, 0, -540, 0, 1045, 
                                           0, -1879, 0, 3324, 0, -6424, 0, 20706, 
                                           32814L, 20706, 0, -6424, 0, 3324, 0, -1879, 
                                           0, 1045, 0, -540, 0, 253, 0, -124, 0};

    const int32_t hamming2[FIR_SIZE] = {   -61, 0, 101, 240, 355, 317, 0, -613, 
                                           -1339, -1784, -1463, 0, 2651, 6098, 9568, 12148, 
                                           13101, 12148, 9568, 6098, 2651, 0, -1463, -1784, 
                                           -1339, -613, 0, 317, 355, 240, 101, 0, -61};
    /* gaussian window */
    const int32_t gaussian5[FIR_SIZE] = {  0, -105, 0, 231, 0, -473, 0, 916, 
                                           0, -1700, 0, 3134, 0, -6277, 0, 20643, 
                                           32800L, 20643, 0, -6277, 0, 3134, 0, -1700, 
                                           0, 916, 0, -473, 0, 231, 0, -105, 0};

    const int32_t gaussian2[FIR_SIZE] = {  -40, 0, 92, 219, 316, 277, 0, -537, 
                                           -1187, -1612, -1349, 0, 2546, 5952, 9455, 12096, 
                                           13080, 12096, 9455, 5952, 2546, 0, -1349, -1612, 
                                           -1187, -537, 0, 277, 316, 219, 92, 0, -40};
    /* chebyshev window */
    const int32_t chebyshev5[FIR_SIZE] = { 0, -3, 0, 28, 0, -124, 0, 405, 
                                           0, -1071, 0, 2503, 0, -5800, 0, 20447, 
                                           32768L, 20447, 0, -5800, 0, 2503, 0, -1071, 
                                           0, 405, 0, -124, 0, 28, 0, -3, 0};

    const int32_t chebyshev2[FIR_SIZE] = { 0, 0, 6, 26, 59, 73, 0, -238, 
                                           -640, -1019, -973, 0, 2217, 5518, 9158, 12024, 
                                           13113, 12024, 9158, 5518, 2217, 0, -973, -1019, 
                                           -640, -238, 0, 73, 59, 26, 6, 0, 0};
    /* kaiser window */
    const int32_t kaiser5[FIR_SIZE] = {    0, -1343, 0, 1570, 0, -1877, 0, 2317, 
                                           0, -3002, 0, 4226, 0, -7070, 0, 21252, 
                                           33390L, 21252, 0, -7070, 0, 4226, 0, -3002, 
                                           0, 2317, 0, -1877, 0, 1570, 0, -1343, 0};

    const int32_t kaiser2[FIR_SIZE] = {    -694, 0, 805, 1411, 1538, 1043, 0, -1287, 
                                           -2352, -2698, -1951, 0, 2941, 6354, 9543, 11804, 
                                           12621, 11804, 9543, 6354, 2941, 0, -1951, -2698, 
                                           -2352, -1287, 0, 1043, 1538, 1411, 805, 0, -694};
#else
    /* hamming window */
    const int32_t hamming5[FIR_SIZE] = {   0, -343, 0, 1521, 0, -4988, 0, 20165, 
                                           32825L, 20165, 0, -4988, 0, 1521, 0, -343, 0}; 

    const int32_t hamming2[FIR_SIZE] = {   -201, -330, -444, 0, 1674, 4790, 8682, 11968, 
                                           13257, 11968, 8682, 4790, 1674, 0, -444, -330, -201};
    /* gaussian window */
    const int32_t gaussian5[FIR_SIZE] = {  0, -359, 0, 1418, 0, -4720, 0, 20015, 
                                           32829L, 20015, 0, -4720, 0, 1418, 0, -359, 0}; 

    const int32_t gaussian2[FIR_SIZE] = {  -161, -352, -445, 0, 1585, 4628, 8617, 12127, 
                                           13537, 12127, 8617, 4628, 1585, 0, -445, -352, -161};
    /* chebyshev window */
    const int32_t chebyshev5[FIR_SIZE] = { 0, -45, 0, 615, 0, -3622, 0, 19436, 
                                           32768L, 19436, 0, -3622, 0, 615, 0, -45, 0}; 

    const int32_t chebyshev2[FIR_SIZE] = { -6, -48, -126, 0, 1034, 3807, 8240, 12625, 
                                           14484, 12625, 8240, 3807, 1034, 0, -126, -48, -6}; 
    /* kaiser window */
    const int32_t kaiser5[FIR_SIZE] = {    0, -2952, 0, 4230, 0, -7158, 0, 21638, 
                                           34021L, 21638, 0, -7158, 0, 4230, 0, -2952, 0}; 

    const int32_t kaiser2[FIR_SIZE] = {    -2445, -2835, -2070, 0, 3166, 6875, 10362, 12845, 
                                           13743, 12845, 10362, 6875, 3166, 0, -2070, -2835, -2445};
#endif


#ifndef FIR_FILTER_TYPE
#define FIR_FILTER_TYPE 3       // default
#endif

#if (FIR_FILTER_TYPE == 1)     // HAMMING
    const int32_t *filter_coeff_5 = hamming5;
    const int32_t *filter_coeff_2 = hamming2;
#elif (FIR_FILTER_TYPE == 2)   // GAUSSIAN
    const int32_t *filter_coeff_5 = gaussian5;
    const int32_t *filter_coeff_2 = gaussian2;
#elif (FIR_FILTER_TYPE == 3)   // CHEBYSHEV
    const int32_t *filter_coeff_5 = chebyshev5;
    const int32_t *filter_coeff_2 = chebyshev2;
#else  //#if (FIR_FILTER_TYPE == 4)   //KAISER
    const int32_t *filter_coeff_5 = kaiser5;
    const int32_t *filter_coeff_2 = kaiser2;
#endif

