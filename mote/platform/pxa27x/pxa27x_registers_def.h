/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2006 Intel Corporation 
 *  All rights reserved. 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 * 
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _PXA27X_REGISTERS_DEF_H
#define _PXA27X_REGISTERS_DEF_H

/*
 * Macros
 */

#define _PXAREG(address) (*((volatile uint32_t *)(address)))
					
/*
 * Register and bit defintion
 * TODO : Take out syntax comment
 * Format syntax for single bit fields
 * #define	REGNAME_BITFIELD	(1<<BitPosition)
 * Format syntax for multi-bit fields that define a variable 
 *   (e.g. 6 bit channel field, LSB starting at bit 5, reg PCMD, bit field TR)
 * #define	PCMD_TR(channel)	((channel & 0x3F) << 5)
 * #define	PCMD_TR_MASK		(~(((1<<6)-1) << 5)) 
 */

/*
 * Power Manager 
 * TODO: Mark
 */
#define	PMCR	_PXAREG(0x40F00000)
#define	PSSR	_PXAREG(0x40F00004)
#define	PSPR	_PXAREG(0x40F00008)
#define	PWER	_PXAREG(0x40F0000C)
#define	PRER	_PXAREG(0x40F00010)
#define	PFER	_PXAREG(0x40F00014)
#define	PEDR	_PXAREG(0x40F00018)
#define	PCFR	_PXAREG(0x40F0001C)
#define	PGSR0	_PXAREG(0x40F00020)
#define	PGSR1	_PXAREG(0x40F00024)
#define	PGSR2	_PXAREG(0x40F00028)
#define	PGSR3	_PXAREG(0x40F0002C)
#define	RCSR	_PXAREG(0x40F00030)
#define	PSLR	_PXAREG(0x40F00034)
#define	PSTR	_PXAREG(0x40F00038)
#define	PVCR	_PXAREG(0x40F00040)
#define	PUCR	_PXAREG(0x40F0004C)
#define	PKWR	_PXAREG(0x40F00050)
#define	PKSR	_PXAREG(0x40F00054)
#define	CCCR	_PXAREG(0x41300000)
#define	CKEN	_PXAREG(0x41300004)
#define	OSCC	_PXAREG(0x41300008)
#define	CCSR	_PXAREG(0x4130000C)

#define	PCMR_BIDAE	(1)
#define	PCMR_BIDAS	(1<<1)
#define	PCMR_VIDAE	(1<<2)
#define	PCMR_VIDAS	(1<<3)
#define	PCMR_IAS	(1<<4)
#define	PCMR_INTRS	(1<<5)

#define	PSSR_SSS	(1)
#define	PSSR_BFS	(1<<1)
#define	PSSR_VFS	(1<<2)
#define	PSSR_STS	(1<<3)
#define PSSR_PH		(1<<4)
#define PSSR_RDH	(1<<5)
#define PSSR_OTGPH	(1<<6)

/* TODO: PSPR */

#define	PWER_WE0	(1)
#define	PWER_WE1	(1<<1)
#define	PWER_WE3	(1<<3)
#define	PWER_WE4	(1<<4)
#define	PWER_WE9	(1<<9)
#define	PWER_WE10	(1<<10)
#define	PWER_WE11	(1<<11)
#define	PWER_WE12	(1<<12)
#define	PWER_WE13	(1<<13)
#define	PWER_WE14	(1<<14)
#define	PWER_WE15	(1<<15)
#define	PWER_WEMUX2(n)		((n & 0x7) << 16)
#define	PWER_WEMUX2_MASK	(~(((1<<3)-1) << 16)) 
#define	PWER_WEMUX3(n)		((n & 0x3) << 19)
#define	PWER_WEMUX3_MASK	(~(((1<<2)-1) << 19)) 
#define	PWER_WEUSIM	(1<<23)
#define	PWER_WE35	(1<<24)
#define	PWER_WBB	(1<<25)
#define	PWER_WEUSBC	(1<<26)
#define	PWER_WEUSBH1	(1<<27)
#define	PWER_WEUSBH2	(1<<28)
#define	PWER_WEP1	(1<<30)
#define	PWER_WERTC	(1<<31)
		
#define	PRER_RE0	(1)
#define	PRER_RE1	(1<<1)
#define	PRER_RE3	(1<<3)
#define	PRER_RE4	(1<<4)
#define	PRER_RE9	(1<<9)
#define	PRER_RE10	(1<<10)
#define	PRER_RE11	(1<<11)
#define	PRER_RE12	(1<<12)
#define	PRER_RE13	(1<<13)
#define	PRER_RE14	(1<<14)
#define	PRER_RE15	(1<<15)
#define	PRER_RE35	(1<<24)

#define	PFER_FE0	(1)
#define	PFER_FE1	(1<<1)
#define	PFER_FE3	(1<<3)
#define	PFER_FE4	(1<<4)
#define	PFER_FE9	(1<<9)
#define	PFER_FE10	(1<<10)
#define	PFER_FE11	(1<<11)
#define	PFER_FE12	(1<<12)
#define	PFER_FE13	(1<<13)
#define	PFER_FE14	(1<<14)
#define	PFER_FE15	(1<<15)
#define	PFER_FE35	(1<<24)

#define	PEDR_ED0	(1)
#define	PEDR_ED1	(1<<1)
#define	PEDR_ED3	(1<<3)
#define	PEDR_ED4	(1<<4)
#define	PEDR_ED9	(1<<9)
#define	PEDR_ED10	(1<<10)
#define	PEDR_ED11	(1<<11)
#define	PEDR_ED12	(1<<12)
#define	PEDR_ED13	(1<<13)
#define	PEDR_ED14	(1<<14)
#define	PEDR_ED15	(1<<15)
#define	PEDR_EDMUX2	(1<<17)
#define	PEDR_EDMUX3	(1<<20)
#define	PEDR_ED35	(1<<24)
#define	PEDR_EDBB	(1<<25)
#define	PEDR_EDUSBC	(1<<26)
#define	PEDR_EDUSBH1	(1<<27)
#define	PEDR_EDUSBH2	(1<<28)
#define	PEDR_EDP1	(1<<30)
#define	PEDR_EDRTC	(1<<31)

#define	PCFR_OPDE	(1)
#define	PCFR_FP		(1<<1)
#define	PCFR_FS		(1<<2)
#define	PCFR_GPR_EN	(1<<4)
#define	PCFR_PI2C_EN	(1<<6)
#define	PCFR_DC_EN	(1<<7)
#define	PCFR_FVC	(1<<10)
#define	PCFR_L1_EN	(1<<11)
#define	PCFR_GPROD	(1<<12)
#define	PCFR_PO		(1<<14)
#define	PCFR_RO		(1<<15)

/* TODO: PGSR0/1/2/3 */

#define	RCSR_HWR	(1)
#define	RCSR_WDR	(1<<1)
#define	RCSR_SMR	(1<<2)
#define	RCSR_GPR	(1<<3)

#define	PSLR_SL_PI(n)	((n & 0x3) << 2)
#define	PSLR_SL_PI_MASK	(~(((1<<2)-1) << 2)) 
#define	PSLR_SL_R0	(1<<8)
#define	PSLR_SL_R1	(1<<9)
#define	PSLR_SL_R2	(1<<10)
#define	PSLR_SL_R3	(1<<11)
#define	PSLR_SL_ROD	(1<<20)
#define	PSLR_IVF	(1<<22)
#define	PSLR_PSSD	(1<<23)
#define	PSLR_PWR_DEL(n)		((n & 0xF) << 24)
#define	PSLR_PWR_DEL_MASK	(~(((1<<4)-1) << 24)) 
#define	PSLR_SYS_DEL(n)		((n & 0xF) << 28)
#define	PSLR_SYS_DEL_MASK	(~(((1<<4)-1) << 28)) 

#define	PSTR_ST_PI(n)	((n & 0x3) << 2)
#define	PSTR_ST_PI_MASK	(~(((1<<2)-1) << 2)) 
#define	PSTR_ST_R0	(1<<8)
#define	PSTR_ST_R1	(1<<9)
#define	PSTR_ST_R2	(1<<10)
#define	PSTR_ST_R3	(1<<11)

#define	PVCR_Slave_Address(n)	(n & 0x7F)
#define	PVCR_Slave_Address_MASK	(~(((1<<7)-1)) 
#define	PVCR_Command_Delay(n)	((n & 0x1F) << 7)
#define	PVCR_Command_Delay_MASK	(~(((1<<5)-1) << 7)) 
#define	PSTR_VCSA	(1<<14)
#define	PVCR_Read_Pointer(n)	((n & 0x1F) << 20)
#define	PVCR_Read_Pointer_MASK	(~(((1<<5)-1) << 20)) 

#define	PUCR_EN_UDENT	(1)
#define	PUCR_USIM114	(1<<2)
#define	PUCR_USIM115	(1<<3)
#define	PUCR_UDETS	(1<<5)

#define	PKWR_WE13	(1)
#define	PKWR_WE16	(1<<1)
#define	PKWR_WE17	(1<<2)
#define	PKWR_WE34	(1<<3)
#define	PKWR_WE36	(1<<4)
#define	PKWR_WE37	(1<<5)
#define	PKWR_WE38	(1<<6)
#define	PKWR_WE39	(1<<7)
#define	PKWR_WE90	(1<<8)
#define	PKWR_WE91	(1<<9)
#define	PKWR_WE93	(1<<10)
#define	PKWR_WE94	(1<<11)
#define	PKWR_WE95	(1<<12)
#define	PKWR_WE96	(1<<13)
#define	PKWR_WE97	(1<<14)
#define	PKWR_WE98	(1<<15)
#define	PKWR_WE99	(1<<16)
#define	PKWR_WE100	(1<<17)
#define	PKWR_WE101	(1<<18)
#define	PKWR_WE102	(1<<19)

