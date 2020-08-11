# pingtree.py
#
# This application sends a task to the network asking each mote to send
# its parent id. This program, after a timeout, prints a textual
# representation of the routing tree. This is useful for diagnostics.
#
# @author Omprakash Gnawali

import sys
sys.path.append('../../master/pylib');
import tenet

forest = {}
def addedge(parent, child):
    if forest.has_key(parent):
        if forest[parent].count(child) < 1:
            forest[parent].append(child)
        return
    forest[parent] = [child]

def isroot(r):
    for k, v in forest.iteritems():
        if forest[k].count(r) > 0:
            return 0
    return 1

def printtree(node, level):
    if level == 0:
        print '  ',node
    else:
        print (level-5) * ' ', '|',5 * '-', node
    if not forest.has_key(node):
        return
    else:
        for n in forest[node]:
            printtree(n, level+8)

def printforest():
    for k, v in forest.iteritems():
        if isroot(k) == 1:
            printtree(k, 0)

tid = tenet.send_task('wait(2000)->nexthop(55)->sendpkt(1)')

if tenet.get_error_code() != 0:
    print 'problem sending the task'
else:
    r = tenet.read_response(5000)
    while r.mote_addr != -1:
        if r.attrs.has_key(55):
            print 'node', r.mote_addr, '->', r.attrs[55]
            addedge(r.attrs[55], r.mote_addr)
            r = tenet.read_response(5000)

print 'Printing the forest'
printforest()
