#ifndef STDDBG_H
#define STDDBG_H

//#define stddbg(args...) do{dbg(DBG_USR3, "%s [%d] - ", __FILE__, __LINE__); fprintf(stdout, args); fprintf(stdout, "\n");}while(0)

#define stddbg(format, args...) do{dbg(DBG_USR3, "%s [%d] - " format "\n", __FILE__, __LINE__, args);}while(0)
#define stddbg1(format) do{dbg(DBG_USR3, "%s [%d] - " format "\n", __FILE__, __LINE__);}while(0)

#endif
