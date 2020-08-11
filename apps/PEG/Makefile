PROGRAMS= PEG

include ../Makerules

CFLAGS += -I../../sys/sf
CFLAGS += -I/usr/local/include/
CFLAGS += -L/usr/local/lib/

all: tenetlib $(PROGRAMS)

sampleRSSI: sampleRSSI.c querytime.c $(TENET_LIB) 
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

localization: localization.c queue.c
	gcc -O2 -Wall -g -DTEST $^ -o $@

PEG: pegApp.c queue.c planning.c plan_vfh.c setposition.c localization.c $(TENET_LIB_CPP)
	g++ -O1 -Wall -g $(CFLAGS) $^ -o $@ -lplayerc -lm

#asampleRSSI: $(TENET_LIB) $(TRANSPORTFILES) $(TENETNOTASKFILES)
#	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

tenetlib:
	(cd ../../master/tasklib; make)

clean:
	rm -f $(PROGRAMS)


