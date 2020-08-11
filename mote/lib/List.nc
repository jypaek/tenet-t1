/**
 * List Interface
 * 
 * Functions provided by List ADU. The implementation is in
 * TaskLib.nc.
 *
 * @author Ben Greenstein
 **/

includes tenet_task;
interface List {
  command void init(list_t *list);
  command bool push(list_t *list, void *data);
  command bool remove(list_t *list, void *data);
  command void *pop(list_t *list);
  command void iterate(list_t *list, operator_fn_t op_fn, void *meta);
  command bool empty(list_t *list);
}
