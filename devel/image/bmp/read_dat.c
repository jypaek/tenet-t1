
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void print_usage(argv0) {
    printf("\nUsage: %s [-d] inputfile [outputfile]\n\n", argv0);
    printf("    ex>: %s in.dat\n", argv0);
    printf(" [options]\n");
    printf("    -d           : 'input data' is in decimal, not hex.\n");
    exit(1);
}

int main(int argc, char ** argv) {

    FILE *finptr; 
    FILE *foutptr;

    char *inputfname;
    char *outputfname = NULL;

    int hex = 1;        // whether input data is in decimal or hex
    int i = 0;
    int c;

    while ((c = getopt(argc, argv, "hd")) != -1) {
        switch (c) {
            case 'd': hex = 0; break;
            default: print_usage(argv[0]);
        }
    }
    if (optind+1 < argc)
        outputfname = argv[optind+1];
    if (optind < argc)
        inputfname = argv[optind];
    else
        print_usage(argv[0]);

    if ((finptr = fopen(inputfname, "r")) == NULL) {
        printf("Input Data file error\n");
        print_usage(argv[0]);
    }

    if (outputfname == NULL) {
        foutptr = stdout;
    } else if ((foutptr = fopen (outputfname, "wb")) == NULL) {
        printf("Ouput Data file error\n");
        print_usage(argv[0]);
    }

    printf(" IN: %s, OUT: %s\n\n", inputfname, outputfname);

    while(1) {
        unsigned char value;
        if (hex)
            c = fscanf(finptr, "%hhx ", &value);
        else
            c = fscanf(finptr, "%hhd ", &value);
        if (c == EOF) 
            break;
        i++;

        fprintf(foutptr, "%02hhx ", value);
        if (i%16 == 0) fprintf(foutptr, "\n"); 
    }

    printf("\n LENGTH = %d\n\n", i);

    if (foutptr != stdout) fclose(foutptr);
    fclose(finptr);
    return 0;
}

