COMPONENT=Tenet

# Below line must be uncommented to compile with Image tasklet
#CYCLOPS_HOST=1

# Below line can be uncommented to compile without timesync
#NO_TIMESYNC=1


#CFLAGS += -DFWD_QUEUE_LEN=21
#CFLAGS += -DLINK_NUM_RETX=4
DATA_LENGTH=114


# One of below line can be uncommented to test simple internally generated tasks
#TASK_TESTING=TEST_BLINK
#TASK_TESTING=TEST_CNT_TO_LEDS_AND_RFM

# Below line can be uncommented to test in 1-hop without routing/transport
#ONE_HOP_TASKING=1

# Flags to compile tenet applications using the centroute routing layer
#USE_ROUTE_ADAPTATION=1
#CFLAGS += -DUSE_CENTROUTE -DUSE_ROUTE_ADAPTATION=1
# these lines needed to compile to run under EmStar 
#CFLAGS += -DOLD_TOS_MSG_FORMAT=1
#LDFLAGS += $(TENETDIR)/../tools/sf/sfsource.o

include ../Makerules
