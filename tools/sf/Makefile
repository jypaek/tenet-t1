PROGRAMS=sf sflisten

all: pc

pc:
	gcc  -O1 -Wall -g -o sf sf.c serialsource.c sfsource.c platform.c
	gcc -O1 -Wall -g -o sflisten sflisten.c sfsource.c platform.c
	gcc -O1 -Wall -g -o seriallisten seriallisten.c serialsource.c platform.c

arm: 
	arm-linux-gcc  -O1 -Wall -g -o asf sf.c serialsource.c sfsource.c platform.c
	arm-linux-gcc -O1 -Wall -g -o asflisten sflisten.c sfsource.c platform.c


clean:
	rm -f $(PROGRAMS) *.o sf sflisten asf asflisten