#define	PKSR_ED13	(1)
#define	PKSR_ED16	(1<<1)
#define	PKSR_ED17	(1<<2)
#define	PKSR_ED34	(1<<3)
#define	PKSR_ED36	(1<<4)
#define	PKSR_ED37	(1<<5)
#define	PKSR_ED38	(1<<6)
#define	PKSR_ED39	(1<<7)
#define	PKSR_ED90	(1<<8)
#define	PKSR_ED91	(1<<9)
#define	PKSR_ED93	(1<<10)
#define	PKSR_ED94	(1<<11)
#define	PKSR_ED95	(1<<12)
#define	PKSR_ED96	(1<<13)
#define	PKSR_ED97	(1<<14)
#define	PKSR_ED98	(1<<15)
#define	PKSR_ED99	(1<<16)
#define	PKSR_ED100	(1<<17)
#define	PKSR_ED101	(1<<18)
#define	PKSR_ED102	(1<<19)

#define	PCMDx_Command_Data(n)	(n & 0xFF)
#define	PCMDx_Command_Data_MASK	(~(((1<<8)-1)) 
#define	PCMDx_SQC(n)	((n & 0x3) << 8)
#define	PCMDx_SQC_MASK	(~(((1<<2)-1) << 8)) 
#define	PCMDx_LC	(1<<10)
#define	PCMDx_DCE	(1<<11)
#define	PCMDx_MBC	(1<<12)

#define	CCCR_L(n)	(n & 0x1F)
#define	CCCR_L_MASK	(~(((1<<1)-1)) 
#define	CCCR_2N(n)	((n & 0xF) << 7)
#define	CCCR_2N_MASK	(~(((1<<4)-1) << 7)) 
#define	CCCR_A	(1<<25)
#define	CCCR_PLL_EARLY_EN	(1<<26)
#define	CCCR_LCD_26	(1<<27)
#define	CCCR_PPDIS	(1<<30)
#define	CCCR_CPDIS	(1<<31)

#define CLKCFG_T        (1)
#define CLKCFG_F        (1<<1)
#define CLKCFG_HT       (1<<2)
#define CLKCFG_B        (1<<3)

#define	CKEN_CKEN0	(1)
#define	CKEN_CKEN1	(1<<1)
#define	CKEN_CKEN2	(1<<2)
#define	CKEN_CKEN3	(1<<3)
#define	CKEN_CKEN4	(1<<4)
#define	CKEN_CKEN5	(1<<5)
#define	CKEN_CKEN6	(1<<6)
#define	CKEN_CKEN7	(1<<7)
#define	CKEN_CKEN8	(1<<8)
#define	CKEN_CKEN9	(1<<9)
#define	CKEN_CKEN10	(1<<10)
#define	CKEN_CKEN11	(1<<11)
#define	CKEN_CKEN12	(1<<12)
#define	CKEN_CKEN13	(1<<13)
#define	CKEN_CKEN14	(1<<14)
#define	CKEN_CKEN15	(1<<15)
#define	CKEN_CKEN16	(1<<16)
#define	CKEN_CKEN17	(1<<17)
#define	CKEN_CKEN18	(1<<18)
#define	CKEN_CKEN19	(1<<19)
#define	CKEN_CKEN20	(1<<20)
#define	CKEN_CKEN21	(1<<21)
#define	CKEN_CKEN22	(1<<22)
#define	CKEN_CKEN23	(1<<23)
#define	CKEN_CKEN24	(1<<24)
#define	CKEN_CKEN31	(1<<31)

#define	OSCC_OOK	(1)
#define	OSCC_OON	(1<<1)
#define	OSCC_TOUT_EN	(1<<2)
#define	OSCC_PIO_EN	(1<<3)
#define	OSCC_CRI	(1<<4)
#define	OSCC_OSD(n)	((n & 0x3) << 5)
#define	OSCC_OSD_MASK	(~(((1<<2)-1) << 5)) 

#define	CCSR_L_S(n)	(n & 0xF)
#define	CCSR_L_S_MASK	(~(((1<<4)-1))) 
#define	CCSR_2N_S(n)	((n & 0x7) << 7)
#define	CCSR_2N_S_MASK	(~(((1<<3)-1) << 7)) 
#define	CCSR_PPLCK	(1<<28)
#define	CCSR_CPLCK	(1<<29)
#define	CCSR_PPDIS_S	(1<<30)
#define	CCSR_CPDIS_S	(1<<31)

/*
 * DMA
 * TODO : Robbie
 */
