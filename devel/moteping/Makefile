
PC= mping mtracert 
ARM=amping amtracert

include ../../apps/Makerules

CFLAGS += -I../../master/transport

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

mping: ping.c $(TENET_LIB) 
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

amping: ping.c $(TENET_LIB_ARM) 
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

mtracert: tracert.c $(TENET_LIB) 
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

amtracert: tracert.c $(TENET_LIB_ARM) 
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@
    
# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)


