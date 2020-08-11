
PROGRAMS= ftsplisten
ARM= aftsplisten

#SFPATH = WRITE_YOUR_T1_SF_PATH_HERE
SFPATH = ../../tools/sf

CFILES += $(SFPATH)/sfsource.c $(SFPATH)/serialsource.c

CFLAGS += -I$(SFPATH)
CFLAGS += -I../../master/include
CFLAGS += -I../../mote/test/TestTimeSync
CFLAGS += -I../../mote/lib/timesync

# If you are using mica2 (or micaz with pkt format conversion),
# then you might need to uncomment below line.
CFLAGS += -DOLD_TOS_MSG_FORMAT=1

all: $(PROGRAMS)
arm: aftsplisten

ftsplisten: ftsplisten.c $(CFILES)
	gcc -O1 -Wall $(CFLAGS) -g -o $@ ftsplisten.c $(CFILES)

# For ARM
aftsplisten: ftsplisten.c $(CFILES)
	arm-linux-gcc -O1 -Wall $(CFLAGS) -g -o $@ ftsplisten.c $(CFILES)

clean:
	rm -f $(PROGRAMS) $(ARM)

