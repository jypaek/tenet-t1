COMPONENT=TestTransport

#CFLAGS += -DRCRT_DEBUG=1
#CFLAGS += -DDEBUG_ROUTE_CHANGE=1
#CFLAGS += -DRSSI_ROUTER=1


ifdef SR
    CFLAGS += -DSTATIC_ROUTING=$(SR)
endif
ifdef BS
    CFLAGS += -DBS=$(BS)
endif

ifdef Q
    CFLAGS += -DFWD_QUEUE_LEN=$(Q)
else
    CFLAGS += -DFWD_QUEUE_LEN=16
endif

ifdef L
    CFLAGS += -DLINK_NUM_RETX=$(L)
else
    CFLAGS += -DLINK_NUM_RETX=4
endif

ifdef D
    CFLAGS += -DTOSH_DATA_LENGTH=$(D)
else
    CFLAGS += -DTOSH_DATA_LENGTH=64
endif


#################################################
# Set Path..........
#################################################
LOCALDIR := ../..
LOCALLIB := $(LOCALDIR)/lib

TENETDIR := /home/jpaek/public_svn/tenet/mote
TENETLIB := $(TENETDIR)/lib
TENETPLATFORM := $(TENETDIR)/platform

CFLAGS += -I$(LOCALLIB)
CFLAGS += -I$(TENETLIB)


#################################################
# IFRC Mac settings
#################################################
ifdef IFRC
    CFLAGS += -DIFRC=$(IFRC)
endif
ifdef SACK
    CFLAGS += -DSACK=1
endif


CFLAGS += -I$(LOCALLIB)/router
CFLAGS += -I$(TENETLIB)/router
CFLAGS += -I$(LOCALLIB)/router/MultiHopLQI
CFLAGS += -I$(TENETLIB)/router/MultiHopLQI
CFLAGS += -I$(LOCALLIB)/router/MultiHopRSSI
CFLAGS += -I$(TENETLIB)/router/MultiHopRSSI

CFLAGS += -I$(TENETLIB)/transport
CFLAGS += -I$(TENETLIB)/trd
CFLAGS += -I$(TENETLIB)/timer
CFLAGS += -I$(TENETLIB)/timesync



#################################################
# TinyOS default Makerules
#################################################
ifndef TOSDIR
    TOSDIR := $(shell ncc -print-tosdir)
endif
include $(TOSDIR)/../apps/Makerules

#ifndef NP
#    TINYOS_NP := NONE 
#endif


#################################################
# Platform dependent
#################################################
ifeq ($(PLATFORM),micaz)
    CFLAGS += -I$(TENETPLATFORM)/micaz
    CFLAGS += -I$(TENETPLATFORM)/micaz/32bitTimer
endif
ifeq ($(PLATFORM),mica2)
    CFLAGS += -I$(TENETPLATFORM)/micaz
    CFLAGS += -I$(TENETPLATFORM)/micaz/32bitTimer
endif
ifeq ($(PLATFORM),telosb)
    CFLAGS += -I$(TENETPLATFORM)/telosb
endif

CFLAGS += -DOLD_TOS_MSG_FORMAT=1

