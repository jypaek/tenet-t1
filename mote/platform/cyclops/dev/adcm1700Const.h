////////////////////////////////////////////////////////////////////////////
// 
// AGILENT TECHNOLOGIES
//
// Contents:   Register definitions for the ADCM 1700. 
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu
//           Henry Uyeno henry_uyeno@agilent.com
//           Rick Baer rick_baer@agilent.com	
//          
//
////////////////////////////////////////////////////////////////////////////

#ifndef ADCM1700CONST_H
#define ADCM1700CONST_H

struct register_s
{
    uint16_t registerName;
    uint8_t block;
    uint8_t offset;
    uint8_t lenght;
}__attribute__((packed));

#define BLOCK_SWITCH_CODE 0x7f
#define TWO_BYTE_REGISTER 0x11
#define ONE_BYTE_REGISTER 0x22


enum {
    ADCM1700_CONTROL_ADDRESS=0x17,
    ADCM1700_EXPOSURE_ADDRESS,
    ADCM1700_FORMAT_ADDRESS,
    ADCM1700_PATCH_ADDRESS,
    ADCM1700_SNAP_ADDRESS,
    ADCM1700_RUN_ADDRESS,
    ADCM1700_VIDEO_ADDRESS,
    ADCM1700_WINDOWSIZE_ADDRESS,
    ADCM1700_STATISITICS_ADDRESS,
    ADCM1700_PATTERN_ADDRESS
};




//definition of camera regster index.
enum {
ADCM_REG_ID=0,       //ID of the device
ADCM_REG_CONTROL,
ADCM_REG_STATUS,
ADCM_REG_SIZE,      
ADCM_REG_SENSOR_WID_V,
ADCM_REG_SENSOR_HGT_V,
ADCM_REG_OUTPUT_WID_V,
ADCM_REG_OUTPUT_HGT_V,
ADCM_REG_SENSOR_WID_S,
ADCM_REG_SENSOR_HGT_S,
ADCM_REG_OUTPUT_WID_S,
ADCM_REG_OUTPUT_HGT_S,
ADCM_REG_OUTPUT_FORMAT,
ADCM_REG_OUTPUT_CTRL_V,
ADCM_REG_PROC_CTRL_V,
ADCM_REG_SZR_IN_WID_V,
ADCM_REG_SZR_IN_HGT_V,
ADCM_REG_SZR_OUT_WID_V,
ADCM_REG_SZR_OUT_HGT_V,
ADCM_REG_SZR_IN_WID_S,
ADCM_REG_SZR_IN_HGT_S,
ADCM_REG_SZR_OUT_WID_S,
ADCM_REG_SZR_OUT_HGT_S,
ADCM_REG_OUTPUT_CTRL_S,
ADCM_REG_PROC_CTRL_S,
ADCM_REG_PADR1,
ADCM_REG_PADR2,
ADCM_REG_PADR3,
ADCM_REG_PADR4,
ADCM_REG_PADR5,
ADCM_REG_PADR6,
ADCM_REG_FWROW,
ADCM_REG_FWCOL,
ADCM_REG_LWROW,
ADCM_REG_LWCOL,
ADCM_REG_SENSOR_CTRL,
ADCM_REG_DATA_GEN,
ADCM_REG_AF_CTRL1,
ADCM_REG_AF_CTRL2,
ADCM_REG_AE_TARGET,
ADCM_REG_EREC_PGA,
ADCM_REG_EROC_PGA,
ADCM_REG_OREC_PGA,
ADCM_REG_OROC_PGA,
ADCM_REG_APS_COEF_GRN1,
ADCM_REG_APS_COEF_RED,
ADCM_REG_APS_COEF_BLUE,
ADCM_REG_APS_COEF_GRN2,
ADCM_REG_RPT_V,
ADCM_REG_ROWEXP_L,
ADCM_REG_ROWEXP_H,
ADCM_REG_SROWEXP,
ADCM_REG_STATUS_FLAGS,
ADCM_REG_SUM_GRN1,
ADCM_REG_SUM_RED,
ADCM_REG_SUM_BLUE,
ADCM_REG_SUM_GRN2,
ADCM_REG_CPP_V,
ADCM_REG_HBLANK_V,
ADCM_REG_VBLANK_V,
ADCM_REG_CLK_PER,
ADCM_REG_AE2_ETIME_MIN,
ADCM_REG_AE2_ETIME_MAX,
ADCM_REG_AE_GAIN_MAX,

//NOTE: This is the size of enum. It is no a register in the imager space!
//**IMPORTANT** this should be always at the end of enum.
IMAGER_NUMBER_OF_REGISTERS 
};

