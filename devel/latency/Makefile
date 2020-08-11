
PC= latency   # default binary name
ARM= alatency # for arm processors (e.g. Stargates), using arm-linux-gcc


include ../../apps/Makerules

CFLAGS += -I../../master/transport

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
latency: latency.c LinkedList.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
alatency: latency.c LinkedList.c  $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)

