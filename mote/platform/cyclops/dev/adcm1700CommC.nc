////////////////////////////////////////////////////////////////////////////
// 
// CENS 
// Agilent
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Copyright (c) 2003 Agilent Corporation 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor Agilent Corporation nor 
//   the names of its contributors may be used to endorse or promote 
//   products derived from this software without specific prior written 
//   permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS , AGILENT CORPORATION AND 
// CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// AGILENT CORPORATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: A high level component to enable communication with camera to
//           write and read data to different block and offset addresses.
//           
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/platform/cyclops/dev/adcm1700CommC.nc,v 1.1 2007-07-03 00:57:48 jpaek Exp $
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu
//
////////////////////////////////////////////////////////////////////////////


configuration adcm1700CommC {
  provides {
    interface StdControl as imagerCommControl;
    interface imagerComm[uint8_t id];
  }
}
implementation {
  components adcm1700CommM,LedsC,I2CPacketImagerC;

  imagerCommControl = adcm1700CommM;
  imagerComm = adcm1700CommM;

  adcm1700CommM.Leds -> LedsC;

  //adcm1700CommM.I2CPacket -> I2CPacketImagerC.I2CPacket[0x53];
  adcm1700CommM.I2CPacket -> I2CPacketImagerC.I2CPacket[0x51];
  adcm1700CommM.I2CStdControl -> I2CPacketImagerC.StdControl;
}
