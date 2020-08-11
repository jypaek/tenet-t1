
PC= sendtasknoroute   # default binary name

TENETPATH = ../..

SFPATH = $(TENETPATH)/tools/sf
INCPATH = $(TENETPATH)/master/include
LIBPATH = $(TENETPATH)/mote/lib
TASKPATH = $(TENETPATH)/master/tasklib

CFLAGS += -DBUILDING_PC_SIDE=1
CFLAGS += -DOLD_TOS_MSG_FORMAT=1
CFLAGS += -I. -I$(INCPATH) -I$(SFPATH) -I$(LIBPATH) -I$(TASKPATH)

CFILES += $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c
CFILES += $(INCPATH)/tosmsg.c $(INCPATH)/tosserial.c

TENET_LIB       = $(TASKPATH)/libtenet.a


all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
sendtasknoroute: sendtasknoroute.c $(CFILES) $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib: 
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)


