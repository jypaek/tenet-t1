/*
Author Ben Greenstein.

This provides queuing functionality for asynchronous events so you can
queue them up and service them at your leisure. It is useful in the
context of sensing and messaging. 
I don't know if it's currently in use.
*/
interface AsyncToSync {
  command void init();
  async command result_t push(void *d);
  event void popped(void *d);
}
