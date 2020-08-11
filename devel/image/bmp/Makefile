
PC = dec2hex bmp2dat dat2bmp read_dat diff_dat resize_bmp

all: $(PC)

dec2hex: dec2hex.c
	gcc $^ -o dec2hex

bmp2dat: bmp2dat.c bmp.c
	gcc $^ -o bmp2dat

dat2bmp: dat2bmp.c bmp.c
	gcc $^ -o dat2bmp

read_dat: read_dat.c
	gcc $^ -o read_dat

diff_dat: diff_dat.c
	gcc $^ -o diff_dat

resize_bmp: resize_bmp.c bmp.c
	gcc $^ -o resize_bmp

clean:
	rm -f $(PC)

