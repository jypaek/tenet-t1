
PC = odetect

all: $(PC)

CFILES += ObjectDetectionM.c segmentM.c

odetect: odetect.c $(CFILES)
	gcc $^ -o odetect

clean:
	rm -f $(PC)

