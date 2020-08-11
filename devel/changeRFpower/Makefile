
PC= changeRFpower   # default binary name
ARM= achangeRFpower # for arm processors (e.g. Stargates), using arm-linux-gcc


include ../../apps/Makerules

CFLAGS += -I../../master/transport

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
changeRFpower: changeRFpower.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
achangeRFpower: changeRFpower.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)