#define	DCSR0	_PXAREG(0x40000000)
#define	DCSR1	_PXAREG(0x40000004)
#define	DCSR2	_PXAREG(0x40000008)
#define	DCSR3	_PXAREG(0x4000000C)
#define	DCSR4	_PXAREG(0x40000010)
#define	DCSR5	_PXAREG(0x40000014)
#define	DCSR6	_PXAREG(0x40000018)
#define	DCSR7	_PXAREG(0x4000001C)
#define	DCSR8	_PXAREG(0x40000020)
#define	DCSR9	_PXAREG(0x40000024)
#define	DCSR10	_PXAREG(0x40000028)
#define	DCSR11	_PXAREG(0x4000002C)
#define	DCSR12	_PXAREG(0x40000030)
#define	DCSR13	_PXAREG(0x40000034)
#define	DCSR14	_PXAREG(0x40000038)
#define	DCSR15	_PXAREG(0x4000003C)
#define	DCSR16	_PXAREG(0x40000040)
#define	DCSR17	_PXAREG(0x40000044)
#define	DCSR18	_PXAREG(0x40000048)
#define	DCSR19	_PXAREG(0x4000004C)
#define	DCSR20	_PXAREG(0x40000050)
#define	DCSR21	_PXAREG(0x40000054)
#define	DCSR22	_PXAREG(0x40000058)
#define	DCSR23	_PXAREG(0x4000005C)
#define	DCSR24	_PXAREG(0x40000060)
#define	DCSR25	_PXAREG(0x40000064)
#define	DCSR26	_PXAREG(0x40000068)
#define	DCSR27	_PXAREG(0x4000006C)
#define	DCSR28	_PXAREG(0x40000070)
#define	DCSR29	_PXAREG(0x40000074)
#define	DCSR30	_PXAREG(0x40000078)
#define	DCSR31	_PXAREG(0x4000007C)
#define	DALGN	_PXAREG(0x400000A0)
#define	DPCSR	_PXAREG(0x400000A4)
#define	DRQSR0	_PXAREG(0x400000E0)
#define	DRQSR1	_PXAREG(0x400000E4)
#define	DRQSR2	_PXAREG(0x400000E8)
#define	DINT	_PXAREG(0x400000F0)
#define	DRCMR0	_PXAREG(0x40000100)
#define	DRCMR1	_PXAREG(0x40000104)
#define	DRCMR2	_PXAREG(0x40000108)
#define	DRCMR3	_PXAREG(0x4000010C)
#define	DRCMR4	_PXAREG(0x40000110)
#define	DRCMR5	_PXAREG(0x40000114)
#define	DRCMR6	_PXAREG(0x40000118)
#define	DRCMR7	_PXAREG(0x4000011C)
#define	DRCMR8	_PXAREG(0x40000120)
#define	DRCMR9	_PXAREG(0x40000124)
#define	DRCMR10	_PXAREG(0x40000128)
#define	DRCMR11	_PXAREG(0x4000012C)
#define	DRCMR12	_PXAREG(0x40000130)
#define	DRCMR13	_PXAREG(0x40000134)
#define	DRCMR14	_PXAREG(0x40000138)
#define	DRCMR15	_PXAREG(0x4000013C)
#define	DRCMR16	_PXAREG(0x40000140)
#define	DRCMR17	_PXAREG(0x40000144)
#define	DRCMR18	_PXAREG(0x40000148)
#define	DRCMR19	_PXAREG(0x4000014C)
#define	DRCMR20	_PXAREG(0x40000150)
#define	DRCMR21	_PXAREG(0x40000154)
#define	DRCMR22	_PXAREG(0x40000158)
#define	DRCMR24	_PXAREG(0x40000160)
#define	DRCMR25	_PXAREG(0x40000164)
#define	DRCMR26	_PXAREG(0x40000168)
#define	DRCMR27	_PXAREG(0x4000016C)
#define	DRCMR28	_PXAREG(0x40000170)
#define	DRCMR29	_PXAREG(0x40000174)
#define	DRCMR30	_PXAREG(0x40000178)
#define	DRCMR31	_PXAREG(0x4000017C)
#define	DRCMR32	_PXAREG(0x40000180)
#define	DRCMR33	_PXAREG(0x40000184)
#define	DRCMR34	_PXAREG(0x40000188)
#define	DRCMR35	_PXAREG(0x4000018C)
#define	DRCMR36	_PXAREG(0x40000190)
#define	DRCMR37	_PXAREG(0x40000194)
#define	DRCMR38	_PXAREG(0x40000198)
#define	DRCMR39	_PXAREG(0x4000019C)
#define	DRCMR40	_PXAREG(0x400001A0)
#define	DRCMR41	_PXAREG(0x400001A4)
#define	DRCMR42	_PXAREG(0x400001A8)
#define	DRCMR43	_PXAREG(0x400001AC)
#define	DRCMR44	_PXAREG(0x400001B0)
#define	DRCMR45	_PXAREG(0x400001B4)
#define	DRCMR46	_PXAREG(0x400001B8)
#define	DRCMR47	_PXAREG(0x400001BC)
#define	DRCMR48	_PXAREG(0x400001C0)
#define	DRCMR49	_PXAREG(0x400001C4)
#define	DRCMR50	_PXAREG(0x400001C8)
#define	DRCMR51	_PXAREG(0x400001CC)
#define	DRCMR52	_PXAREG(0x400001D0)
#define	DRCMR53	_PXAREG(0x400001D4)
#define	DRCMR54	_PXAREG(0x400001D8)
#define	DRCMR55	_PXAREG(0x400001DC)
#define	DRCMR56	_PXAREG(0x400001E0)
#define	DRCMR57	_PXAREG(0x400001E4)
#define	DRCMR58	_PXAREG(0x400001E8)
#define	DRCMR59	_PXAREG(0x400001EC)
#define	DRCMR60	_PXAREG(0x400001F0)
#define	DRCMR61	_PXAREG(0x400001F4)
#define	DRCMR62	_PXAREG(0x400001F8)
#define	DRCMR63	_PXAREG(0x400001FC)
#define	DDADR0	_PXAREG(0x40000200)
#define	DSADR0	_PXAREG(0x40000204)
#define	DTADR0	_PXAREG(0x40000208)
#define	DCMD0	_PXAREG(0x4000020C)
#define	DDADR1	_PXAREG(0x40000210)
#define	DSADR1	_PXAREG(0x40000214)
#define	DTADR1	_PXAREG(0x40000218)
#define	DCMD1	_PXAREG(0x4000021C)
#define	DDADR2	_PXAREG(0x40000220)
#define	DSADR2	_PXAREG(0x40000224)
#define	DTADR2	_PXAREG(0x40000228)
#define	DCMD2	_PXAREG(0x4000022C)
#define	DDADR3	_PXAREG(0x40000230)
#define	DSADR3	_PXAREG(0x40000234)
#define	DTADR3	_PXAREG(0x40000238)
#define	DCMD3	_PXAREG(0x4000023C)
#define	DDADR4	_PXAREG(0x40000240)
#define	DSADR4	_PXAREG(0x40000244)
#define	DTADR4	_PXAREG(0x40000248)
#define	DCMD4	_PXAREG(0x4000024C)
#define	DDADR5	_PXAREG(0x40000250)
#define	DSADR5	_PXAREG(0x40000254)
#define	DTADR5	_PXAREG(0x40000258)
#define	DCMD5	_PXAREG(0x4000025C)
#define	DDADR6	_PXAREG(0x40000260)
#define	DSADR6	_PXAREG(0x40000264)
#define	DTADR6	_PXAREG(0x40000268)
#define	DCMD6	_PXAREG(0x4000026C)
#define	DDADR7	_PXAREG(0x40000270)
#define	DSADR7	_PXAREG(0x40000274)
#define	DTADR7	_PXAREG(0x40000278)
#define	DCMD7	_PXAREG(0x4000027C)
#define	DDADR8	_PXAREG(0x40000280)
#define	DSADR8	_PXAREG(0x40000284)
#define	DTADR8	_PXAREG(0x40000288)
#define	DCMD8	_PXAREG(0x4000028C)
#define	DDADR9	_PXAREG(0x40000290)
#define	DSADR9	_PXAREG(0x40000294)
#define	DTADR9	_PXAREG(0x40000298)
#define	DCMD9	_PXAREG(0x4000029C)
#define	DDADR10	_PXAREG(0x400002A0)
#define	DSADR10	_PXAREG(0x400002A4)
#define	DTADR10	_PXAREG(0x400002A8)
#define	DCMD10	_PXAREG(0x400002AC)
#define	DDADR11	_PXAREG(0x400002B0)
#define	DSADR11	_PXAREG(0x400002B4)
#define	DTADR11	_PXAREG(0x400002B8)
#define	DCMD11	_PXAREG(0x400002BC)
#define	DDADR12	_PXAREG(0x400002C0)
#define	DSADR12	_PXAREG(0x400002C4)
#define	DTADR12	_PXAREG(0x400002C8)
#define	DCMD12	_PXAREG(0x400002CC)
#define	DDADR13	_PXAREG(0x400002D0)
#define	DSADR13	_PXAREG(0x400002D4)
#define	DTADR13	_PXAREG(0x400002D8)
#define	DCMD13	_PXAREG(0x400002DC)
#define	DDADR14	_PXAREG(0x400002E0)
#define	DSADR14	_PXAREG(0x400002E4)
#define	DTADR14	_PXAREG(0x400002E8)
#define	DCMD14	_PXAREG(0x400002EC)
#define	DDADR15	_PXAREG(0x400002F0)
#define	DSADR15	_PXAREG(0x400002F4)
#define	DTADR15	_PXAREG(0x400002F8)
#define	DCMD15	_PXAREG(0x400002FC)
#define	DDADR16	_PXAREG(0x40000300)
#define	DSADR16	_PXAREG(0x40000304)
#define	DTADR16	_PXAREG(0x40000308)
#define	DCMD16	_PXAREG(0x4000030C)
#define	DDADR17	_PXAREG(0x40000310)
#define	DSADR17	_PXAREG(0x40000314)
#define	DTADR17	_PXAREG(0x40000318)
#define	DCMD17	_PXAREG(0x4000031C)
#define	DDADR18	_PXAREG(0x40000320)
#define	DSADR18	_PXAREG(0x40000324)
#define	DTADR18	_PXAREG(0x40000328)
#define	DCMD18	_PXAREG(0x4000032C)
#define	DDADR19	_PXAREG(0x40000330)
#define	DSADR19	_PXAREG(0x40000334)
#define	DTADR19	_PXAREG(0x40000338)
#define	DCMD19	_PXAREG(0x4000033C)
#define	DDADR20	_PXAREG(0x40000340)
#define	DSADR20	_PXAREG(0x40000344)
#define	DTADR20	_PXAREG(0x40000348)
#define	DCMD20	_PXAREG(0x4000034C)
#define	DDADR21	_PXAREG(0x40000350)
#define	DSADR21	_PXAREG(0x40000354)
#define	DTADR21	_PXAREG(0x40000358)
#define	DCMD21	_PXAREG(0x4000035C)
#define	DDADR22	_PXAREG(0x40000360)
#define	DSADR22	_PXAREG(0x40000364)
#define	DTADR22	_PXAREG(0x40000368)
#define	DCMD22	_PXAREG(0x4000036C)
#define	DDADR23	_PXAREG(0x40000370)
#define	DSADR23	_PXAREG(0x40000374)
#define	DTADR23	_PXAREG(0x40000378)
#define	DCMD23	_PXAREG(0x4000037C)
#define	DDADR24	_PXAREG(0x40000380)
#define	DSADR24	_PXAREG(0x40000384)
#define	DTADR24	_PXAREG(0x40000388)
#define	DCMD24	_PXAREG(0x4000038C)
#define	DDADR25	_PXAREG(0x40000390)
#define	DSADR25	_PXAREG(0x40000394)
#define	DTADR25	_PXAREG(0x40000398)
#define	DCMD25	_PXAREG(0x4000039C)
#define	DDADR26	_PXAREG(0x400003A0)
#define	DSADR26	_PXAREG(0x400003A4)
#define	DTADR26	_PXAREG(0x400003A8)
#define	DCMD26	_PXAREG(0x400003AC)
#define	DDADR27	_PXAREG(0x400003B0)
#define	DSADR27	_PXAREG(0x400003B4)
#define	DTADR27	_PXAREG(0x400003B8)
#define	DCMD27	_PXAREG(0x400003BC)
#define	DDADR28	_PXAREG(0x400003C0)
#define	DSADR28	_PXAREG(0x400003C4)
#define	DTADR28	_PXAREG(0x400003C8)
#define	DCMD28	_PXAREG(0x400003CC)
#define	DDADR29	_PXAREG(0x400003D0)
#define	DSADR29	_PXAREG(0x400003D4)
#define	DTADR29	_PXAREG(0x400003D8)
#define	DCMD29	_PXAREG(0x400003DC)
#define	DDADR30	_PXAREG(0x400003E0)
#define	DSADR30	_PXAREG(0x400003E4)
#define	DTADR30	_PXAREG(0x400003E8)
#define	DCMD30	_PXAREG(0x400003EC)
#define	DDADR31	_PXAREG(0x400003F0)
#define	DSADR31	_PXAREG(0x400003F4)
#define	DTADR31	_PXAREG(0x400003F8)
#define	DCMD31	_PXAREG(0x400003FC)
#define	DRCMR64	_PXAREG(0x40001100)
#define	DRCMR65	_PXAREG(0x40001104)
#define	DRCMR66	_PXAREG(0x40001108)
#define	DRCMR67	_PXAREG(0x4000110C)
#define	DRCMR68	_PXAREG(0x40001110)
#define	DRCMR69	_PXAREG(0x40001114)
#define	DRCMR70	_PXAREG(0x40001118)
#define	DRCMR74	_PXAREG(0x40001128)
#define	FLYCNFG	_PXAREG(0x48000020)

/***********
*MACROS for DMA
************/
#define DCSR_BASE  (0x40000000)
#define DRCMR_BASE (0x40000100)
#define DDADR_BASE (0x40000200)
#define DSADR_BASE (0x40000204)
#define DTADR_BASE (0x40000208)
#define DCMD_BASE  (0x4000020C)

#define DMASTATUS_REG_OFFSET(n)  ((n)*4)
#define DCSR(n)   _PXAREG(DCSR_BASE + DMASTATUS_REG_OFFSET(n))

#define DMAREQUESTCHANNEL_REG_OFFSET(n)  ( ((n)<64) ? ((n)*4) : (((n)*4) + 3840))
#define DRCMR(n)  _PXAREG(DRCMR_BASE +DMAREQUESTCHANNEL_REG_OFFSET(n))

#define DMACHANNEL_REG_OFFSET(n) ((n)*16)
#define DDADR(n)   _PXAREG(DDADR_BASE + DMACHANNEL_REG_OFFSET((n)))
#define DSADR(n)   _PXAREG(DSADR_BASE + DMACHANNEL_REG_OFFSET((n)))
#define DTADR(n)   _PXAREG(DTADR_BASE + DMACHANNEL_REG_OFFSET((n)))
#define DCMD(n)    _PXAREG(DCMD_BASE + DMACHANNEL_REG_OFFSET((n)))

