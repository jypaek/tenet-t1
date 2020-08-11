
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void print_usage(argv0) {
    printf("\nUsage: %s [-d] [-o offset] file1 file2 [outfile]\n\n", argv0);
    printf("    ex>: %s in1.dat in2.dat\n", argv0);
    printf("    ex>: %s in1.dat in2.dat out.dat\n", argv0);
    printf(" [options]\n");
    printf("    -d           : 'input data' is in decimal, not hex.\n");
    exit(1);
}

int main(int argc, char ** argv) {

    FILE *fin1ptr; 
    FILE *fin2ptr; 
    FILE *foutptr;

    char *inputfname1;
    char *inputfname2;
    char *outputfname = NULL;

    int hex = 1;        // whether input data is in decimal or hex
    unsigned char offset = 0;

    int i;
    int c;

    while ((c = getopt(argc, argv, "do:")) != -1) {
        switch (c) {
            case 'd': hex = 0; break;
            case 'o': offset = atoi(optarg); break;
            default: print_usage(argv[0]);
        }
    }
    if (optind+2 < argc)
        outputfname = argv[optind+2];
    if (optind+1 < argc) {
        inputfname1 = argv[optind];
        inputfname2 = argv[optind+1];
    } else
        print_usage(argv[0]);

    if ((fin1ptr = fopen(inputfname1, "r")) == NULL) {
        printf("Input Data file error 1\n");
        print_usage(argv[0]);
    } else if ((fin2ptr = fopen(inputfname2, "r")) == NULL) {
        printf("Input Data file error 2\n");
        print_usage(argv[0]);
    }

    if (outputfname == NULL) {
        foutptr = stdout;
    } else if ((foutptr = fopen (outputfname, "wb")) == NULL) {
        printf("Ouput Data file error\n");
        print_usage(argv[0]);
    }

    printf(" IN: %s, IN: %s, OUT: %s\n\n",
            inputfname1, inputfname2, outputfname);

    i = 0;

    while(1) {
        unsigned char a, b;
        int ok1, ok2;
        if (hex) {
            ok1 = fscanf(fin1ptr,"%hhx ", &a);
            ok2 = fscanf(fin2ptr,"%hhx ", &b);
        } else {
            ok1 = fscanf(fin1ptr,"%hhd ", &a);
            ok2 = fscanf(fin2ptr,"%hhd ", &b);
        }
        if (ok1 == EOF || ok2 == EOF)
            break;
        i++;

        fprintf(foutptr, "%02hhx ", (unsigned char)(a - b + offset));
        if (i%16 == 0)
           fprintf(foutptr, "\n"); 
    }

    if (foutptr != stdout) fclose(foutptr);
    fclose(fin1ptr);
    fclose(fin2ptr);
    return 0;
}

