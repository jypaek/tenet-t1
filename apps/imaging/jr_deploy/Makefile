
### For James Reserve Deployment (Sep. 2007)
PC = jr_deploy1 jr_deploy2 genhtmpage
ARM = ajr_deploy1 ajr_deploy2 

MASTERPATH = ../../../master
include ../../Makerules


MOTEPATH = ../../../mote
CYCLOPSLIB = $(MOTEPATH)/lib/cyclops
NEURONPATH = $(MOTEPATH)/lib/cyclops/neuron

CFLAGS += -I. -I$(CYCLOPSLIB) -I$(NEURONPATH)
CFLAGS += -I../
CFILES += $(CYCLOPSLIB)/cyclops_query.c
CFILES += ../cyapp_util.c
CFILES += ../bmp.c


all: tenetlib pc

pc: $(PC)
arm: $(ARM)


# for JR deployment
jr_deploy1: jr_deploy1.c $(CFILES) $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@
jr_deploy2: jr_deploy2.c $(CFILES) $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

ajr_deploy1: jr_deploy1.c $(CFILES) $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@
ajr_deploy2: jr_deploy2.c $(CFILES) $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

genhtmpage: genhtmpage.c
	gcc -g $^ -o $@


# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../../master/tasklib; make)
    
clean:
	rm -f $(PC) $(ARM)


