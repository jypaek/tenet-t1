
PC= collect   # default binary name
ARM= acollect # for arm processors (e.g. Stargates), using arm-linux-gcc

include ../Makerules

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
collect: collect.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ -lm

# for arm processors (e.g. Stargates), using arm-linux-gcc
acollect: collect.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@ -lm

# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)

