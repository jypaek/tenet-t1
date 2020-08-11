#include "tos_emstar.h"

fp_list_t fplist_g;


fp_list_t *get_fplist()
{
//	printf("%x\n", &fplist_g);
    return &fplist_g;
}

