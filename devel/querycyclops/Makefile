
PC = querycyclops
TOOLS= bmp2dat dat2bmp


TENETPATH = ../..

SFPATH = $(TENETPATH)/tools/sf
INCPATH = $(TENETPATH)/master/include
CYCLOPSLIBPATH = $(TENETPATH)/mote/lib/cyclops
NEURONPATH = $(TENETPATH)/lib/cyclops/neuron


CFLAGS += -DBUILDING_PC_SIDE=1
CFLAGS += -DOLD_TOS_MSG_FORMAT=1
CFLAGS += -I. -I$(INCPATH) -I$(SFPATH) -I$(CYCLOPSLIBPATH) -I$(NEURONPATH)
CFLAGS += -I$(TENETPATH)/mote/test/TestCyclopsHost

CFILES += $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c
CFILES += $(INCPATH)/tosmsg.c $(INCPATH)/tosserial.c
CFILES += $(CYCLOPSLIBPATH)/cyclops_query.c
CFILES += bmp.c cyapp_util.c


all: $(PC) $(TOOLS)

# default compilation
querycyclops: querycyclops.c $(CFILES)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

dat2bmp: dat2bmp.c bmp.c
	gcc $^ -o dat2bmp

bmp2dat: bmp2dat.c bmp.c
	gcc $^ -o bmp2dat

clean:
	rm -f $(PC) $(TOOLS)

