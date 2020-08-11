/* 
  * Author:		Josh Herbach
  * Revision:	1.0
  * Date:		09/02/2005
  */
#ifndef __PXA27XUSBCLIENT_H__
#define __PXA27XUSBCLIENT_H__

#define DEBUG 0
#define ASSERT 0

#define USBPOWER 125 // 1/2 of the actually requested power, so 250 ma

#define _PXAREG8(_addr)	(*((volatile uint8_t *)(_addr)))
#define _PXAREG16(_addr)	(*((volatile uint16_t *)(_addr)))

#define _UDC_bit(_udc)  (1 << ((_udc) & 0x1f))


#define USB_ENDPOINT_IN 7

// These define offsets within certain register bitmaps

//UDCCR
//#define UDCCR_UDE 0	// defined in pxa27x_registers.h , should move all	
#define UDCCR_EMCE 3
#define UDCCR_SMAC 4
#define UDCCR_ACN 11


//UDCCSR0
#define UDCCSR0_ACM 9
#define UDCCSR0_AREN 8
#define UDCCSR0_SA 7
#define UDCCSR0_FST 5
#define UDCCSR0_DME 3
#define UDCCSR0_FTF 2
#define UDCCSR0_IPR 1
#define UDCCSR0_OPC 0

//UDCCSRAX
#define UDCCSRAX_DPE 9
#define UDCCSRAX_FEF 8
#define UDCCSRAX_SP 7
#define UDCCSRAX_BNEBNF 6
#define UDCCSRAX_FST 5
#define UDCCSRAX_SST 4
#define UDCCSRAX_DME 3
#define UDCCSRAX_TRN 2
#define UDCCSRAX_PC 1
#define UDCCSRAX_FS 0

//UDCCRAX
#define UDCCRAX_CN 25
#define UDCCRAX_IN 22
#define UDCCRAX_AISN 19
#define UDCCRAX_EN 15
#define UDCCRAX_ET 13
#define UDCCRAX_ED 12
#define UDCCRAX_MPS 2
#define UDCCRAX_DE 1
#define UDCCRAX_EE 0

//Interrupts
#define INT_IRCC 31 // SET_CONFIGURATION or SET_INTERRUPT command received
#define INT_IRSOF 30 // Start-of-frame received
#define INT_IRRU 29 // Resume detected
#define INT_IRSU 28 // Suspend detected
#define INT_IRRS 27 // USB reset detected

#define INT_END0 0 //Endpoint 0 packet complete bit
#define INT_ENDA 2 //Endpoint A packet complete bit
#define INT_ENDB 4 //Endpoint B packet complete bit

// USB control Setup request, Standard
#define USB_GETDESCRIPTOR 0x06
#define USB_SETCONFIGURATION 0x09

// USB control Setup request, Hid

#define USB_HID_GETREPORT 0x01
#define USB_HID_GETIDLE 0x02
#define USB_HID_GETPROTOCOL 0x03
#define USB_HID_SETREPORT 0x09
#define USB_HID_SETIDLE 0x0A
#define USB_HID_SETPROTOCOL 0x0B


// USB Descriptors
#define USB_DESCRIPTOR_DEVICE 0x01
#define USB_DESCRIPTOR_CONFIGURATION 0x02
#define USB_DESCRIPTOR_STRING 0x03
#define USB_DESCRIPTOR_INTERFACE 0x04
#define USB_DESCRIPTOR_ENDPOINT 0x05
#define USB_DESCRIPTOR_DEVICE_QUALIFIER 0x06
#define USB_DESCRIPTOR_OTHER_SPEED_CONFIG 0x07
#define USB_DESCRIPTOR_INTERFACE_POWER 0x08
#define USB_DESCRIPTOR_HID 0x21
#define USB_DESCRIPTOR_HID_REPORT 0x22

//Sending Data states, defined as bit flags
#define INPROGRESS 0
#define MIDSEND 1

//States, defined as full numbers, not flags
//0 is nothing
#define POWERED 1 //means attached and powered by the USB host
#define DEFAULT 2 //finished resetting
#define CONFIGURED 3 //ready to be used for communication

#define isFlagged(_BITFIELD, _FLAG) (((_BITFIELD) & (_FLAG)) != 0)
#define getByte(_WORD, _BYTE) ((((_WORD) >> (((_BYTE) & 0x03) * 8))) & 0xFF)
#define getBit(_BITFIELD, _BIT) (((_BITFIELD) >> ((_BIT) & 0x1F)) & 0x01)

#define STRINGS_USED 3

//Interfaces used
#define SENDVARLENPACKET 0
#define SENDJTPACKET 1
#define SENDBAREMSG 2


/*JT protocol numbers; NOTE: some of the constants 
are different between the client (mote) and host (pc) software (namely, 
the byte positions)*/

#define IMOTE_HID_REPORT 1
#define IMOTE_HID_TYPE_COUNT 4

//Imote2 HID report, byte positions
#define IMOTE_HID_TYPE 0
#define IMOTE_HID_NI 1
//Imote2 HID report, type byte,  bit positions
#define IMOTE_HID_TYPE_CL 0
#define IMOTE_HID_TYPE_L 2
#define IMOTE_HID_TYPE_H 4
#define IMOTE_HID_TYPE_MSC 5
//Imote2 HID report, type byte, L defintions
#define IMOTE_HID_TYPE_L_BYTE 0
#define IMOTE_HID_TYPE_L_SHORT 1
#define IMOTE_HID_TYPE_L_INT 2
//Imote2 HID report, L sizes
#define IMOTE_HID_TYPE_L_BYTE_SIZE 15871
#define IMOTE_HID_TYPE_L_SHORT_SIZE 3997695
#define IMOTE_HID_TYPE_L_INT_SIZE 0xFFFFFFFF
//Imote2 HID report, type byte, CL defintions
#define IMOTE_HID_TYPE_CL_GENERAL 0
#define IMOTE_HID_TYPE_CL_BINARY 1
#define IMOTE_HID_TYPE_CL_RPACKET 2
#define IMOTE_HID_TYPE_CL_BLUSH 3
//Imote2 HID report, type byte, MSC definitions
#define IMOTE_HID_TYPE_MSC_DEFAULT 0
#define IMOTE_HID_TYPE_MSC_BLOADER 1

/**
 * The types used by the boot loader extending
 * JT Protocol messages.
 * FIXME Currently the driver will not push the
 * MSC types to the right bits, so its easier to
 * set the right bits to start with. 
 * NOTE this value is not the same in PC App but the
 * result is the same.
 */
#define IMOTE_HID_TYPE_MSC_REBOOT 64
#define IMOTE_HID_TYPE_MSC_COMMAND 96
#define IMOTE_HID_TYPE_MSC_BINARY 128
#define IMOTE_HID_TYPE_MSC_ERROR 160

//Imote2 HID report, max packet data sizes
#define IMOTE_HID_BYTE_MAXPACKETDATA 62
#define IMOTE_HID_SHORT_MAXPACKETDATA 61
#define IMOTE_HID_INT_MAXPACKETDATA 59

#endif
