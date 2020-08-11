
PC= send_task   # default binary name
ARM= asend_task # for arm processors (e.g. Stargates), using arm-linux-gcc

include ../Makerules

all: tenetlib pc

pc: $(PC)
arm: $(ARM)

# default compilation
send_task: send_task.c $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
asend_task: send_task.c $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# need to compile the tenet master-side library, if not done before
tenetlib: 
	(cd ../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)