/******************************
 * DRCRM<0-31> bit definitions
 *****************************/
#define DRCMR_MAPVLD (1<<7)
#define DRCMR_CHLNUM(channel) ((channel) & 0x1F)

/******************************
 * DDADR<0-31> bit definitions
 *****************************/
#define DDADR_BREN (1<<1)
#define DDADR_STOP (1)

/******************************
 * DCMD<0-31> bit definitions
 *****************************/
#define DCMD_INCSRCADDR    (1<<31)
#define DCMD_INCTRGADDR    (1<<30)
#define DCMD_FLOWSRC       (1<<29)
#define DCMD_FLOWTRG       (1<<28)
#define DCMD_CMPEN         (1<<25)
#define DCMD_ADDRMODE      (1<<23)
#define DCMD_STARTIRQEN    (1<<22)
#define DCMD_ENDIRQEN      (1<<21)
#define DCMD_FLYBYS        (1<<20)
#define DCMD_FLYBYT        (1<<19)
#define DCMD_SIZE(size)    (((size) & 0x3)<<16)
#define DCMD_MAXSIZE       DCMD_SIZE(3)
#define DCMD_WIDTH(width)  (((width) & 0x3)<<14)
#define DCMD_MAXWIDTH      DCMD_WIDTH(3)
#define DCMD_LEN(len)      (((len) & 0x1FFF))
#define DCMD_MAXLEN        DCMD_LEN(0x1FFF)
/******************************
 * FLYCNFG bit definitions
 *****************************/
#define FLYCNFG_FBPOL1     (1<<16)
#define FLYCNFG_FBPOL0     (1)

/******************************
 * DRQSR<0-2> bit definitions
 *****************************/
#define DRQSR_CLR           (1<<8)
#define DRQSR_REQPEND(val)  (((val) & 0x1F))

/******************************
 * DCSR<0-31> bit definitions
 *****************************/
#define DCSR_RUN            (1<<31)
#define DCSR_NODESCFETCH    (1<<30)
#define DCSR_STOPIRQEN      (1<<29)
#define DCSR_EORIRQEN       (1<<28)
#define DCSR_EORJMPEN       (1<<27)
#define DCSR_EORSTOPEN      (1<<26)
#define DCSR_SETCMPST       (1<<25)
#define DCSR_CLRCMPST       (1<<24)
#define DCSR_RASIRQEN       (1<<23)
#define DCSR_MASKRUN        (1<<22)
#define DCSR_CMPST          (1<<10)
#define DCSR_EORINT         (1<<9)
#define DCSR_REQPEND        (1<<8)
#define DCSR_RASINTR        (1<<4)
#define DCSR_STOPINTR       (1<<3)
#define DCSR_ENDINTR        (1<<2)
#define DCSR_STARTINTR      (1<<1)
#define DCSR_BUSERRINTR     (1)

/******************************
 * DINT bit definitions
 *****************************/
//#define DINT(num)  (1<<(num))

/******************************
 * DALGN bit definitions
 *****************************/
#define DALGN_DALGN(num)   (1<<(num))

/******************************
 * DPCSR bit definitions
 *****************************/
#define DPCSR_BRGSPLIT      (1<<31)
#define DPCSR_BRGBUSY       (1)
/*
 * Memory Controller
 * TODO : Robbie
 */
#define MDCNFG	_PXAREG(0x48000000)
#define MDREFR	_PXAREG(0x48000004)
#define MSC0	_PXAREG(0x48000008)
#define MSC1	_PXAREG(0x4800000C)
#define MSC2	_PXAREG(0x48000010)
#define MECR	_PXAREG(0x48000014)
#define SXCNFG	_PXAREG(0x4800001C)
#define MCMEM0	_PXAREG(0x48000028)
#define MCMEM1	_PXAREG(0x4800002C)
#define MCATT0	_PXAREG(0x48000030)
#define MCATT1	_PXAREG(0x48000034)
#define MCIO0	_PXAREG(0x48000038)
#define MCIO1	_PXAREG(0x4800003C)
#define MDMRS	_PXAREG(0x48000040)
#define BOOT_DEF	_PXAREG(0x48000044)
#define ARB_CNTL	_PXAREG(0x48000048)
#define BSCNTR0	_PXAREG(0x4800004C)
#define BSCNTR1	_PXAREG(0x48000050)
#define LCDBSCNTR	_PXAREG(0x48000054)
#define MDMRSLP	_PXAREG(0x48000058)
#define BSCNTR2	_PXAREG(0x4800005C)
#define BSCNTR3	_PXAREG(0x48000060)
#define SA1110	_PXAREG(0x48000064)


#define MDCNFG_MDENX	(1<<31)
#define MDCNFG_DCACX2	(1<<30)
#define MDCNFG_DSA1110_2	(1<<28)
#define MDCNFG_SETALWAYS	(1<<27)
#define MDCNFG_DADDR2	(1<<26)
#define MDCNFG_DTC2(n)	(((n) & 0x3) <<24)
#define MDCNFG_DNB2	(1<<23)
#define MDCNFG_DRAC2(n)	(((n) & 0x3) <<21)
#define MDCNFG_DCAC2(n)	(((n) & 0x3) <<19)
#define MDCNFG_DWID2	(1<<18)
#define MDCNFG_DE3	(1<<17)
#define MDCNFG_DE2	(1<<16)
#define MDCNFG_STACK1	(1<<15)
#define MDCNFG_DCACX0	(1<<14)
#define MDCNFG_STACK0	(1<<13)
#define MDCNFG_DSA1110_	(1<<12)
#define MDCNFG_DADDR0	(1<<10)
#define MDCNFG_DTC0(n)  (((n) & 0x3) <<8)
#define MDCNFG_DNB0	(1<<7)
#define MDCNFG_DRAC0(n)	(((n) & 0x3) <<5)
#define MDCNFG_DCAC0(n)	(((n) & 0x3) <<3)
#define MDCNFG_DWID0	(1<<2)
#define MDCNFG_DE1	(1<<1)
#define MDCNFG_DE0	(1)


#define SA1110_SXSTACK(n)   (((n) & 0x3) <<12)


/*
 * SSP
 * TODO : Rahul
 */
#define	SSCR0_1	_PXAREG(0x41000000)
#define	SSCR1_1	_PXAREG(0x41000004)
#define	SSSR_1	_PXAREG(0x41000008)
#define	SSITR_1	_PXAREG(0x4100000C)
#define	SSDR_1	_PXAREG(0x41000010)
#define	SSTO_1	_PXAREG(0x41000028)
#define	SSPSP_1	_PXAREG(0x4100002C)
#define	SSTSA_1	_PXAREG(0x41000030)
#define	SSRSA_1	_PXAREG(0x41000034)
#define	SSTSS_1	_PXAREG(0x41000038)
#define	SSACD_1	_PXAREG(0x4100003C)
#define	SSCR0_2	_PXAREG(0x41700000)
#define	SSCR1_2	_PXAREG(0x41700004)
#define	SSSR_2	_PXAREG(0x41700008)
#define	SSITR_2	_PXAREG(0x4170000C)
#define	SSDR_2	_PXAREG(0x41700010)
#define	SSTO_2	_PXAREG(0x41700028)
#define	SSPSP_2	_PXAREG(0x4170002C)
#define	SSTSA_2	_PXAREG(0x41700030)
#define	SSRSA_2	_PXAREG(0x41700034)
#define	SSTSS_2	_PXAREG(0x41700038)
#define	SSACD_2	_PXAREG(0x4170003C)
#define	SSCR0_3	_PXAREG(0x41900000)
#define	SSCR1_3	_PXAREG(0x41900004)
#define	SSSR_3	_PXAREG(0x41900008)
#define	SSITR_3	_PXAREG(0x4190000C)
#define	SSDR_3	_PXAREG(0x41900010)
#define	SSTO_3	_PXAREG(0x41900028)
#define	SSPSP_3	_PXAREG(0x4190002C)
#define	SSTSA_3	_PXAREG(0x41900030)
#define	SSRSA_3	_PXAREG(0x41900034)
#define	SSTSS_3	_PXAREG(0x41900038)
#define	SSACD_3	_PXAREG(0x4190003C)

/* SSP Control registers */
#define SSCR0_DSS(n) 		((n & 0xF) << 0)
#define SSCR0_DSS_MASK 		(~(((1<<4)-1) << 0))
#define SSCR0_FRF(n) 		((n & 0x3) << 4)
#define SSCR0_FRF_MASK 		(~(((1<<2)-1) << 4))
#define SSCR0_ECS 		(1 << 6)
#define SSCR0_SSE 		(1 << 7)
#define SSCR0_SCR(n) 		((n & 0xFFF) << 8)
#define SSCR0_SCR_MASK 		(~(((1<<12)-1) << 8))
#define SSCR0_EDSS 		(1 << 20)
#define SSCR0_NCS 		(1 << 21) 
#define SSCR0_RIM 		(1 << 22) 
#define SSCR0_TIM 		(1 << 23)
#define SSCR0_FRDC(n) 		((n & 0x7) << 24)
#define SSCR0_FRDC_MASK 	(~(((1<<3)-1) << 24))
#define SSCR0_ACS 		(1 << 30) 
#define SSCR0_MOD 		(1 << 31)

