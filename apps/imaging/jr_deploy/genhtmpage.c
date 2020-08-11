#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_NUMBER_OF_MOTES	64

int main (int argc, char **argv)
{
	char temp[256];
	char *q;
	int i, idx, offset;
	int TOTAL_NUMBER_OF_MOTES = 8;	// default;
	char TARGET_HTML[256];
	char *szMote[MAX_NUMBER_OF_MOTES];
	char *szFileName[MAX_NUMBER_OF_MOTES];
	char *szTime[MAX_NUMBER_OF_MOTES];
    char path[50];
    time_t m_time = time(NULL);

	if (argc < 3) {
		printf("You should run this program with args, using 'update.sh' script\n");
		exit(1);
	}

	// arg[1] : target html filename
	// arg[2] : number of entries (motename, filename, time)
    strcpy(TARGET_HTML,	argv[1]);
	TOTAL_NUMBER_OF_MOTES = atoi(argv[2]);
    strcpy(path, argv[3]);
    offset = 4;

	// put the data into array.
	for (i = 0; i < TOTAL_NUMBER_OF_MOTES; i++) {
		// mote name
		szMote[i] = strdup(argv[offset+3*i]);

		// file name
		szFileName[i] = strdup(argv[offset+3*i+1]);

		// Time
		temp[0] = 0;
		idx = offset+3*i+2;
		if (q = strchr(argv[idx], '.'), q) {
			strncpy(temp, argv[idx], q - argv[idx]);
			temp[q-argv[idx]] = 0;
			szTime[i] = strdup(temp);
		} else {
			szTime[i] = strdup(argv[idx]);
		}
	}

	// start to make a web page
	printf("<html>\n");
	printf("\n<head>\n\n");
	printf("<title>JR Tenet/Cyclops Image Viewer</title>\n");
	printf("<meta http-equiv=\"refresh\" content=\"10\">\n");
	printf("\n</head>\n\n");
    /* below 6 lines for javascript-based auto refresh */
	//printf("<script language=\"JavaScript\">\n");
	//printf("function move() {\n");
	//printf("window.location = '%s';\n", TARGET_HTML);
	//printf("}\n");
	//printf("</script>\n");
	//printf("<body onload=\"timer=setTimeout('move()', 10000)\">\n");
	printf("\n<body>\n\n");
	printf("<h2>JR Tenet/Cyclops Image Viewer</h2><hr>\n");
	printf("<table border=0 cellpadding=5 cellspacing=1>\n");
	printf("<tr>\n");
	for (i = 0; i < TOTAL_NUMBER_OF_MOTES; i++) {
		printf("<td><center>\n");
        if ((i == 0) || (strcmp(szMote[i-1], szMote[i]) != 0))
    		printf("<h3>%s</h3>\n", szMote[i]);
        else
    		printf("<h5><font color=grey>%s-prev</font></h5>\n", szMote[i]);
		printf("<img src=\"%s/%s\"><br><br>\n", path, szFileName[i]);
		printf("<font size=2>", szFileName[i]);
		printf("%s<br>", szFileName[i]);
		printf("%s<br>", szTime[i]);
		printf("</font>\n");
		printf("</center></td>\n");
		if (((i+1)%4) == 0) {
			printf("</tr>\n");
			printf("<tr>\n");
		}
	}
	printf("</tr>\n");
	printf("</table>\n");
    printf("<hr>\n");
    printf("<a href=\"file:///home/jpaek/public_cvs/tenet/apps/imaging/data\"><h5>List of image files</h5></a>\n");
    printf("<small>Last refreshed: %s </small>", asctime(localtime(&m_time)));
	printf("\n</body>\n\n");

	// release allocated buffers.
	for (i = 0; i < TOTAL_NUMBER_OF_MOTES; i++) {
		if (szMote[i]) free(szMote[i]);
		if (szFileName[i]) free(szFileName[i]);
		if (szTime[i]) free(szTime[i]);
	}

    fflush(stdout);
	return 0;
}
