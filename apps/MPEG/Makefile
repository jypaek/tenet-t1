PROGRAMS= els generateLocationTable clientLS 

include ../Makerules

all: tenetlib $(PROGRAMS)

mpeg: mpeg.c queue.c planning.c localization.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ -lplayerc -lm

locationServer: locationServer.c client.c sfsource.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

clientLS: clientLS.c sfsource.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

mpeg2: mpeg2.c planning.c sfsource.c
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ -lplayerc -lm

els: evaderLocationServer.c localization.c queue.c client.c sfsource.c log.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

generateLocationTable: generateLocationTable.c
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

tenetlib: 
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PROGRAMS)