#define SSCR1_RIE 		(1 << 0)
#define SSCR1_TIE 		(1 << 1)
#define SSCR1_LBM 		(1 << 2)
#define SSCR1_SPO 		(1 << 3)
#define SSCR1_SPH 		(1 << 4)
#define SSCR1_MWDS 		(1 << 5)
#define SSCR1_TFT(n) 		((n & 0xF) << 6)
#define SSCR1_TFT_MASK 		(~(((1<<4)-1) << 6))
#define SSCR1_RFT(n) 		((n & 0xF) << 10)
#define SSCR1_RFT_MASK 		(~(((1<<4)-1) << 10))
#define SSCR1_EFWR 		(1 << 14)
#define SSCR1_STRF 		(1 << 15)
#define SSCR1_IFS 		(1 << 16)
#define SSCR1_PINTE 		(1 << 18)
#define SSCR1_TINTE 		(1 << 19)
#define SSCR1_RSRE 		(1 << 20)
#define SSCR1_TSRE 		(1 << 21)
#define SSCR1_TRAIL 		(1 << 22)
#define SSCR1_RWOT 		(1 << 23)
#define SSCR1_SFRMDIR 		(1 << 24)
#define SSCR1_SCLKDIR 		(1 << 25)
#define SSCR1_ECRB 		(1 << 26)
#define SSCR1_ECRA 		(1 << 27)
#define SSCR1_SCFR 		(1 << 28)
#define SSCR1_EBCEI 		(1 << 29)
#define SSCR1_TTE 		(1 << 30)
#define SSCR1_TTELP 		(1 << 31)

/* SSP Status Registers */
#define SSSR_TNF 		(1 << 2)
#define SSSR_RNE 		(1 << 3)
#define SSSR_BSY 		(1 << 4)
#define SSSR_TFS 		(1 << 5)
#define SSSR_RFS 		(1 << 6)
#define SSSR_ROR 		(1 << 7)
#define SSSR_TFL(n) 		((n & 0xF) << 8)
#define SSSR_TFL_MASK 		(~(((1<<4)-1) << 8))
#define SSSR_RFL(n) 		((n & 0xF) << 12)
#define SSSR_RFL_MASK 		(~(((1<<4)-1) << 12))
#define SSSR_PINT 		(1 << 18)
#define SSSR_TINT 		(1 << 19)
#define SSSR_EOC 		(1 << 20)
#define SSSR_TUR 		(1 << 21)
#define SSSR_CSS 		(1 << 22)
#define SSSR_BCE 		(1 << 23)

/* SSP Interrupt Test Registers */
#define SSITR_TTFS (1 << 5)
#define SSITR_TRFS (1 << 6)
#define SSITR_TROR (1 << 7)

/* SSP Timeout Registers */
#define SSTO_TIMEOUT(n) 	((n & 0xFFFFFF) << 0)
#define SSTO_TIMEOUT_MASK 	(~(((1<<24)-1) << 0))

/* SSP Programmable Serial Protocol Registers */
#define SSPSP_SCMODE(n) 	((n & 0x3) << 0)
#define SSPSP_SCMODE_MASK 	(~(((1<<3)-1) << 0))
#define SSPSP_SFRMP 		(1 << 2)
#define SSPSP_ETDS 		(1 << 3)
#define SSPSP_STRTDLY(n) 	((n & 0x7) << 4)
#define SSPSP_STRTDLY_MASK 	(~(((1<<3)-1) << 4))
#define SSPSP_DMYSTRT(n) 	((n & 0x3) << 7)
#define SSPSP_DMYSTRT_MASK 	(~(((1<<2)-1) << 7))
#define SSPSP_SFRMDLY(n) 	((n & 0x7F) << 9)
#define SSPSP_SFRMDLY_MASK 	(~(((1<<7)-1) << 9))
#define SSPSP_SFRMWDTH(n) 	((n & 0x3F) << 16)
#define SSPSP_SFRMWDTH_MASK 	(~(((1<<6)-1) << 16))
#define SSPSP_DMYSTOP(n) 	((n & 0x3) << 23)
#define SSPSP_DMYSTOP_MASK 	(~(((1<<2)-1) << 23))
#define SSPSP_FSRT 		(1 << 25)

/* SSP Audio Clock Divider Registers */
#define SSACD_ACDS(n) 		((n & 0x7) << 0)
#define SSACD_ACDS_MASK 	(~(((1<<3)-1) << 0))
#define SSACD_SCDB 		(1 << 3)
#define SSACD_ACPS(n) 		((n & 0x7) << 4)
#define SSACD_ACPS_MASK 	(~(((1<<3)-1) << 4))

/*
 * I2C
 * TODO : Junaith
 */
#define	IBMR	_PXAREG(0x40301680)
#define	IDBR	_PXAREG(0x40301688)
#define	ICR	_PXAREG(0x40301690)
#define	ISR	_PXAREG(0x40301698)
#define	ISAR	_PXAREG(0x403016A0)
#define	PIBMR	_PXAREG(0x40F00180)
#define	PIDBR	_PXAREG(0x40F00188)
#define	PICR	_PXAREG(0x40F00190)
#define	PISR	_PXAREG(0x40F00198)
#define	PISAR	_PXAREG(0x40F001A0)

/*I2C Bus Monitor Register*/
#define IBMR_SDA  (1 << 0) 
#define IBMR_SCL  (1 << 1) 

/*I2C control Register. Used to control the I2C unit*/
#define ICR_START  (1 << 0) 
#define ICR_STOP   (1 << 1) 
#define ICR_ACKNAK (1 << 2) 
#define ICR_TB     (1 << 3) 
#define ICR_MA     (1 << 4) 
#define ICR_SCLE   (1 << 5) 
#define ICR_IUE    (1 << 6) 
#define ICR_GCD    (1 << 7) 
#define ICR_ITEIE  (1 << 8) 
#define ICR_DRFIE  (1 << 9) 
#define ICR_BEIE   (1 << 10) 
#define ICR_SSDIE  (1 << 11) 
#define ICR_ALDIE  (1 << 12) 
#define ICR_SADIE  (1 << 13) 
#define ICR_UR     (1 << 14) 
#define ICR_FM     (1 << 15) 

/*The ISR signals I2C interrupts to the PXA27x processor interrupt controller.*/
#define ISR_RWM    (1 << 0) 
#define ISR_ACKNAK (1 << 1) 
#define ISR_UB     (1 << 2) 
#define ISR_IBB    (1 << 3) 
#define ISR_SSD    (1 << 4) 
#define ISR_ALD    (1 << 5) 
#define ISR_ITE    (1 << 6) 
#define ISR_IRF    (1 << 7) 
#define ISR_GCAD   (1 << 8) 
#define ISR_SAD    (1 << 9) 
#define ISR_BED    (1 << 10) 

/*
 * FFUART
 */
#define	FFRBR	_PXAREG(0x40100000)
#define	FFTHR	_PXAREG(0x40100000)
#define	FFDLL	_PXAREG(0x40100000)
#define	FFIER	_PXAREG(0x40100004)
#define	FFDLH	_PXAREG(0x40100004)
#define	FFIIR	_PXAREG(0x40100008)
#define	FFFCR	_PXAREG(0x40100008)
#define	FFLCR	_PXAREG(0x4010000C)
#define	FFMCR	_PXAREG(0x40100010)
#define	FFLSR	_PXAREG(0x40100014)
#define	FFMSR	_PXAREG(0x40100018)
#define	FFSPR	_PXAREG(0x4010001C)
#define	FFISR	_PXAREG(0x40100020)
#define	FFFOR	_PXAREG(0x40100024)
#define	FFABR	_PXAREG(0x40100028)
#define	FFACR	_PXAREG(0x4010002C)

/*
 * BTUART
 * TODO: Mark
 */
#define	BTRBR	_PXAREG(0x40200000)
#define	BTTHR	_PXAREG(0x40200000)
#define	BTDLL	_PXAREG(0x40200000)
#define	BTIER	_PXAREG(0x40200004)
#define	BTDLH	_PXAREG(0x40200004)
#define	BTIIR	_PXAREG(0x40200008)
#define	BTFCR	_PXAREG(0x40200008)
#define	BTLCR	_PXAREG(0x4020000C)
#define	BTMCR	_PXAREG(0x40200010)
#define	BTLSR	_PXAREG(0x40200014)
#define	BTMSR	_PXAREG(0x40200018)
#define	BTSPR	_PXAREG(0x4020001C)
#define	BTISR	_PXAREG(0x40200020)
#define	BTFOR	_PXAREG(0x40200024)
#define	BTABR	_PXAREG(0x40200028)
#define	BTACR	_PXAREG(0x4020002C)

/*
 * STUART 
 * TODO: Rahul
 */
#define	STRBR	_PXAREG(0x40700000)
#define	STTHR	_PXAREG(0x40700000)
#define	STDLL	_PXAREG(0x40700000)
#define	STIER	_PXAREG(0x40700004)
#define	STDLH	_PXAREG(0x40700004)
#define	STIIR	_PXAREG(0x40700008)
#define	STFCR	_PXAREG(0x40700008)
#define	STLCR	_PXAREG(0x4070000C)
#define	STMCR	_PXAREG(0x40700010)
#define	STLSR	_PXAREG(0x40700014)
#define	STMSR	_PXAREG(0x40700018)
#define	STSPR	_PXAREG(0x4070001C)
#define	STISR	_PXAREG(0x40700020)
#define	STFOR	_PXAREG(0x40700024)
#define	STABR	_PXAREG(0x40700028)
#define	STACR	_PXAREG(0x4070002C)

/*
 * Common UART bit definitions
 */

/******************************
 * UART DLL bit definitions
 *****************************/
#define	DLL_DLL(n)		((n) & 0xFF)
#define	DLL_DLL_MASK		(~(((1<<8)-1)) 

/******************************
 * UART DLH bit definitions
 *****************************/
#define	DLH_DLH(n)		((n) & 0xFF)
#define	DLH_DLH_MASK		(~(((1<<8)-1)) 

/******************************
 * UART IER bit definitions
 *****************************/
#define	IER_DMAE	(1<<7)
#define	IER_UUE	        (1<<6)
#define	IER_NRZE	(1<<5)
#define	IER_RTOIE	(1<<4)
#define	IER_MIE	        (1<<3)
#define	IER_RLSE	(1<<2)
#define	IER_TIE	        (1<<1)
#define	IER_RAVIE	(1)

/******************************
 * UART IIR bit definitions
 *****************************/
