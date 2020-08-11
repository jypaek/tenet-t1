
PC= snoop   # default binary name
ARM= asnoop # for arm processors (e.g. Stargates)


TENETPATH = ../..
MASTERPATH = ../../master

INCPATH = $(MASTERPATH)/include
LIBPATH = $(MASTERPATH)/tasklib
TRDPATH = $(MASTERPATH)/trd
TRANSPORT_PATH = $(MASTERPATH)/transport
SFPATH = $(TENETPATH)/tools/sf

MOTELIB = $(MASTERPATH)/../mote/lib
MOTETRDPATH = $(MOTELIB)/trd
MOTEROUTERPATH = $(MOTELIB)/router
MOTEMULTIHOPPATH = $(MOTELIB)/router/MultiHopLQI
MOTETRANSPORTPATH = $(MOTELIB)/transport
MOTETIMESYNCPATH = $(MOTELIB)/timesync


CFILES = $(INCPATH)/timeval.c $(INCPATH)/tosmsg.c $(SFPATH)/sfsource.c
CFILES += $(INCPATH)/tosserial.c $(SFPATH)/serialsource.c
CFILES += $(TRDPATH)/trd_misc.c


include $(INCPATH)/Makerules


CFLAGS += -I$(INCPATH) -I$(SFPATH) -I$(TRDPATH)
CFLAGS += -I$(MOTETRDPATH) -I$(MOTEROUTERPATH) -I$(MOTETRANSPORTPATH) -I$(MOTEMULTIHOPPATH)
CFLAGS += -I$(MOTETIMESYNCPATH) -I$(MOTELIB)


all: $(PC)

# default compilation
snoop: tenet_snoop.c $(CFILES)
	gcc -O1 -Wall -g -o $@ $(CFLAGS) $^

# For ARM
asnoop: tenet_snoop.c $(CFILES)
	arm-linux-gcc -O1 -Wall -g -o $@ $(CFLAGS) $^

clean:
	rm -f $(PC) $(ARM)

