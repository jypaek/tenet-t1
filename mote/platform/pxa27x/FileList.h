// $Id: FileList.h,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/**
 * @file FileList.h
 * @author Junaith Ahemed Shahabdeen
 *
 * Linked List definitions and access functions for the
 * Flash File System.
 *
 */
#ifndef _FILE_LIST_H
#define _FILE_LIST_H

typedef struct list_ptr
{
  struct list_ptr *next, *prev;
} list_ptr;

#define INIT_LIST(ptr) do { \
	(ptr)->next = (ptr); (ptr)->prev = (ptr); \
} while (0)

#define get_list_entry(ptr, type, member) \
  ((type *)((char *)(ptr)-(unsigned long)(&((type *)0)->member)))

#define for_each_node_in_list(pos, n, head) \
  for (pos = (head)->next, n = pos->next; pos != (head); pos = n, n = pos->next)

#define for_each_member(pos, head, member)				\
	for (pos = get_list_entry((head)->next, typeof(*pos), member);	\
	     &pos->member != (head); 					\
	     pos = get_list_entry(pos->member.next, typeof(*pos), member))

#define for_each_prev(pos, head) \
  for (pos = (head)->prev; pos != (head); pos = pos->prev)

#define move_list_ptr(pos, head, num, cnt) \
  for (pos = (head)->next;(pos != head) && (cnt < num); pos = pos->next, cnt ++)

static inline void _add_to_list(list_ptr *node,
                               list_ptr *prev,
                               list_ptr *next)
{
  next->prev = node;
  node->next = next;
  node->prev = prev;
  prev->next = node;
}

static inline void _del_node_from_list (list_ptr *prev, list_ptr *next)
{
  next->prev = prev;
  prev->next = next;
}

static inline void add_node(list_ptr *node, list_ptr *head)
{
  _add_to_list (node, head, head->next);
}

static inline void add_node_to_tail(list_ptr *node, list_ptr *head)
{
  _add_to_list (node, head->prev, head);
}

static inline void delete_node(list_ptr *entry)
{
  _del_node_from_list(entry->prev, entry->next);
  entry->next = (void *) 0;
  entry->prev = (void *) 0;
}

static inline int is_list_empty(list_ptr *head)
{
  return head->next == head;
}

static inline void _list_join(list_ptr *list,
                              list_ptr *head)
{
  list_ptr *first = list->next;
  list_ptr *last = list->prev;
  list_ptr *at = head->next;

  first->prev = head;
  head->next = first;
  last->next = at;
  at->prev = last;
}

static inline void join_lists (list_ptr *list, 
                              list_ptr *head)
{
  if (!is_list_empty(list))
    _list_join(list, head->prev);
    //_list_join(list, head);
}

#endif
