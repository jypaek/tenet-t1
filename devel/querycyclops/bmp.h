
#ifndef __BMP_H__
#define __BMP_H__

int convert_data_to_bmp(char *imageData, int format, int width, int height, char *filename);
int convert_bmp_to_dat(char *filename, int *format, int *width, int *height, char **returnBuf);

#endif