#define	IIR_FIFOES(n)	(((n) & 0x3) << 6)
#define	IIR_FIFOES_MASK	(~(((1<<2)-1) << 6)) 
#define	IER_EOC	        (1<<5)
#define	IER_ABL	        (1<<4)
#define	IER_TOD	        (1<<3)
#define	IIR_IID(n)	(((n) & 0x3) << 1)
#define	IIR_IID_MASK	(~(((1<<2)-1) << 1)) 
#define	IIR_nIP	        (1)

/******************************
 * UART FCR bit definitions
 *****************************/
#define	FCR_ITL(n)	(((n) & 0x3) << 6)
#define	FCR_ITL_MASK	(~(((1<<2)-1) << 6)) 
#define	FCR_BUS	        (1<<5)
#define	FCR_TRAIL	(1<<4)
#define	FCR_TIL	        (1<<3)
#define	FCR_RESETTF	(1<<2)
#define	FCR_RESETRF	(1<<1)
#define	FCR_TRFIFOE	(1)

/******************************
 * UART FOR bit definitions
 *****************************/
#define	FOR_ITL(n)	((n) & 0x3F)
#define	FOR_ITL_MASK	(~(((1<<6)-1))) 

/******************************
 * UART ABR bit definitions
 *****************************/
#define	ABR_ABT	        (1<<3)
#define	ABR_ABUP	(1<<2)
#define	ABR_ABLIE       (1<<1)
#define	ABR_ABE	        (1)

/******************************
 * UART ACR bit definitions
 *****************************/
#define	ACR_Count_Value(n)	((n) & 0xFFFF)
#define	ACR_Count_Value_MASK	(~(((1<<16)-1))) 

/******************************
 * UART LCR bit definitions
 *****************************/
#define	LCR_DLAB	(1<<7)
#define	LCR_SB	        (1<<6)
#define	LCR_STKYP	(1<<5)
#define	LCR_EPS	        (1<<4)
#define	LCR_PEN	        (1<<3)
#define	LCR_STB	        (1<<2)
#define	LCR_WLS(n)	(n & 0x3)
#define	LCR_WLS_MASK	(~(((1<<2)-1))) 

/******************************
 * UART LSR bit definitions
 *****************************/
#define	LSR_DR		(1)
#define	LSR_OE		(1<<1)
#define	LSR_PE		(1<<2)
#define	LSR_FE		(1<<3)
#define	LSR_BI		(1<<4)
#define	LSR_TDRQ	(1<<5)
#define	LSR_TEMT	(1<<6)
#define	LSR_FIFOE	(1<<7)

/******************************
 * UART MCR bit definitions
 *****************************/
#define	MCR_DTR		(1)
#define	MCR_RTS		(1<<1)
#define	MCR_OUT1	(1<<2)
#define	MCR_OUT2	(1<<3)
#define	MCR_LOOP	(1<<4)
#define	MCR_AFE		(1<<5)

/******************************
 * UART MSR bit definitions
 *****************************/
#define	MSR_DCTS	(1)
#define	MSR_DDSR	(1<<1)
#define	MSR_TERI	(1<<2)
#define	MSR_DDCD	(1<<3)
#define	MSR_CTS		(1<<4)
#define	MSR_DSR		(1<<5)
#define	MSR_RI		(1<<6)
#define	MSR_DCD		(1<<7)

/******************************
 * UART SCR bit definitions
 *****************************/
#define	SCR_Scratchpad(n)	(n & 0xFF)
#define	SCR_Scratchpad_MASK	(~(((1<<8)-1))) 

/******************************
 * UART ISR bit definitions
 *****************************/
#define	ISR_XMITIR	(1)
#define	ISR_RCVEIR	(1<<1)
#define	ISR_XMODE	(1<<2)
#define	ISR_TXPL	(1<<3)
#define	ISR_RXPL	(1<<4)

/*
 * USB Client
 * TODO: Junaith
 */
#define UDCCR	_PXAREG(0x40600000)
#define UDCICR0	_PXAREG(0x40600004)
#define UDCICR1	_PXAREG(0x40600008)
#define UDCISR0	_PXAREG(0x4060000C)
#define UDCISR1	_PXAREG(0x40600010)
#define UDCFNR	_PXAREG(0x40600014)
#define UDCOTGICR _PXAREG(0x40600018)
#define UDCOTGISR _PXAREG(0x4060001C)
#define UP2OCR	_PXAREG(0x40600020)
#define UP3OCR	_PXAREG(0x40600024)
#define UDCCSR0	_PXAREG(0x40600100)
#define UDCCSRA	_PXAREG(0x40600104)
#define UDCCSRB	_PXAREG(0x40600108)
#define UDCCSRC	_PXAREG(0x4060010C)
#define UDCCSRD	_PXAREG(0x40600110)
#define UDCCSRE	_PXAREG(0x40600114)
#define UDCCSRF	_PXAREG(0x40600118)
#define UDCCSRG	_PXAREG(0x4060011C)
#define UDCCSRH	_PXAREG(0x40600120)
#define UDCCSRI	_PXAREG(0x40600124)
#define UDCCSRJ	_PXAREG(0x40600128)
#define	UDCCSRK	_PXAREG(0x4060012C)
#define	UDCCSRL	_PXAREG(0x40600130)
#define	UDCCSRM	_PXAREG(0x40600134)
#define	UDCCSRN	_PXAREG(0x40600138)
#define	UDCCSRP	_PXAREG(0x4060013C)
#define	UDCCSRQ	_PXAREG(0x40600140)
#define	UDCCSRR	_PXAREG(0x40600144)
#define	UDCCSRS	_PXAREG(0x40600148)
#define	UDCCSRT	_PXAREG(0x4060014C)
#define	UDCCSRU	_PXAREG(0x40600150)
#define	UDCCSRV	_PXAREG(0x40600154)
#define	UDCCSRW	_PXAREG(0x40600158)
#define	UDCCSRX	_PXAREG(0x4060015C)
#define	UDCBCR0	_PXAREG(0x40600200)
#define	UDCBCRA	_PXAREG(0x40600204)
#define	UDCBCRB	_PXAREG(0x40600208)
#define	UDCBCRC	_PXAREG(0x4060020C)
#define	UDCBCRD	_PXAREG(0x40600210)
#define	UDCBCRE	_PXAREG(0x40600214)
#define	UDCBCRF	_PXAREG(0x40600218)
#define	UDCBCRG	_PXAREG(0x4060021C)
#define	UDCBCRH	_PXAREG(0x40600220)
#define	UDCBCRI	_PXAREG(0x40600224)
#define	UDCBCRJ	_PXAREG(0x40600228)
#define	UDCBCRK	_PXAREG(0x4060022C)
#define	UDCBCRL	_PXAREG(0x40600230)
#define	UDCBCRM	_PXAREG(0x40600234)
#define	UDCBCRN	_PXAREG(0x40600238)
#define	UDCBCRP	_PXAREG(0x4060023C)
#define	UDCBCRQ	_PXAREG(0x40600240)
#define	UDCBCRR	_PXAREG(0x40600244)
#define	UDCBCRS	_PXAREG(0x40600248)
#define	UDCBCRT	_PXAREG(0x4060024C)
#define	UDCBCRU	_PXAREG(0x40600250)
#define	UDCBCRV	_PXAREG(0x40600254)
#define	UDCBCRW	_PXAREG(0x40600258)
#define	UDCBCRX	_PXAREG(0x4060025C)

#define	UDCDR0	_PXAREG(0x40600300)
#define	UDCDRA	_PXAREG(0x40600304)
#define	UDCDRB	_PXAREG(0x40600308)
#define	UDCDRC	_PXAREG(0x4060030C)
#define	UDCDRD	_PXAREG(0x40600310)
#define	UDCDRE	_PXAREG(0x40600314)
#define	UDCDRF	_PXAREG(0x40600318)
#define	UDCDRG	_PXAREG(0x4060031C)
#define	UDCDRH	_PXAREG(0x40600320)
#define	UDCDRI	_PXAREG(0x40600324)
#define	UDCDRJ	_PXAREG(0x40600328)
#define	UDCDRK	_PXAREG(0x4060032C)
#define	UDCDRL	_PXAREG(0x40600330)
#define	UDCDRM	_PXAREG(0x40600334)
#define	UDCDRN	_PXAREG(0x40600338)
#define	UDCDRP	_PXAREG(0x4060033C)
#define	UDCDRQ	_PXAREG(0x40600340)
#define	UDCDRR	_PXAREG(0x40600344)
#define	UDCDRS	_PXAREG(0x40600348)
#define	UDCDRT	_PXAREG(0x4060034C)
#define	UDCDRU	_PXAREG(0x40600350)
#define	UDCDRV	_PXAREG(0x40600354)
#define	UDCDRW	_PXAREG(0x40600358)
#define	UDCDRX	_PXAREG(0x4060035C)

#define	UDCCRA	_PXAREG(0x40600404)
#define	UDCCRB	_PXAREG(0x40600408)
#define	UDCCRC	_PXAREG(0x4060040C)
#define	UDCCRD	_PXAREG(0x40600410)
#define	UDCCRE	_PXAREG(0x40600414)
#define	UDCCRF	_PXAREG(0x40600418)
#define	UDCCRG	_PXAREG(0x4060041C)
#define	UDCCRH	_PXAREG(0x40600420)
#define	UDCCRI	_PXAREG(0x40600424)
#define	UDCCRJ	_PXAREG(0x40600428)
#define	UDCCRK	_PXAREG(0x4060042C)
#define	UDCCRL	_PXAREG(0x40600430)
#define	UDCCRM	_PXAREG(0x40600434)
#define	UDCCRN	_PXAREG(0x40600438)
#define	UDCCRP	_PXAREG(0x4060043C)
#define	UDCCRQ	_PXAREG(0x40600440)
#define	UDCCRR	_PXAREG(0x40600444)
#define	UDCCRS	_PXAREG(0x40600448)
#define	UDCCRT	_PXAREG(0x4060044C)
#define	UDCCRU	_PXAREG(0x40600450)
#define	UDCCRV	_PXAREG(0x40600454)
#define	UDCCRW	_PXAREG(0x40600458)
#define	UDCCRX	_PXAREG(0x4060045C)

