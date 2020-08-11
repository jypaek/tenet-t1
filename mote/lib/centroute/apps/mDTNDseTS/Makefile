COMPONENT=mDTNDseTS
CONTRIB_INCLUDES += EmDeluge hostmote multihop sensorIB sequentialEEPROM mDTN sympathy reset_count
SENSORBOARD=mda300ca	

# Used to be sure we do not let tinyos include its own bootloader/deluge code
TINYOS_NP=

# Time in milliseconds between beacons
CFLAGS += -DLNKEST_BEACON_PER=100000

# To disable the LEDS after a certain time period
CFLAGS += -DNEW_DISABLE_LEDS

# add in the node health task
#CFLAGS += -DNODE_HEALTH 


# centroute flags
CFLAGS += -DUSE_ROUTE_ADAPTATION -DUSE_CENTROUTE -I../CentrouteToApp



CFLAGS += -DEMSTAR_NO_KERNEL -I$(TENETDIR)/mote/lib/centroute/apps/TreeLeaf

CFLAGS += --nesc-topdir=$(TENETDIR)/mote/lib/centroute/

#Lonely-mote (pre-configured with a query)
CFLAGS += -DLONELY_MOTE

#Router mote (no configuration or query)
#CFLAGS += -DROUTER_MOTE


# Use this flag to enable post-editting of the binary to set radio
# configurations.  DO NOT use if you are NOT planning to use the binary edit
# script!
#CFLAGS += -DPOST_MOTE_RADIO_CONFIG

# Use this flag to enable post-editting of the binary to set config and query
# configurations.  DO NOT use if you are NOT planning to use the binary edit
# script!
#CFLAGS += -DPOST_MOTE_QUERY_CONFIG

# increase the maximum number of supported tasks: was needed for 
# centroute
CFLAGS += -DTOSH_MAX_TASKS_LOG2=5

#CFLAGS += -DCC1K_DEFAULT_FREQ=2
#CFLAGS += -DTOSH_DATA_LENGTH=70
CFLAGS += -DTOSH_DATA_LENGTH=60
CFLAGS += -DMAX_RECORD_PAYLOAD=60

CFLAGS += -DLPL_MODE=3
CFLAGS += -DTX_POWER=0xFF

CFLAGS += -DHOSTMOTE_MAX_SEND_DATA_LENGTH=76
CFLAGS += -D_MAX_RETRANSMIT=5
#CFLAGS += -D_HOSTMOTE_DEBUG

# More than 2 sinks ever?
CFLAGS += -DPTHEST_MAX_SINKS=2

# Pages DTN will use.
CFLAGS += -DRECORD_START_PAGE=1200
CFLAGS += -DRECORD_END_PAGE=2000

# Necessary includes directly from the tinyos distro
PFLAGS= -I%T/lib/Queue
PFLAGS+= -I%T/lib/Deluge/TOSBoot/include


include ../Makerules 
#~/tinyos/opt/tinyos-1.x/tools/make/emstar.target

### Legacy flags below this line

# For Contam deployments using ion-selective electrodes from sentek
#CFLAGS += -DNOISE_WINDOW

#CFLAGS += -DUSE_SYMPATHY -DSYMPATHY_NEIGHBOR_INFO
#CFLAGS += -DSYMPATHY_DSE
#CFLAGS += -DSYMPATHY_FAULT

# Set to compile in Deluge
#CFLAGS += -DUSE_DELUGE
#CFLAGS += -DEMSTAR_NO_KERNEL -DPLATFORM_EMSTAR

#-I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/interfaces -I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/system -I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/platform/mica2/

#-I$(EMSTAR_ROOT)/tos-contrib/dse/tos/interfaces -I$(EMSTAR_ROOT)/tos-contrib/herd/apps/TreeLeafApplication/ -I$(EMSTAR_ROOT)/tos-contrib/herd/tos/system/ -I$(EMSTAR_ROOT)/tos-contrib/herd/tos/interfaces/ 

# to compile for centroute with the node health task
#CFLAGS += -DWRAPPER -DDEFAULT_MAX_RETRIES=5 -DDATA_TX_TIMER=30 -DHOSTMOTE_MAX_RECV_DATA_LENGTH=56 -DNODE_HEALTH -DLNKEST_BEACON_PER=100000  - 

# to compile for centroute without the node health task
#CFLAGS += -g -DWRAPPER -DDEFAULT_MAX_RETRIES=5 -DDATA_TX_TIMER=30 -DHOSTMOTE_MAX_RECV_DATA_LENGTH=56 -DLNKEST_BEACON_PER=100000 -DUSE_ROUTE_ADAPTATION -UUSE_SYMPATHY -DUSE_CENTROUTE -I../CentrouteToApp -I$(EMSTAR_ROOT)/tos-contrib/dse/tos/interfaces -I$(EMSTAR_ROOT)/tos-contrib/herd/apps/TreeLeafApplication/ -I$(EMSTAR_ROOT)/tos-contrib/herd/tos/system/ -I$(EMSTAR_ROOT)/tos-contrib/herd/tos/interfaces/ -I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/interface -I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/system -I$(EMSTAR_ROOT)/tos-contrib/node_health/tos/platform/mica2/

#CFLAGS += -DMAX_RECORD_PAYLOAD=60
#CFLAGS += -DSTATUS_DBG

#include ../Makerules ~/emstar/emstar/mote/emtos/sockets.target