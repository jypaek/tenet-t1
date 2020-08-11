#ifndef __ASSERT_H__
#define __ASSERT_H__

#undef assert
#ifdef NDEBUG
#define assert(e) ((void)0)
#else
extern void printAssertMsg(const char* file, uint32_t line, char *condition) __attribute__((C));
#define assert(e) ((void)((e) || (printAssertMsg(__FILE__, (int)__LINE__, #e), 0)))
#endif

#endif //__ASSERT_H__

