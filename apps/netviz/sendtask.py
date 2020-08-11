import sys
sys.path.append('../../master/pylib');
import tenet

task = sys.argv[1]

tid = tenet.send_task(task)

if tenet.get_error_code() != 0:
    print 'problem sending the task'
else:
    r = tenet.read_response(10000)
    while r.mote_addr != -1:
        print 'node', r.mote_addr, r.attrs
        r = tenet.read_response(10000)
    tenet.delete_task(tid)

