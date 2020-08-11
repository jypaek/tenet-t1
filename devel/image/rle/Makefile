
PC = simple_rle simple_trle packbit_rle packbit_trle packbit_ftrle

all: $(PC)

simple_rle: simple_rle.c
	gcc $^ -o simple_rle

simple_trle: simple_trle.c
	gcc $^ -o simple_trle

packbit_rle: packbit_rle.c
	gcc $^ -o packbit_rle

packbit_trle: packbit_trle.c
	gcc $^ -o packbit_trle

packbit_ftrle: packbit_ftrle.c
	gcc $^ -o packbit_ftrle

clean:
	rm -f $(PC)

