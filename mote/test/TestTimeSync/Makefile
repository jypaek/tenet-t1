
###############################################################################
# supported platforms:  mica2, 
#                       mica2dot, 
#                       micaZ (only TIMESYNC_SYSTIME), 
#                         --> No, we support both using ENLTimer - jpaek
#                       telos(no TIMESYNC_SYSTIME support)
#
# the following directives are recognized by TimeSync component 
#
# -DTIMESYNC_DEBUG: enforces multiple hops in software
# -DTIMESYNC_SYSTIME: choice of clock source(1MHz internal, or 32kHz external)
#
###############################################################################

################################################################################
# Test FTSP TimeSync
# - compile two or more motes here.
# - compile one mote in this directory with 'POLLER=1' flag
# - compile one mote with TOSBase
#
# How it works
# - poller sends out reference broadcast
# - all other motes, upon reception of this poll msg, send out poll reply
# - use TOSBase to listen to these replies and check ftsp performance
#
# To see the reply packets
# - go to 'ftsplisten' directory and run the program
#
################################################################################

# Do I want to compile the poller? (mote which sends out reference broadcast?)
ifdef POLLER
    COMPONENT=TestTimeSyncPollerC
    # You want to make the reference-broadcast (poller) powerful
    # so that as many motes as possible can hear it.
    CFLAGS += -DCC2420_DEF_RFPOWER=31
endif

# otherwise, let's compile 'TestTimeSyncAppC'.
ifndef COMPONENT
    COMPONENT=TestTimeSyncC
endif

# period of timesync msg broadcast and the period of reference broadcast
PFLAGS += -DTIMESYNC_RATE=20 -DTIMESYNC_POLLER_RATE=10

# let internal components know that we are testing...
CFLAGS += -DTESTTIMESYNC=1

CFLAGS += -I../../lib/timesync
CFLAGS += -I../../lib/timer

CFLAGS += -DTOSH_DATA_LENGTH=64

CFLAGS += -DOLD_TOS_MSG_FORMAT=1

include $(TOSDIR)/../apps/Makerules

TENETDIR := ../../
TENETPLATFORM := $(TENETDIR)/platform
ifeq ($(PLATFORM),micaz)
    CFLAGS += -DCLOCK_FREQ_32768=1
    CFLAGS += -I$(TENETPLATFORM)/micaz/32bitTimer
endif
ifeq ($(PLATFORM),mica2)
    CFLAGS += -DCLOCK_FREQ_32768=1
    CFLAGS += -I$(TENETPLATFORM)/micaz/32bitTimer
endif
ifeq ($(PLATFORM),telosb)
#    CFLAGS += -I$(TENETPLATFORM)/telosb
endif