/* definitions within register data */
#define ADCM_ID_1700                    0x0059  /* what should return when reading ADCM_REG_ID */
#define ADCM_ID_MASK                    0xF8    /* lowest three bits are revision # */
#define ADCM_STATUS_CONFIG_MASK         0x0004  /* Bit 2 = CONFIG */
#define ADCM_OUTPUT_CTRL_FRVCLK_MASK    0x0100  /* Bit 8 of OUTPUT_CTRL reg */
#define ADCM_OUTPUT_CTRL_FR_OUT_MASK    0x1000  /* Bit 12 of OUTPUT_CTRL reg */
#define ADCM_OUTPUT_CTRL_JUST_MASK      0x8000  /* Bit 15 of OUTPUT_CTRL reg */

/* Although the ADCM-1700 is capable of supporting different formats in video and still
   mode, one format is applied to both modes in Cyclops */   
#define ADCM_OUTPUT_FORMAT_RGB          0x0000  /* RGB (3 bytes per pixel) format */
#define ADCM_OUTPUT_FORMAT_YCbCr        0x0008  /* YCbCr Y1,U12,Y2,V12 (2 bytes per pixel) format */
// There be dragons!!! The ADCM-1700 Sizer is bypassed in RAW mode. The output size will equal
// the input size, regardless of the window settings!!!
#define ADCM_OUTPUT_FORMAT_RAW          0x000E  /* raw format (1 byte per pixel) format */
#define ADCM_OUTPUT_FORMAT_Y            0x000D  /* luminance format (1 byte per pixel) */

// Valid values for test pattern generator
#define ADCM_TEST_MODE_NONE    0x0000
#define ADCM_TEST_MODE_SOC     0x0003
#define ADCM_TEST_MODE_8PB     0x0004
#define ADCM_TEST_MODE_CKB     0x0005
#define ADCM_TEST_MODE_BAR     0x0007
#define ADCM_SIZE_VSIZE_QQVGA           0x0004
#define ADCM_SIZE_SSIZE_QQVGA           0x0400

#define ADCM_CONTROL_RUN_MASK           0x0001
#define ADCM_CONTROL_SNAP_MASK          0x0002
#define ADCM_CONTROL_CONFIG_MASK        0x0004  /* bit 2 in control register */

#define ADCM_SIZE_VSIZE_MASK            0x0007
#define ADCM_SIZE_SSIZE_MASK            0x0700
#define ADCM_SIZE_VSIZE_QQVGA           0x0004
#define ADCM_SIZE_SSIZE_QQVGA           0x0400
#define ADCM_PROC_CTRL_NOSIZER          0x0010  /* bit 4 of PROC_CTRL */

// auto function control
#define ADCM_AF_AE  0x0001
#define ADCM_AF_AWB 0x0002
#define ADCM_AF_ABL 0x0010

