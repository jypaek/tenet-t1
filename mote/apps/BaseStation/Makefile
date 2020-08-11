COMPONENT=BaseStation

# BASE_STATION
#  - this must be defined for the multi-root version of MultihopLQI to work.
CFLAGS += -DBASE_STATION


CFLAGS += -DTOSH_MAX_TASKS_LOG2=8


# TIMESYNC_HELPER is required to run
#   - TimeSyncDebugger and/or TestTimeSyncPoller
CFLAGS += -DTIMESYNC_HELPER -DBS_SERVICE
CFLAGS += -I$(TENETLIB)/../test/TestTimeSync

ifdef IFRC
    CFLAGS += -DIFRC=$(IFRC)
endif
ifdef SACK
    CFLAGS += -DSACK=1
    CFLAGS += -I$(TENETLIB)/CC2420
endif

ifdef Q
    CFLAGS += -DBS_Q_LEN=$(Q)
endif

##############################################################

# This "Makerules" must come before any use of $(PLATFORM)
include ../Makerules

##############################################################

