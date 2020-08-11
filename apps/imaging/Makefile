
PC    = imaging    # default binary name
ARM   = aimaging   # for arm processors (e.g. Stargates), using arm-linux-gcc
TOOLS = bmp2dat dat2bmp
ATOOLS = abmp2dat adat2bmp

include ../Makerules


MOTEPATH = ../../mote
CYCLOPSLIB = $(MOTEPATH)/lib/cyclops
NEURONPATH = $(MOTEPATH)/lib/cyclops/neuron


CFLAGS += -I. -I$(CYCLOPSLIB) -I$(NEURONPATH)

CFILES += $(CYCLOPSLIB)/cyclops_query.c
CFILES += cyapp_util.c
CFILES += bmp.c


all: tenetlib pc jr $(TOOLS) simple_image


pc: $(PC) jr
arm: $(ARM) jrarm $(ATOOLS)


# default compilation
imaging: imaging.c $(CFILES) $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@

# for arm processors (e.g. Stargates), using arm-linux-gcc
aimaging: imaging.c $(CFILES) $(TENET_LIB_ARM)
	arm-linux-gcc -O1 -Wall -g $(CFLAGS) $^ -o $@


dat2bmp: dat2bmp.c bmp.c
	gcc $^ -o dat2bmp

bmp2dat: bmp2dat.c bmp.c
	gcc $^ -o bmp2dat

adat2bmp: dat2bmp.c bmp.c
	arm-linux-gcc $^ -o adat2bmp

abmp2dat: bmp2dat.c bmp.c
	arm-linux-gcc $^ -o abmp2dat

jr:
	$(MAKE) -C jr_deploy -f Makefile
jrarm:
	$(MAKE) -C jr_deploy -f Makefile arm

simple_image: simple_image.c $(CFILES) $(TENET_LIB)
	gcc -O1 -Wall -g $(CFLAGS) $^ -o $@


# need to compile the tenet master-side library, if not done before
tenetlib:
	(cd ../../master/tasklib; make)


clean:
	rm -f $(PC) $(ARM)
	$(MAKE) -C jr_deploy -f Makefile clean


