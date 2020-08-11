
PC= coverIt   # default binary name
ARM= acoverIt # for arm processors (e.g. Stargates), using arm-linux-gcc

include ../Makerules

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
coverIt: coverIt.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
acoverIt: coverIt.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)