/*
 * UDC Control Register UDCCR bit definitions.
 * The UDC Control register (UDCCR) contains control and status bits. 
 * All bits in this register are reset after a USB reset is received from the 
 * external USB host.
 */

#define UDCCR_UDE     (1 << 0)  
#if 0
				 //currently, PXA27XUSBClient.h defines all but UDE
#define UDCCR_UDA     (1 << 1) 
#define UDCCR_UDR     (1 << 2)
#define UDCCR_EMCE    (1 << 3)
#define UDCCR_SMAC    (1 << 4)
#define UDCCR_AAISN0  (1 << 5)
#define UDCCR_AAISN1  (1 << 6)
#define UDCCR_AAISN2  (1 << 7)
#define UDCCR_AIN0    (1 << 8)
#define UDCCR_AIN1    (1 << 9)
#define UDCCR_AIN2    (1 << 10)
#define UDCCR_ACN0    (1 << 11)
#define UDCCR_ACN1    (1 << 12)
#define UDCCR_DWRE    (1 << 16)
#define UDCCR_BHNP    (1 << 28) 
#define UDCCR_AHNP    (1 << 29)
#define UDCCR_AALTHNP (1 << 30)
#define UDCCR_OEN     (1 << 31)

#endif

/*
 * RTC
 * TODO: Jon
 */
#define	RCNR	_PXAREG(0x40900000)
#define	RTAR	_PXAREG(0x40900004)
#define	RTSR	_PXAREG(0x40900008)
#define	RTTR	_PXAREG(0x4090000C)
#define	RDCR	_PXAREG(0x40900010)
#define	RYCR	_PXAREG(0x40900014)
#define	RDAR1	_PXAREG(0x40900018)
#define	RYAR1	_PXAREG(0x4090001C)
#define	RDAR2	_PXAREG(0x40900020)
#define	RYAR2	_PXAREG(0x40900024)
#define	SWCR	_PXAREG(0x40900028)
#define	SWAR1	_PXAREG(0x4090002C)
#define	SWAR2	_PXAREG(0x40900030)
#define	RTCPICR	_PXAREG(0x40900034)
#define	PIAR	_PXAREG(0x40900038)

#define RTSR_AL     (1)
#define RTSR_HZ     (1<<1)
#define RTSR_ALE    (1<<2)
#define RTSR_HZE    (1<<3)
#define RTSR_RDAL1  (1<<4)
#define RTSR_RDALE1 (1<<5)
#define RTSR_RDAL2  (1<<6)
#define RTSR_RDALE2 (1<<7)
#define RTSR_SWAL1  (1<<8)
#define RTSR_SWALE1 (1<<9)
#define RTSR_SWAL2  (1<<10)
#define RTSR_SWALE2 (1<<11)
#define RTSR_SWCE   (1<<12)
#define RTSR_PIAL   (1<<13)
#define RTSR_PIALE  (1<<14)
#define RTSR_PICE   (1<<15)

/*
 * OS Timers
 * TODO : Jon
 */
#define	OSMR0	_PXAREG(0x40A00000)
#define	OSMR1	_PXAREG(0x40A00004)
#define	OSMR2	_PXAREG(0x40A00008)
#define	OSMR3	_PXAREG(0x40A0000C)
#define	OSCR0	_PXAREG(0x40A00010)
#define	OSSR	_PXAREG(0x40A00014)
#define	OWER	_PXAREG(0x40A00018)
#define	OIER	_PXAREG(0x40A0001C)
#define	OSNR	_PXAREG(0x40A00020)
#define	OSCR4	_PXAREG(0x40A00040)
#define	OSCR5	_PXAREG(0x40A00044)
#define	OSCR6	_PXAREG(0x40A00048)
#define	OSCR7	_PXAREG(0x40A0004C)
#define	OSCR8	_PXAREG(0x40A00050)
#define	OSCR9	_PXAREG(0x40A00054)
#define	OSCR10	_PXAREG(0x40A00058)
#define	OSCR11	_PXAREG(0x40A0005C)
#define	OSMR4	_PXAREG(0x40A00080)
#define	OSMR5	_PXAREG(0x40A00084)
#define	OSMR6	_PXAREG(0x40A00088)
#define	OSMR7	_PXAREG(0x40A0008C)
#define	OSMR8	_PXAREG(0x40A00090)
#define	OSMR9	_PXAREG(0x40A00094)
#define	OSMR10	_PXAREG(0x40A00098)
#define	OSMR11	_PXAREG(0x40A0009C)
#define	OMCR4	_PXAREG(0x40A000C0)
#define	OMCR5	_PXAREG(0x40A000C4)
#define	OMCR6	_PXAREG(0x40A000C8)
#define	OMCR7	_PXAREG(0x40A000CC)
#define	OMCR8	_PXAREG(0x40A000D0)
#define	OMCR9	_PXAREG(0x40A000D4)
#define	OMCR10	_PXAREG(0x40A000D8)
#define	OMCR11	_PXAREG(0x40A000DC)

#define OIER_E0  (1)
#define OIER_E1  (1<<1)
#define OIER_E2  (1<<2)
#define OIER_E3  (1<<3)
#define OIER_E4  (1<<4)
#define OIER_E5  (1<<5)
#define OIER_E6  (1<<6)
#define OIER_E7  (1<<7)
#define OIER_E8  (1<<8)
#define OIER_E9  (1<<9)
#define OIER_E10 (1<<10)
#define OIER_E11 (1<<11)
#define OMCR_CRES(n)	(n & 0x7)
#define OMCR_CRES_MASK	(~(((1<<3)-1)))
#define OMCR_R     (1<<3)
#define OMCR_S(n)	((n & 0x3) << 4)
#define OMCR_S_MASK		(~(((1<<2)-1) << 4))
#define OMCR_P     (1<<6)
#define OMCR_C     (1<<7)

/*
 * GPIO
 * TODO : Lama
 */
#define	GPLR0	_PXAREG(0x40E00000)
#define	GPLR1	_PXAREG(0x40E00004)
#define	GPLR2	_PXAREG(0x40E00008)
#define	GPDR0	_PXAREG(0x40E0000C)
#define	GPDR1	_PXAREG(0x40E00010)
#define	GPDR2	_PXAREG(0x40E00014)
#define	GPSR0	_PXAREG(0x40E00018)
#define	GPSR1	_PXAREG(0x40E0001C)
#define	GPSR2	_PXAREG(0x40E00020)
#define	GPCR0	_PXAREG(0x40E00024)
#define	GPCR1	_PXAREG(0x40E00028)
#define	GPCR2	_PXAREG(0x40E0002C)
#define	GRER0	_PXAREG(0x40E00030)
#define	GRER1	_PXAREG(0x40E00034)
#define	GRER2	_PXAREG(0x40E00038)
#define	GFER0	_PXAREG(0x40E0003C)
#define	GFER1	_PXAREG(0x40E00040)
#define	GFER2	_PXAREG(0x40E00044)
#define	GEDR0	_PXAREG(0x40E00048)
#define	GEDR1	_PXAREG(0x40E0004C)
#define	GEDR2	_PXAREG(0x40E00050)
#define	GAFR0_L	_PXAREG(0x40E00054)
#define	GAFR0_U	_PXAREG(0x40E00058)
#define	GAFR1_L	_PXAREG(0x40E0005C)
#define	GAFR1_U	_PXAREG(0x40E00060)
#define	GAFR2_L	_PXAREG(0x40E00064)
#define	GAFR2_U	_PXAREG(0x40E00068)
#define	GAFR3_L	_PXAREG(0x40E0006C)
#define	GAFR3_U	_PXAREG(0x40E00070)
#define	GPLR3	_PXAREG(0x40E00100)
#define	GPDR3	_PXAREG(0x40E0010C)
#define	GPSR3	_PXAREG(0x40E00118)
#define	GPCR3	_PXAREG(0x40E00124)
#define	GRER3	_PXAREG(0x40E00130)
#define	GFER3	_PXAREG(0x40E0013C)
#define	GEDR3	_PXAREG(0x40E00148)

/*
 * Macros
 * The GPIO register addresses are not contiguous, need to define a base
 * address and offset for the 4th set.
 */
#define	GPLR_BASE	(0x40E00000)
#define	GPDR_BASE	(0x40E0000C)
#define	GPSR_BASE	(0x40E00018)
#define	GPCR_BASE	(0x40E00024)
#define	GRER_BASE	(0x40E00030)
#define	GFER_BASE	(0x40E0003C)
#define	GEDR_BASE	(0x40E00048)
#define	GAFR_BASE	(0x40E00054)

#define GPIO_REG_OFFSET(gpio) (((gpio) < 96) ? ((((gpio) & 0x7f) >> 5) * 4) : (0x100))
#define GPLR(gpio)	_PXAREG(GPLR_BASE + GPIO_REG_OFFSET(gpio))
#define GPDR(gpio)	_PXAREG(GPDR_BASE + GPIO_REG_OFFSET(gpio))
#define GPSR(gpio)	_PXAREG(GPSR_BASE + GPIO_REG_OFFSET(gpio))
#define GPCR(gpio)	_PXAREG(GPCR_BASE + GPIO_REG_OFFSET(gpio))
#define GRER(gpio)	_PXAREG(GRER_BASE + GPIO_REG_OFFSET(gpio))
#define GFER(gpio)	_PXAREG(GFER_BASE + GPIO_REG_OFFSET(gpio))
#define GEDR(gpio)	_PXAREG(GEDR_BASE + GPIO_REG_OFFSET(gpio))

/*
 * There are 8 alternate function registers for the 128 gpios
 * each alternate function is specified with 2 bits
 */
