
COMPONENT = TestCyclopsHost

MOTEDIR := ../..
CYCLOPSLIB := $(MOTEDIR)/lib/cyclops

CFLAGS += -I$(CYCLOPSLIB)
CFLAGS += -I$(CYCLOPSLIB)/I2C
CFLAGS += -I$(CYCLOPSLIB)/neuron


# Disable Deluge!! (causes problem with cyclops)
TINYOS_NP := NONE 

CFLAGS += -DTOSH_DATA_LENGTH=64

include $(TOSDIR)/../apps/Makerules

