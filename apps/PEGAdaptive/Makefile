PROGRAMS= PEGAdaptive aPEGAdaptive querytime aquerytime

# Packet Format
#CFLAGS += -DOLD_TOS_MSG_FORMAT=1
CFLAGS += -DCC2420_TOS_MSG_FORMAT=1

STARGATEPATH = ../..
MOTEPATH = ../../../mote

SFPATH = $(STARGATEPATH)/sys/sf
INCPATH = $(STARGATEPATH)/include
TRANSPATH = $(STARGATEPATH)/sys/transport
TASKPATH = $(STARGATEPATH)/task
PARSERPATH = $(STARGATEPATH)/parser
MOTELIB = $(MOTEPATH)/lib


CFILES += $(SFPATH)/sfsource.c $(SFPATH)/platform.c $(INCPATH)/tosmsg.c
CFILES += $(INCPATH)/itimer.c $(INCPATH)/timeval.c
CFILES += $(TASKPATH)/test_tasks.c $(TASKPATH)/element_construct.c
_TRANSPORTFILES = tasklist.c transportAPI.c serviceAPI.c tr_if.c service_if.c
TRANSPORTFILES = $(patsubst %,../../sys/transport/%,$(_TRANSPORTFILES))
CFILES += $(TRANSPORTFILES) 
CFILES += $(TASKPATH)/test_tasks.c $(TASKPATH)/task_construct.c $(TASKPATH)/element_construct.c
PARSERFILES += $(PARSERPATH)/lex.yy.c $(PARSERPATH)/y.tab.c $(PARSERPATH)/tp.c


CFLAGS += -I$(SFPATH) -I$(INCPATH) -I$(MOTELIB)
CFLAGS += -I$(TASKPATH) -I$(PARSERPATH) -I$(TRANSPATH)


# below definition of "BUILDING_PC_SIDE" is used in stargate/task/* files
# they allow the PC-side and mote to share the task contructing functions.
CFLAGS += -DBUILDING_PC_SIDE


all: $(PROGRAMS)

PEGAdaptive: sampleRSSI.c querytime.c $(CFILES) 
	flex -o$(PARSERPATH)/lex.yy.c $(PARSERPATH)/lexer.l
	yacc -o $(PARSERPATH)/y.tab.c -d $(PARSERPATH)/parser.y 
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ $(PARSERFILES) 

aPEGAdaptive: sampleRSSI.c querytime.c $(CFILES)
	flex -o$(PARSERPATH)/lex.yy.c $(PARSERPATH)/lexer.l
	yacc -o $(PARSERPATH)/y.tab.c -d $(PARSERPATH)/parser.y
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ $(PARSERFILES)

querytime: querytime.c $(CFILES) 
	flex -o$(PARSERPATH)/lex.yy.c $(PARSERPATH)/lexer.l
	yacc -o $(PARSERPATH)/y.tab.c -d $(PARSERPATH)/parser.y
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ $(PARSERFILES) -DQUERY_MAIN

aquerytime: querytime.c $(CFILES)
	flex -o$(PARSERPATH)/lex.yy.c $(PARSERPATH)/lexer.l
	yacc -o $(PARSERPATH)/y.tab.c -d $(PARSERPATH)/parser.y
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ $(PARSERFILES) -DQUERY_MAIN

#asampleRSSI: $(CFILES) $(TRANSPORTFILES) $(TENETNOTASKFILES)
#	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

clean:
	rm -f $(PARSERPATH)/lex.yy.c $(PARSERPATH)/y.tab.c
	rm -f $(PROGRAMS)