#define GAFR_REG_OFFSET(gpio) ((((gpio) & 0x7f) >> 4)*4)
#define GAFR(gpio)	_PXAREG(GAFR_BASE + GAFR_REG_OFFSET(gpio))

#define GPIO_BIT(gpio)	(1 << ((gpio) & 0x1f))
#define GPIO_FUNC_OFFSET(gpio)	(((gpio) & 0xf) * 2) 
#define GPIO_CLEAR_FUNC(gpio)	(~(3 << (GPIO_FUNC_OFFSET(gpio))))

#define SET_GPIO(gpio)  {GPSR(gpio) = GPIO_BIT(gpio);}
#define CLEAR_GPIO(gpio)  {GPCR(gpio) = GPIO_BIT(gpio);}
#define READ_GPIO(gpio) ((GPLR(gpio) & GPIO_BIT(gpio)) ? 1 : 0)
#define GPIO_OUT 1
#define GPIO_IN 0

#define GPIO_SET_ALT_FUNC(gpio,func,dir) \
{GPDR(gpio) = (dir==GPIO_OUT)? (GPDR(gpio) | GPIO_BIT(gpio)) : \
              (GPDR(gpio) & ~GPIO_BIT(gpio)); \
 GAFR(gpio) = (GAFR(gpio) & GPIO_CLEAR_FUNC(gpio)) | \
              (func << GPIO_FUNC_OFFSET(gpio));}
/*
 * Interrupt Controller		
 * TODO : Robbie
 */
#define	ICIP	_PXAREG(0x40D00000)
#define	ICMR	_PXAREG(0x40D00004)
#define	ICLR	_PXAREG(0x40D00008)
#define	ICFP	_PXAREG(0x40D0000C)
#define	ICPR	_PXAREG(0x40D00010)
#define	ICCR	_PXAREG(0x40D00014)
#define	ICHP	_PXAREG(0x40D00018)
#define	IPR0	_PXAREG(0x40D0001C)
#define	IPR1	_PXAREG(0x40D00020)
#define	IPR2	_PXAREG(0x40D00024)
#define	IPR3	_PXAREG(0x40D00028)
#define	IPR4	_PXAREG(0x40D0002C)
#define	IPR5	_PXAREG(0x40D00030)
#define	IPR6	_PXAREG(0x40D00034)
#define	IPR7	_PXAREG(0x40D00038)
#define	IPR8	_PXAREG(0x40D0003C)
#define	IPR9	_PXAREG(0x40D00040)
#define	IPR10	_PXAREG(0x40D00044)
#define	IPR11	_PXAREG(0x40D00048)
#define	IPR12	_PXAREG(0x40D0004C)
#define	IPR13	_PXAREG(0x40D00050)
#define	IPR14	_PXAREG(0x40D00054)
#define	IPR15	_PXAREG(0x40D00058)
#define	IPR16	_PXAREG(0x40D0005C)
#define	IPR17	_PXAREG(0x40D00060)
#define	IPR18	_PXAREG(0x40D00064)
#define	IPR19	_PXAREG(0x40D00068)
#define	IPR20	_PXAREG(0x40D0006C)
#define	IPR21	_PXAREG(0x40D00070)
#define	IPR22	_PXAREG(0x40D00074)
#define	IPR23	_PXAREG(0x40D00078)
#define	IPR24	_PXAREG(0x40D0007C)
#define	IPR25	_PXAREG(0x40D00080)
#define	IPR26	_PXAREG(0x40D00084)
#define	IPR27	_PXAREG(0x40D00088)
#define	IPR28	_PXAREG(0x40D0008C)
#define	IPR29	_PXAREG(0x40D00090)
#define	IPR30	_PXAREG(0x40D00094)
#define	IPR31	_PXAREG(0x40D00098)
#define	ICIP2	_PXAREG(0x40D0009C)
#define	ICMR2	_PXAREG(0x40D000A0)
#define	ICLR2	_PXAREG(0x40D000A4)
#define	ICFP2	_PXAREG(0x40D000A8)
#define	ICPR2	_PXAREG(0x40D000AC)
#define	IPR32	_PXAREG(0x40D000B0)
#define	IPR33	_PXAREG(0x40D000B4)
#define	IPR34	_PXAREG(0x40D000B8)
#define	IPR35	_PXAREG(0x40D000BC)
#define	IPR36	_PXAREG(0x40D000C0)
#define	IPR37	_PXAREG(0x40D000C4)
#define	IPR38	_PXAREG(0x40D000C8)
#define	IPR39	_PXAREG(0x40D000CC)

/*
 * Peripheral ID values
 * Took out the parenthesis on purpose due to SET_IPR macro below
 */
#define	IID_RTC_AL	31
#define	IID_RTC_HZ	30
#define	IID_OST_3	29
#define	IID_OST_2	28
#define	IID_OST_1	27
#define	IID_OST_0	26
#define	IID_DMAC	25
#define	IID_SSP1	24
#define	IID_MMC	        23
#define	IID_FFUART	22
#define	IID_BTUART	21
#define	IID_STUART	20
#define	IID_ICP	        19
#define	IID_I2C	        18
#define	IID_LCD	        17
#define	IID_SSP2	16
#define	IID_USIM	15
#define	IID_AC97	14
#define	IID_I2S	        13
#define	IID_PMU	        12
#define	IID_USBC	11
#define	IID_GPIO_X	10
#define	IID_GPIO_1	9
#define	IID_GPIO_0	8
#define	IID_OST_4_11	7
#define	IID_PWR_I2C	6
#define	IID_MEM_STK	5
#define	IID_KEYPAD	4
#define	IID_USBH1	3
#define	IID_USBH2	2
#define	IID_MSL	        1
#define	IID_SSP3	0

/*
 * Macros
 */

#define ICIP_BASE (0x40D0000)
#define ICMR_BASE (0x40D00004)
#define ICLR_BASE (0x40D00008)
#define ICFP_BASE (0x40D0000C)
#define ICPR_BASE (0x40D00010)
#define IPR_BASE  (0x40D0001C)

#define INTERRUPT_BIT(iid) (1<<((iid)%32))
#define INTERRUPT_REG_OFFSET(iid) (((iid)<32)?0:0x9c)

#define ICIP_REG(iid)  _PXAREG(ICIP_BASE + INTERRUPT_REG_OFFSET(iid))
#define ICMR_REG(iid)  _PXAREG(ICMR_BASE + INTERRUPT_REG_OFFSET(iid))
#define ICLR_REG(iid)  _PXAREG(ICLR_BASE + INTERRUPT_REG_OFFSET(iid))
#define ICFP_REG(iid)  _PXAREG(ICFP_BASE + INTERRUPT_REG_OFFSET(iid))
#define ICPR_REG(iid)  _PXAREG(ICPR_BASE + INTERRUPT_REG_OFFSET(iid))

#define IPR_REG_OFFSET(iid)  (((iid)<32)?(iid)*4: ((iid)*4)+20)  
#define IPR(iid)   _PXAREG(IPR_BASE + IPR_REG_OFFSET((iid)))


/******************************
 * IPR bit definitions
 *****************************/
#define IPR_VAL (1<<31)

/* 
 * Quick Capture Interface 
 * TODO : This was added by Konrad, any issues with keeping it, it is not
 *        in the original file. 
 */

/*
 * Control register 1
 */
#define CICR1_TBIT (1 << 31) 
#define CICR1_RGBT_CONV(data,x)   ((data & ~(0x7 << 29)) | (x << 29))       
#define CICR1_PPL(data,x)         ((data & ~(0x7ff << 15)) | (x << 15)) 
#define CICR1_RGB_CONV(data,x)    ((data & ~(0x7 << 12)) | (x << 12)) 
#define CICR1_RGB_F (1 << 11)
#define CICR1_YCBCR_F (1 << 10)
#define CICR1_RGB_BPP(data,x) ((data & ~(0x7 << 7)) | (x << 7))
#define CICR1_RAW_BPP(data,x) ((data & ~(0x3 << 5)) | (x << 5))
#define CICR1_COLOR_SP(data,x) ((data & ~(0x3 << 3)) | (x << 3))
#define CICR1_DW(data,x) ((data & ~(0x7 << 0)) | (x << 0)) 

/*
 * Control register 3
 */
#define CICR3_LPF(data,x) ((data & ~(0x7ff << 0)) | (x << 0))
                                               
/* 
 * Control Register 4 
 */
#define CICR4_PCLK_EN (1 << 23)
#define CICR4_HSP (1 << 21)
#define CICR4_VSP (1 << 20)
#define CICR4_MCLK_EN (1 << 19)
#define CICR4_DIV(data,x) ((data & ~(0xff << 0)) | (x << 0))

/* 
 * Status Register 
 */
#define CISR_FTO (1 << 15)
#define CISR_RDAV_2 (1 << 14)
#define CISR_RDAV_1 (1 << 13)
#define CISR_RDAV_0 (1 << 12)
#define CISR_FEMPTY_2 (1 << 11)
#define CISR_FEMPTY_1 (1 << 10)
#define CISR_FEMPTY_0 (1 << 9)
#define CISR_EOL (1 << 8)
#define CISR_PAR_ERR (1 << 7)
#define CISR_CQD (1 << 6)
#define CISR_CDD (1 << 5)
#define CISR_SOF (1 << 4)
#define CISR_EOF (1 << 3)
#define CISR_IFO_2 (1 << 2)
#define CISR_IFO_1 (1 << 1)
#define CISR_IFO_0 (1 << 0)


/* 
 * FIFO Control Register 
 */
#define CIFR_FLVL0(data,x) ((data & ~(0xff << 8)) | (x << 8)) 
#define CIFR_THL_0(data,x) ((data & ~(0x3 << 4)) | (x << 4))
#define CIFR_RESETF (1 << 3)

#endif /* _PXA27X_REGISTERS_DEF_H */
