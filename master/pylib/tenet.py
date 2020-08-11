# Tenet module
#
# Selects appropriate transport module and exports the
# functions defined in transport module. Also packages the response
# received into an object of type "response"
#
#@author Omprakash Gnawali

import sys

v = sys.version_info[1]

if sys.platform == 'cygwin':
    if v == 5:
        import transport_py25 as transport
    else:
        import transport_py24 as transport
else:
    import transport

send_task = transport.send_task
get_error_code = transport.get_error_code
config_transport = transport.config_transport
delete_task = transport.delete_task

class response:
    def __init__(self):
        self.mote_addr = -1
        self.tid = 0
        self.attrs = []

    def __str__(self):
        return "[moteaddr=%d, tid=%d, attrs=%s]" % (self.mote_addr, self.tid, self.attrs)

def read_response(timeout):
    f = transport.read_response(timeout)


    r = response()

    if len(f) > 0:
        r.mote_addr = f[1]
        r.tid = f[2]
        r.attrs = f[3]

    return r
