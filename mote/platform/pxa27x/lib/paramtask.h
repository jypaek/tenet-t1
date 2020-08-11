#ifndef __PARAMTASK_H__
#define __PARAMTASK_H__

unsigned char TOS_parampost(void (*tp) (), uint32_t arg) __attribute__((C,spontaneous));
  
#define DEFINE_PARAMTASK(funcname) \
void _##funcname##veneer(){\
uint32_t argument;\
atomic{popqueue(&paramtaskQueue,&argument);}\
funcname(argument);}
  
#define POST_PARAMTASK(funcname, arg) TOS_parampost(_##funcname##veneer,(uint32_t)arg)




#endif // __PARAMTASK_H__
