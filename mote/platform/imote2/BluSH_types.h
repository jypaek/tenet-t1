#ifndef __BLUSH_TYPES_H
#define __BLUSH_TYPES_H
enum 
  {
    BLUSH_SUCCESS_DONE = 0,
    BLUSH_SUCCESS_NOT_DONE,
    BLUSH_FAIL
  };

typedef uint8_t BluSH_result_t;
typedef struct __BluSHdata_t{
  uint8_t *src;
  uint32_t len;
  uint8_t state;
} BluSHdata_t;
typedef BluSHdata_t * BluSHdata;
#endif
