
/**
 * Define two functions: 'nxs()' and 'nxl()', 
 * - just a wrapper around ntohs and ntohl.
 *
 * Dummy typedef aliases to let PC-side code compile with nesC header files
 * which may include 'nx_' structures.
 * - let mote and master code share same header files with
 *   endianess-defined structs defined in nesC.
 *   (both big-endian & little-endian)
 *
 * @author Jeongyeup Paek
 * @modified 10/30/2007
 **/

#ifndef _NX_H_
#define _NX_H_

// you can disable nx-type conversion using compile-time def. of below
#ifndef DO_NOT_CONVERT_NX_TYPE
#define DO_NOT_CONVERT_NX_TYPE 0
#endif

#ifdef BUILDING_PC_SIDE

#include <sys/types.h>  // for uint??_t
#include <arpa/inet.h>  // for ntohs, ntohl

#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif

#define nxs(a) (DO_NOT_CONVERT_NX_TYPE == 1 ? a : ntohs(a))
#define nxl(a) (DO_NOT_CONVERT_NX_TYPE == 1 ? a : ntohl(a))
#define hxs(a) (DO_NOT_CONVERT_NX_TYPE == 1 ? a : htons(a))
#define hxl(a) (DO_NOT_CONVERT_NX_TYPE == 1 ? a : htonl(a))

#else   // mote

#define nxs(a) (nx_uint16_t)a
#define nxl(a) (nx_uint32_t)a
#define hxs(a) (nx_uint16_t)a
#define hxl(a) (nx_uint32_t)a

#endif

/**
 * BIG endian
 * - note that host software must use 'ntohs' and 'ntohl' functions
 *   defined in <arpa/inet.h> to access the types below
 **/
#define nx_struct struct

typedef uint8_t nx_uint8_t;
typedef uint16_t nx_uint16_t;
typedef uint32_t nx_uint32_t;

typedef int8_t nx_int8_t;
typedef int16_t nx_int16_t;
typedef int32_t nx_int32_t;


/**
 * little endian
 * - currently, the machines that we usually use (e.g. intel~~, or stargate)
 *   does not require any byte-ordering conversion for little endian.
 **/
typedef uint8_t nxle_uint8_t;
typedef uint16_t nxle_uint16_t;
typedef uint32_t nxle_uint32_t;

typedef int8_t nxle_int8_t;
typedef int16_t nxle_int16_t;
typedef int32_t nxle_int32_t;

#endif

