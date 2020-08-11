/*
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef __SSYNC_MACROS_H__
#define __SSYNC_MACROS_H__


#define SSYNC_PUB_TYPESAFE_INLINES(name,type,tname,keylen) \
 \
typedef struct name##_table_s { \
  ssync_elt_t header; \
  type name; \
} name##_table_t; \
 \
static inline int name##_pub(char *prefix, name##_table_t *table, int count, \
                             flow_id_t *fid) \
{ \
  ssync_pub_t *pub = \
    ssync_pub_aux(prefix, tname, sizeof(name##_table_t), sizeof(type), keylen, \
                  fid, (char*)table, count); \
  if (pub) { \
    ssync_pub_issue(pub); \
    ssync_pub_free(pub); \
    return 0; \
  } \
  return -1; \
} \
 \
typedef int (* name##_sub_cb_t) (ssync_sub_t *sub, name##_table_t *table, \
                               int count, void *data); \
 \
int name##_adaptor(ssync_sub_t *sub, ssync_elt_t *header, int count); \
 \
static inline int name##_sub_open(char *prefix, name##_sub_cb_t cb, void *data, ssync_sub_t **ref) \
{ \
  ssync_sub_opts_t opts = { \
    prefix_name: prefix, \
    type_name: tname, \
    record_len: sizeof(type), \
    key_len: keylen, \
    cb: name##_adaptor, \
    data: data, \
    data2: cb \
  }; \
  return ssync_sub_open(&opts, ref); \
} \
static inline int name##_sub_open_full(char *prefix, name##_sub_cb_t cb, void *data, ssync_sub_opts_t *opts, ssync_sub_t **ref) \
{ \
  ssync_sub_opts_t _opts = { \
    prefix_name: prefix, \
    type_name: tname, \
    record_len: sizeof(type), \
    key_len: keylen, \
    cb: name##_adaptor, \
    data: data, \
    data2: cb, \
    reread_period: opts->reread_period, \
    read_refractory: opts->read_refractory \
  }; \
  return ssync_sub_open(&_opts, ref); \
}

#define SSYNC_PUB_TYPESAFE_FUNCS(name,type) \
int name##_adaptor(ssync_sub_t *sub, ssync_elt_t *header, int count) \
{ return ((name##_sub_cb_t)ssync_sub_data2(sub)) \
       (sub, (name##_table_t *)header, count, ssync_sub_data(sub)); \
}


#endif
