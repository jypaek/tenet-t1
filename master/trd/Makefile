
TRD_TARGET= trd_listen trd_deamon trd_inject
TRD_TARGET_ARM= atrd_listen atrd_deamon atrd_inject

TENETPATH = ../..
MASTERPATH = ..

INCPATH = $(MASTERPATH)/include
SFPATH = $(TENETPATH)/tools/sf

MOTETRDPATH = $(TENETPATH)/mote/lib/trd
# Any "trd_*" files that are not found in this directory(TRDPATH)
# are in the mote/lib/trd directory


CFILES = trd.c trd_state.c trd_timer.c trd_memory.c trd_misc.c
CFILES += $(MOTETRDPATH)/trd_table.c $(MOTETRDPATH)/trd_nodecache.c
CFILES += $(MOTETRDPATH)/trd_metalist.c $(MOTETRDPATH)/trd_seqno.c
CFILES += $(MOTETRDPATH)/trd_checksum.c
CFILES += $(INCPATH)/timeval.c $(INCPATH)/tosmsg.c
CFILES += $(SFPATH)/sfsource.c

include $(INCPATH)/Makerules

CFLAGS += -I$(INCPATH) -I$(SFPATH) -I$(MOTETRDPATH)


# default is not to compile for arm.
all: pc
pc: $(TRD_TARGET)
arm: $(TRD_TARGET_ARM)


# For PC
trd_listen: trd_listen.c trd_misc.c $(INCPATH)/tosmsg.c $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c
	gcc -O1 -Wall -g -o $@ $(CFLAGS) $^
trd_deamon: trd_deamon.c $(CFILES)
	gcc -O1 -Wall -g -o $@ $(CFLAGS) $^
trd_inject: trd_inject.c $(CFILES)
	gcc -O1 -Wall -g -o $@ $(CFLAGS) $^

# For ARM
atrd_listen: trd_listen.c trd_misc.c $(INCPATH)/tosmsg.c $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c
	arm-linux-gcc -O1 -Wall -g -o $@ $(CFLAGS) $^
atrd_deamon: trd_deamon.c $(CFILES)
	arm-linux-gcc -O1 -Wall -g -o $@ $(CFLAGS) $^
atrd_inject: trd_inject.c $(CFILES)
	arm-linux-gcc -O1 -Wall -g -o $@ $(CFLAGS) $^

clean:
	rm -f $(TRD_TARGET)
	rm -f $(TRD_TARGET_ARM)

