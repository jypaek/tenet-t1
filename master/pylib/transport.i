/* $Id: transport.i,v 1.3 2007-03-02 00:02:16 om_p Exp $ */
/**
 * transport.i
 * 
 * SWIG interface file to enable calls to functions defined in the
 * transport binaries
 *
 * @author Omprakash Gnawali
 **/

%module transport

%{
#include "response.h"
%}

%typemap(python,out) response*
{
  PyObject *p, *attrlist, *attrvallist;
  int i, j;
  attr_node *n;
  p = PyDict_New();
  if ($1) {
      PyDict_SetItem(p, PyInt_FromLong(1), PyInt_FromLong($1->mote_addr));
      PyDict_SetItem(p, PyInt_FromLong(2), PyInt_FromLong($1->tid));

      attrlist = PyDict_New();
      n = $1->head;
      i = 0;
      while (i < $1->length) {
	 if (n->length == 1) {
              PyDict_SetItem(attrlist, PyInt_FromLong(n->type), PyInt_FromLong(n->value[0]));
         } else {
              attrvallist = PyList_New(n->length);
              for (j = 0; j < n->length; j++) {
                 PyList_SetItem(attrvallist, j, PyInt_FromLong(n->value[j]));
              }
              PyDict_SetItem(attrlist, PyInt_FromLong(n->type), attrvallist);
         }
         n = n->next; i++;
      }
      PyDict_SetItem(p, PyInt_FromLong(3), attrlist);

      free($1);
  }
  $result = p;
}


int send_task(char *task_string);
void delete_task(int t_id);
response* read_response(int militimeout);
void config_transport(char *host, int port);
int open_transport();
void setVerbose(void);
int get_error_code();
