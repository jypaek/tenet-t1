
PC= example_app blink    # default binary name
ARM= aexample_app ablink # for arm processors (e.g. Stargates), using arm-linux-gcc

include ../Makerules

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
example_app: example_app.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@
blink: blink.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
aexample_app: example_app.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@
ablink: blink.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)

