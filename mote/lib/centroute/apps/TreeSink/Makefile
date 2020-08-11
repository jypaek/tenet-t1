COMPONENT=TreeSink
CONTRIB_INCLUDES += herd
##CFLAGS += -Itos-contrib/regionArea/tos/types/  ## No needed - Vinayak
#LDFLAGS += -L$(EMSTAR_ROOT)/obj.i686-linux/lib -lemstar_sockets
#CFLAGS += -DTOSH_DATA_LENGTH=140 -DWRAPPER
#PFLAGS= -I%T/lib/Queue
CFLAGS += -DEMSTAR_NO_KERNEL -DTOSH_DATA_LENGTH=150
# adding the USE_TENET flag will make this module interface with 
# serial forwarder rather than the emstar channel model
# specify the IP / Port for SF on the command line
#CFLAGS += -DUSE_TENET
CFLAGS += -DOLD_TOS_MSG_FORMAT=1
LDFLAGS += $(TENETDIR)/tools/sf/sfsource.o
include ../Makerules
