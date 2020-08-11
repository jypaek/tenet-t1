
LIB_TARGET     = libtenet.a
LIB_TARGET_ARM = libtenet_arm.a         # for arm processors (e.g. Stargates)
LIB_TARGET_CPP = libtenet_cpp.a
LIB_TARGET_ARM_CPP = libtenet_arm_cpp.a # for arm processors, g++ 

LIB_OBJECTS     = tenetAPI.o task_construct.o response.o \
                  element_construct.o element_usage.o task_error.o \
                  tp.o lex.yy.o y.tab.o \
                  transportAPI.o $(TRPATH)/tr_if.o $(TRPATH)/trsource.o \
                  $(TRPATH)/serviceAPI.o $(TRPATH)/service_if.o \
                  $(SFPATH)/sfsource.o \
                  $(INCPATH)/tosmsg.o $(INCPATH)/timeval.o
LIB_OBJECTS_ARM = tenetAPI.a.o task_construct.a.o response.a.o \
                  element_construct.a.o element_usage.a.o task_error.a.o \
                  tp.a.o lex.yy.a.o y.tab.a.o \
                  transportAPI.a.o $(TRPATH)/tr_if.a.o $(TRPATH)/trsource.a.o \
                  $(TRPATH)/serviceAPI.a.o $(TRPATH)/service_if.a.o \
                  $(SFPATH)/sfsource.a.o \
                  $(INCPATH)/tosmsg.a.o $(INCPATH)/timeval.a.o
LIB_OBJECTS_CPP = tenetAPI.p.o task_construct.p.o response.p.o \
                  element_construct.p.o element_usage.p.o task_error.p.o \
                  tp.p.o lex.yy.p.o y.tab.p.o \
                  transportAPI.p.o $(TRPATH)/tr_if.p.o $(TRPATH)/trsource.p.o \
                  $(TRPATH)/serviceAPI.p.o $(TRPATH)/service_if.p.o \
                  $(SFPATH)/sfsource.p.o \
                  $(INCPATH)/tosmsg.p.o $(INCPATH)/timeval.p.o
LIB_OBJECTS_ARM_CPP = tenetAPI.a.p.o task_construct.a.p.o response.a.p.o \
                  element_construct.a.p.o element_usage.a.p.o task_error.a.p.o \
                  tp.a.p.o lex.yy.a.p.o y.tab.a.p.o \
                  transportAPI.a.p.o $(TRPATH)/tr_if.a.p.o $(TRPATH)/trsource.a.p.o \
                  $(TRPATH)/serviceAPI.a.p.o $(TRPATH)/service_if.a.p.o \
                  $(SFPATH)/sfsource.a.p.o \
                  $(INCPATH)/tosmsg.a.p.o $(INCPATH)/timeval.a.p.o

        
TENETPATH = ../..
MASTERPATH = ..

INCPATH = $(MASTERPATH)/include
TRPATH = $(MASTERPATH)/transport
SFPATH = $(TENETPATH)/tools/sf

TRDPATH = $(MASTERPATH)/trd
LIBPATH = $(MASTERPATH)/tasklib
MOTELIB = $(TENETPATH)/mote/lib
CYCLOPSLIB = $(TENETPATH)/mote/lib/cyclops


LIB_SRC = tenetAPI.c task_construct.c response.c \
          element_construct.c element_usage.c task_error.c tp.c \
          $(SFPATH)/sfsource.c $(SFPATH)/platform.c \
          $(INCPATH)/tosmsg.c $(INCPATH)/timeval.c \
          transportAPI.c $(TRPATH)/tr_if.c $(TRPATH)/trsource.c \
          $(TRPATH)/serviceAPI.c $(TRPATH)/service_if.c

          
include $(INCPATH)/Makerules


CFLAGS += -g -Wall
CFLAGS += -I. -I$(INCPATH) -I$(SFPATH) -I$(MOTELIB) -I$(TRPATH)
CFLAGS += -I$(CYCLOPSLIB) -DINCLUDE_CYCLOPS=1


# default is not to compile for arm.
##all: yacc_lex pc arm cpp arm_cpp
all: yacc_lex pc
arm: yacc_lex arm_lib

pc: $(LIB_TARGET) $(LIB_TARGET_CPP)

arm_lib: $(LIB_TARGET_ARM) $(LIB_TARGET_ARM_CPP)


$(LIB_TARGET): $(LIB_OBJECTS)
	ar scru $(LIB_TARGET) $(LIB_OBJECTS)

$(LIB_TARGET_ARM): $(LIB_OBJECTS_ARM)
	arm-linux-ar scru $(LIB_TARGET_ARM) $(LIB_OBJECTS_ARM) 

$(LIB_TARGET_CPP): $(LIB_OBJECTS_CPP)
	ar scru $(LIB_TARGET_CPP) $(LIB_OBJECTS_CPP)

$(LIB_TARGET_ARM_CPP): $(LIB_OBJECTS_ARM_CPP)
	arm-linux-ar scru $(LIB_TARGET_ARM_CPP) $(LIB_OBJECTS_ARM_CPP)

%.o: %.c
	gcc -o $*.o -c $(CFLAGS) $*.c

%.a.o: %.c
	arm-linux-gcc -o $*.a.o -c $(CFLAGS) $*.c

%.p.o: %.c
	g++ -o $*.p.o -c $(CFLAGS) $*.c

%.a.p.o: %.c
	arm-linux-g++ -o $*.a.p.o -c $(CFLAGS) $*.c

depend: $(LIB_SRC)
	makedepend $(LIB_SRC)

yacc_lex: y.tab.c lex.yy.c

y.tab.c: parser.y
	yacc -o y.tab.c -d parser.y

lex.yy.c: lexer.l
	flex -olex.yy.c lexer.l

parser_standalone: lex.yy.c y.tab.c tp.c element_usage.c 
	gcc $(CFLAGS) -DTP_STANDALONE=1 -o tp lex.yy.c y.tab.c tp.c element_usage.c 

clean:
	rm -f *.o $(INCPATH)/*.o $(TRPATH)/*.o
	rm -f $(LIB_TARGET) $(LIB_TARGET_ARM) $(LIB_TARGET_CPP) $(LIB_TARGET_ARM_CPP)
	rm -f y.tab.c y.tab.h lex.yy.c
        

task_construct.o:    task_construct.h element_construct.h \
                     $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_construct.o: element_construct.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_usage.o:     element_usage.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
task_error.o:        task_error.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
tp.o:                $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h

task_construct.a.o:  task_construct.h element_construct.h \
                     $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_construct.a.o: element_construct.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_usage.a.o:   element_usage.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
task_error.a.o:      task_error.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
tp.a.o:              $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h

task_construct.p.o:   task_construct.h element_construct.h \
                      $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_construct.p.o:element_construct.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
element_usage.p.o:    element_usage.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
task_error.p.o:       task_error.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
tp.p.o:               $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h

tenetAPI.o:     tenet.h transportAPI.h $(TRPATH)/tr_if.h response.h \
                $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
transportAPI.o: transportAPI.h $(TRPATH)/tr_if.h response.h \
                $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
tr_if.o:        $(TRPATH)/tr_if.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
serviceAPI.o:   $(TRPATH)/serviceAPI.h $(TRPATH)/service_if.h tenet.h \
                $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h
service_if.o:   $(TRPATH)/service_if.h $(INCPATH)/common.h $(INCPATH)/tosmsg.h $(MOTELIB)/tenet_task.h

