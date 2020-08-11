all: tenetbin tenetpylib

arm:

tenetpylib: transport.i tenetbin
	swig -python transport.i
	gcc -shared -DCC2420_TOS_MSG_FORMAT=1 -DBUILDING_PC_SIDE \
	-DTOSH_DATA_LENGTH=80 \
	-I../include \
	-I../../tools/sf \
	-I../../mote/lib \
	-I../../mote/lib/cyclops \
	-I../tasklib \
	-I../transport \
	-I/usr/include/python2.3 \
	-I/usr/include/python2.4 \
	../transport/service_if.c \
	../transport/serviceAPI.c \
	../transport/tr_if.c \
	../tasklib/response.c \
	../tasklib/transportAPI.c \
	../include/tosmsg.c \
	../include/timeval.c \
	../../tools/sf/sfsource.c \
	../tasklib/task_error.c \
	../tasklib/task_construct.c  \
	../tasklib/element_construct.c \
	../tasklib/tp.c \
	../tasklib/lex.yy.c \
	../tasklib/y.tab.c \
	../tasklib/element_usage.c \
	transport_wrap.c \
	 -o _transport.so

tenetbin:
	(cd ../tasklib; make)
	(cd ../../tools/sf; make)
	(cd ../transport; make)

clean:
	rm -f *.so *.o *.c *.pyc *.dll transport.py
