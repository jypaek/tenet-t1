PROGRAMS= trd_debugreceive trd_testsend 

TENETPATH = ../..

INCPATH = $(TENETPATH)/master/include
SFPATH = $(TENETPATH)/tools/sf
TRDPATH = $(TENETPATH)/master/trd

MOTETRDPATH = $(TENETPATH)/mote/lib/trd
# Any "trd_*" files that are not found in this directory(TRDPATH)
# are in the mote/lib/trd directory


CFILES = $(TRDPATH)/trd.c $(TRDPATH)/trd_state.c $(TRDPATH)/trd_misc.c
CFILES += $(TRDPATH)/trd_timer.c $(TRDPATH)/trd_memory.c
CFILES += $(MOTETRDPATH)/trd_table.c $(MOTETRDPATH)/trd_nodecache.c
CFILES += $(MOTETRDPATH)/trd_metalist.c $(MOTETRDPATH)/trd_seqno.c
CFILES += $(MOTETRDPATH)/trd_checksum.c
CFILES += $(INCPATH)/timeval.c $(INCPATH)/tosmsg.c
CFILES += $(SFPATH)/sfsource.c


CFLAGS += -I$(INCPATH) -I$(SFPATH) -I$(MOTETRDPATH) -I$(TENETPATH)/mote/test/TestTRD
CFLAGS_EXTRA += -I$(MOTETRDPATH) -I$(TRDPATH)


CFLAGS += -DBUILDING_PC_SIDE
ifdef OLD_TOS_MSG
    CFLAGS += -DOLD_TOS_MSG_FORMAT=1
endif


all: $(PROGRAMS)

trd_debugreceive: trd_debugreceive.c $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c $(INCPATH)/tosmsg.c
	gcc -O1 -Wall -g $(CFLAGS) -o $@ $^

trd_testsend: $(CFILES) trd_testsend.c
	gcc -O1 -Wall -g $(CFLAGS) $(CFLAGS_EXTRA) -o $@ $^

clean:
	rm -f $(PROGRAMS)

