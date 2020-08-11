
RT_TARGET     = router  # default binary name
RT_TARGET_ARM = arouter # for arm processors (e.g. Stargates)


TENETPATH = ../..
MASTERPATH = ..

INCPATH = $(MASTERPATH)/include
SFPATH = $(TENETPATH)/tools/sf
TRDPATH = $(TENETPATH)/master/trd

TENETMOTELIB = $(TENETPATH)/mote/lib
MOTETRDPATH = $(TENETMOTELIB)/trd

MOTELIB = $(MASTERPATH)/../mote/lib
MOTEROUTERPATH = $(MOTELIB)/router


SRCS += Main.cpp Network.cpp TenetRouter.cpp TenetTransport.cpp TCP_Server.cpp TCP_Client.cpp UDP_Server.cpp UDP_Client.cpp IPRT_Manager.cpp MRT_Manager.cpp TR_Common.cpp TenetSFClient.cpp SFClient.cpp File.cpp
SRCS += $(SFPATH)/sfsource.c



include $(INCPATH)/Makerules



CFLAGS += -O1 -Wall -g
#SOCKLIB	= 
#CFLAGS += $(SOCKLIB) -lpthread
CFLAGS += -I$(INCPATH) -I$(SFPATH)
CFLAGS += -I$(MOTELIB) -I$(MOTETRDPATH) -I$(MOTEROUTERPATH)
#CFLAGS += -DDEBUG_MODE


# default is not to compile for arm.
all: pc

pc: $(RT_TARGET)

arm: $(RT_TARGET_ARM)

# default compilation
router: $(SRCS)
	g++ $(CFLAGS) $^ -o $@
    
# for arm processors (e.g. Stargates)
arouter: $(SRCS)
	arm-linux-g++ $(CFLAGS) $^ -o $@

clean:
	rm -rf	*.o $(RT_TARGET) $(RT_TARGET_ARM)
	
