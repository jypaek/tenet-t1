 # Copyright (c) 2005 The Regents of the University of California.  All 
 # rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #
 # - Redistributions of source code must retain the above copyright
 #   notice, this list of conditions and the following disclaimer.
 #
 # - Neither the name of the University nor the names of its
 #   contributors may be used to endorse or promote products derived
 #   from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 # THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 # PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 #
 #
 # Authors: Shaun Ahmadian
 #          Alan Jern
 #          David Zats dzats@ucla.edu
 #          Mohammad Rahimi mhr@cens.ucla.edu
 #
 # History: created 08/10/05
 #

 #
 # @modified 6/27/2007
 # @author Jeongyeup Paek (jpaek@enl.usc.edu)
 #
 # This is for the cyclops device
 #

COMPONENT = CyclopsDevice


#################################################
# Include Libraries (header files, I2C, neuron)
#################################################
TENETMOTEDIR := ../..
CFLAGS += -I$(TENETMOTEDIR)/lib/cyclops
CFLAGS += -I$(TENETMOTEDIR)/lib/cyclops/I2C
CFLAGS += -I$(TENETMOTEDIR)/lib/cyclops/neuron
CFLAGS += -I$(TENETMOTEDIR)/lib/cyclops/objectdetection
CFLAGS += -I$(TENETMOTEDIR)/platform/cyclops
CFLAGS += -I$(TENETMOTEDIR)/platform/cyclops/dev


#################################################
# Packet Size
#################################################
CFLAGS += -DTOSH_DATA_LENGTH=114


#################################################
# Flash configuration (CBI, else SBI)
#################################################
#CFLAGS += -DCYCLOPS_FLASH_ON_IS_CBI=1


#################################################
# Disable Deluge
#################################################
TINYOS_NP := NONE 


#################################################
# Include TinyOS Makerules
#################################################
ifndef TOSDIR
    TOSDIR := $(shell ncc -print-tosdir)
endif
include $(TOSDIR)/../apps/Makerules