//register_param_t 
struct register_s register_param_list[] = {
    //  id,                  block,        offset,   length    
    { ADCM_REG_ID       ,    0x00,         0x00,     TWO_BYTE_REGISTER },
    { ADCM_REG_CONTROL  ,    0x00,         0x02,     TWO_BYTE_REGISTER },
    { ADCM_REG_STATUS   ,    0x00,         0x04,     TWO_BYTE_REGISTER },
    { ADCM_REG_SIZE     ,    0x00,         0x08,     TWO_BYTE_REGISTER },
    { ADCM_REG_SENSOR_WID_V, 0x00,         0x18,     TWO_BYTE_REGISTER },
    { ADCM_REG_SENSOR_HGT_V, 0x00,         0x1A,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_WID_V, 0x00,         0x1C,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_HGT_V, 0x00,         0x1E,     TWO_BYTE_REGISTER },
    { ADCM_REG_SENSOR_WID_S, 0x00,         0x20,     TWO_BYTE_REGISTER },
    { ADCM_REG_SENSOR_HGT_S, 0x00,         0x22,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_WID_S, 0x00,         0x24,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_HGT_S, 0x00,         0x26,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_FORMAT,0x00,         0x0A,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_CTRL_V,0x02,         0x10,     TWO_BYTE_REGISTER },
    { ADCM_REG_PROC_CTRL_V,  0x02,         0x12,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_IN_WID_V, 0x02,         0x00,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_IN_HGT_V, 0x02,         0x02,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_OUT_WID_V, 0x02,        0x04,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_OUT_HGT_V, 0x02,        0x06,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_IN_WID_S,  0x02,        0x20,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_IN_HGT_S,  0x02,        0x22,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_OUT_WID_S, 0x02,        0x24,     TWO_BYTE_REGISTER },
    { ADCM_REG_SZR_OUT_HGT_S, 0x02,        0x26,     TWO_BYTE_REGISTER },
    { ADCM_REG_OUTPUT_CTRL_S, 0x02,        0x30,     TWO_BYTE_REGISTER },
    { ADCM_REG_PROC_CTRL_S,   0x02,        0x32,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR1    ,    0x03,         0x06,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR2    ,    0x90,         0x08,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR3    ,    0x90,         0x20,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR4    ,    0x90,         0x60,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR5    ,    0x90,         0x6C,     TWO_BYTE_REGISTER },
    { ADCM_REG_PADR6    ,    0x90,         0x80,     TWO_BYTE_REGISTER },
    { ADCM_REG_FWROW    ,    0x10,         0x0A,     ONE_BYTE_REGISTER },
    { ADCM_REG_FWCOL    ,    0x10,         0x0B,     ONE_BYTE_REGISTER },
    { ADCM_REG_LWROW    ,    0x10,         0x0C,     ONE_BYTE_REGISTER },
    { ADCM_REG_LWCOL    ,    0x10,         0x0D,     ONE_BYTE_REGISTER },
    { ADCM_REG_SENSOR_CTRL,  0x10,         0x1C,     ONE_BYTE_REGISTER },
    { ADCM_REG_DATA_GEN,     0x20,         0x5E,     TWO_BYTE_REGISTER },
    { ADCM_REG_AF_CTRL1,     0x02,         0x40,     TWO_BYTE_REGISTER },
    { ADCM_REG_AF_CTRL2,     0x02,         0x42,     TWO_BYTE_REGISTER },
    { ADCM_REG_AE_TARGET,    0x02,         0x5E,     TWO_BYTE_REGISTER },
    { ADCM_REG_EREC_PGA,     0x10,         0x0F,     ONE_BYTE_REGISTER },
    { ADCM_REG_EROC_PGA,     0x10,         0x10,     ONE_BYTE_REGISTER },
    { ADCM_REG_OREC_PGA,     0x10,         0x11,     ONE_BYTE_REGISTER },
    { ADCM_REG_OROC_PGA,     0x10,         0x12,     ONE_BYTE_REGISTER },
    { ADCM_REG_APS_COEF_GRN1,  0x20,       0x62,     TWO_BYTE_REGISTER },
    { ADCM_REG_APS_COEF_RED,   0x20,       0x64,     TWO_BYTE_REGISTER },
    { ADCM_REG_APS_COEF_BLUE,  0x20,       0x66,     TWO_BYTE_REGISTER },
    { ADCM_REG_APS_COEF_GRN2,  0x20,       0x68,     TWO_BYTE_REGISTER },
    { ADCM_REG_RPT_V,        0x02,         0x14,     TWO_BYTE_REGISTER },
    { ADCM_REG_ROWEXP_L,     0x10,         0x13,     ONE_BYTE_REGISTER },
    { ADCM_REG_ROWEXP_H,     0x10,         0x14,     ONE_BYTE_REGISTER },
    { ADCM_REG_SROWEXP,      0x10,         0x15,     ONE_BYTE_REGISTER },
    { ADCM_REG_STATUS_FLAGS, 0x21,         0x02,     TWO_BYTE_REGISTER },
    { ADCM_REG_SUM_GRN1,     0x05,         0x18,     TWO_BYTE_REGISTER },
    { ADCM_REG_SUM_RED,      0x05,         0x1A,     TWO_BYTE_REGISTER },
    { ADCM_REG_SUM_BLUE,     0x05,         0x1C,     TWO_BYTE_REGISTER },
    { ADCM_REG_SUM_GRN2,     0x05,         0x1E,     TWO_BYTE_REGISTER },
    { ADCM_REG_CPP_V,        0x02,         0x08,     TWO_BYTE_REGISTER },
    { ADCM_REG_HBLANK_V,     0x02,         0x0A,     TWO_BYTE_REGISTER },
    { ADCM_REG_VBLANK_V,     0x02,         0x0C,     TWO_BYTE_REGISTER },
    { ADCM_REG_CLK_PER,      0x00,         0x06,     TWO_BYTE_REGISTER },
    { ADCM_REG_AE2_ETIME_MIN, 0x02,        0x58,     TWO_BYTE_REGISTER },
    { ADCM_REG_AE2_ETIME_MAX, 0x02,        0x5A,     TWO_BYTE_REGISTER },
    { ADCM_REG_AE_GAIN_MAX,   0x02,        0x54,     TWO_BYTE_REGISTER },
       
