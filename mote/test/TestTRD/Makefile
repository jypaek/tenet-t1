COMPONENT=TestTRD
BUILD_EXTRA_DEPS+=grid_lossy

CFLAGS += -DTOSH_DATA_LENGTH=80

CFLAGS += -DTESTTRD=1

CFLAGS += -I../../lib/
CFLAGS += -I../../lib/trd
CFLAGS += -I../../lib/timer

include $(TOSDIR)/../apps/Makerules

ifeq ($(PLATFORM),pc)
    CFLAGS += -DRAM_TRD=1
    CFLAGS += -DTRD_SEND_ENABLED=1
    CFLAGS += -I/home/jpaek/code/tenet/tinyos-1.x/tos/platform/pc
endif

grid_lossy: grid_lossy.c
	gcc -o grid_lossy grid_lossy.c