    // this must always go last
    { IMAGER_NUMBER_OF_REGISTERS  , 1, 1, 1},
};

struct register_s *lookup_register(uint16_t registerName)
{
    int i;
    for (i = 0; register_param_list[i].registerName != IMAGER_NUMBER_OF_REGISTERS ; i++)
        if (register_param_list[i].registerName == registerName)
            return &(register_param_list[i]);
    // not found!! 
    return NULL;
}

#define GET_REGISTER_BLOCK(myRegister) lookup_register(myRegister)->block
#define GET_REGISTER_OFFSET(myRegister) lookup_register(myRegister)->offset
#define GET_REGISTER_LENGHT(myRegister) lookup_register(myRegister)->lenght

// size limits for adcm1700:
#define ADCM_SIZE_MAX_X 352
#define ADCM_SIZE_MIN_X  24
#define ADCM_SIZE_MAX_Y 288
#define ADCM_SIZE_MIN_Y  24


#define SET_SIZE_USING_SIZER  // use sizer instead of low-level windowing
/* default image type and size information */
#define ADCM_SIZE_1700DEFAULT_W 352     /* columns */
#define ADCM_SIZE_1700DEFAULT_H 288     /* rows */
#define ADCM_SIZE_API_DEFAULT_W  64     /* columns */
#define ADCM_SIZE_API_DEFAULT_H  64     /* rows */
/* end default */
/* SIZE macro definitions (specific to to the 1700 imager */
#define FWROW_1700(row)  ( (((ADCM_SIZE_1700DEFAULT_H - (row))/2) + 4) /4 )
#define FWCOL_1700(col)  ( (((ADCM_SIZE_1700DEFAULT_W - (col))/2) + 4) /4 )
#define LWROW_1700(row)  ( (((ADCM_SIZE_1700DEFAULT_H - (row))/2) + (row) + 8) /4 )
#define LWCOL_1700(col)  ( (((ADCM_SIZE_1700DEFAULT_W - (col))/2) + (col) + 8) /4 )    

#endif

// 2 horizontal lines between frames (provides extra time to stop imager before next frame begins)
#define ADCM_VBLANK_DEFAULT  2
