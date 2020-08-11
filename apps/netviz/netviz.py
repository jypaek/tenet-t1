# Netviz displays the routing tree, node attributes, and
# TelosB light sensor values in a Tenet
# Netviz is an example Tenet application written in Python
# author: Omprakash Gnawali
# contact: om_p@enl.usc.edu

import tkFont
import time
import sys
sys.path.append('../../master/pylib')
import tenet
import tkColorChooser
import tkFileDialog

try:
   from Tkinter import *
except ImportError:
    print "NetViz requires Tkinter module. Please install Tkinter and try again."
    sys.exit()

v1 = sys.version_info[0]
v2 = sys.version_info[1]


if ((sys.platform == 'cygwin' or sys.platform == 'win32') and v1 == 2 and v2 < 4):
    print "On Cygwin/Windows platform, NetViz requires at least Python 2.4."
    sys.exit()

if v1 < 2 or v2 < 3:
    print "NetViz requires at least Python 2.3. Please install Python 2.5 and try again."
    sys.exit()

root = Tk()
root.title("TeNetViz")
root.config(bg='#ffffff')
c = Canvas(root, width=1600, height=100)
c.config(bg='#ffffff')
splashfont = tkFont.Font(root, ('helvetica', 30, tkFont.NORMAL))
titlefont=tkFont.Font(root, ('helvetica', 15, tkFont.NORMAL))
nodefontsize = 10
nodefont=tkFont.Font(root, ('helvetica', nodefontsize, tkFont.NORMAL))
datafont=tkFont.Font(root, ('courier', 10, tkFont.BOLD))
picture = PhotoImage(file="tenet.gif")
image = Label(root, image=picture)
label = Label(root, text='TeNetViz', font=splashfont)
label.config(bg='#ffffff')
label.pack()
image.pack()

class StatusBar(Frame):
   def __init__(self, master):
      Frame.__init__(self, master)
      self.label = Label(self, bd=1, relief=SUNKEN, anchor=W)
      self.label.pack(fill=X)
   
   def set(self, format, *args):
      self.label.config(text=format % args)
      self.label.update_idletasks()
   
   def clear(self):
      self.label.config(text="")
      self.label.update_idletasks()


s = StatusBar(root)
s.pack(side=BOTTOM, fill=X)
s.set("Ready")

class node:
    def __init__(self, id):
        self.x = 0
        self.y = 0
        self.id = id
        self.width = 0
        self.level = 0
        self.parentx = 0
        self.parent = 0

        self.info = []

class sysattr:
   def __init__(self, name, id, formatfn):
      self.name = name
      self.id = id
      self.formatfn = formatfn


def echo(x):
   return x

def displaybool(x):
   if x == 1:
      return "True"
   else:
      return "False"

def displaytime(x):
   return "0x%04X%04X" % (x[1], x[0])

def displayplatform(x):
   if x == 1:
      return "TelosB"
   else:
      return "MicaZ"

def displaymemory(x):
   return "Now: %d, Max: %d" % (x[0], x[2])

attrs = []
attrs.append( sysattr("Routing Parent", 1, echo))
attrs.append( sysattr("Global Time", 2, displaytime))
attrs.append( sysattr("Local Time", 3, displaytime))
attrs.append( sysattr("Memory Usage (B)", 4, displaymemory))
attrs.append( sysattr("Number of Tasks", 5, echo))
attrs.append( sysattr("Number of Active Tasks", 6, echo))
attrs.append( sysattr("Children", 7, echo))
attrs.append( sysattr("LEDs", 9, echo))
attrs.append( sysattr("RF Power", 10, echo))
attrs.append( sysattr("RF Channel", 11, echo))
attrs.append( sysattr("Is Time Synchronized?", 12, displaybool))
attrs.append( sysattr("Node ID", 13, echo))
attrs.append( sysattr("Global Time (ms)", 14, echo))
attrs.append( sysattr("Local Time (ms)", 15, echo))
attrs.append( sysattr("Linkquality to Parent", 16, echo))
attrs.append( sysattr("Platform", 17, displayplatform))
attrs.append( sysattr("Clock Frequency", 18, echo))

def attribute_idx(a):
   global attrs
   i = 0;
   for item in attrs:
      if item.id == a:
         return i
      i += 1
   return -1


curtask = [1, 4, 5, 16]
newtask = [1, 4, 5, 16]

import Dialog
host = "localhost"
port = "9998"
viewtree = 1
viewlight = 0
tidinfo = -1
tidlight = -1

linewidth1 = 500
linewidth2 = 250
linewidth3 = 125
refreshrate = 120000

def task_str(task):
    stask = ""
    for item in curtask:
        stask += "get(" + str(item+10) + ", " + str(item) + ")->"
    stask += "sendpkt(1)"
    return stask

forest = {}
forestoffset = 0
nodelight = {}
nodedata = {}

def initforest():
    global forest
    global forestoffset
    global nodelight
    forest = {}
    forestoffset = 0
    nodelight = {}

def addedge(parent, child):

    c = node(child)
    cont = 1
    for k, v in forest.iteritems():
        if cont != 1:
            break
        if k.id == child:
            c = k
        for n in v:
            if n.id == child:
                c = forest[k].pop(forest[k].index(n))
                cont = 0
                break
    
    for k, v in forest.iteritems():
        if k.id == parent:
            forest[k].append(c)
            return c
    for k, v in forest.iteritems():
        for n in v:
            if n.id == parent:
                c.level = n.level + 1
                if forest.has_key(n):
                    forest[n].append(c)
                else:
                    forest[n] = [c]
                return c
    c.level = 1
    forest[node(parent)] = [c]
    return c


def isloop(n):
    loopvisited = {}
    queue = []
    queue.append(n)
    while (len(queue) > 0):
        node = queue.pop()
        if forest.has_key(node):
            for k in forest[node]:
                if loopvisited.has_key(k.id):
                    print 'loop detected'
                    return 1
                loopvisited[k.id] = 1
                queue.append(k)

def isroot(r):
    for k, v in forest.iteritems():
        for n in v:
            if n.id == r.id:
                if isloop(n) == 1:
                    return 1
    
    for k, v in forest.iteritems():
        for n in v:
            if n.id == r.id:
                return 0
    return 1

def printtree(node, level):
    if level == 0:
        print '  ',node.id
    else:
        print (level-5) * ' ', '|',5 * '-', node.id
    if not forest.has_key(node):
        return
    else:
        for n in forest[node]:
            printtree(n, level+8)


def printforest():
    for k, v in forest.iteritems():
        if isroot(k) == 1:
            printtree(k, 0)


def annotatetree(node, level, visited):
    if visited.has_key(node.id):
        return
    visited[node.id] = 1
    node.level = level
    if forest.has_key(node):
        if len(forest[node]) == 0:
            node.width = 1
        else:            
            node.width = 0
        for n in forest[node]:
            annotatetree(n, level+1, visited)
            node.width += n.width
    else:
        node.width = 1

def annotateforest(visited):
    for k, v in forest.iteritems():
        if isroot(k) == 1:
            annotatetree(k, 0, visited)

output = {}
for l in range(0,20):
    output[l] = []
    for i in range(0,80):
        output[l].append(-1)

def showoutput():
    for l in range(0,5):
        for i in range(0,60):
            if output[l][i] == -1:
                print ' ',
            else:
                print output[l][i],
        print

import sys

marginx = 30
marginy = 30
ovalwidth = 20
horiz_sep = 5
vert_sep = 20
nodeidcolor = "#000000"
ovalbgcolor = "#ffffff"

queue = []
def arrangetree(forestoffset):
    lastlevel = 0
    offset = 0
    lastparent = 0
    visited = {}
    while (len(queue) > 0):
        node = queue.pop(0)
        if visited.has_key(node.id):
            break
        else:
            visited[node.id] = 1
        if (node.level > lastlevel):
                lastlevel = node.level
                lastparent = node.parent
                offset = node.parentx
        if (node.parent != lastparent):
            lastparent = node.parent
            offset = node.parentx
            
        startx = offset
        endx = offset + node.width
        output[node.level][forestoffset + int((startx+endx)/2)] = node.id
        node.x = forestoffset + 1.0*(startx+endx)/2
        node.y = node.level

        node.x = marginx + node.x * (ovalwidth + horiz_sep) - ovalwidth/2
        node.y = marginy + node.y * (ovalwidth + vert_sep)  - ovalwidth/2
        
        offset += node.width
        if forest.has_key(node):
            for n in forest[node]:
                n.parentx = offset - node.width
                n.parent = node
                queue.append(n)


def arrangeforest():
    forestoffset = 0
    for k, v in forest.iteritems():
        if isroot(k) == 1:
            k.parentx = 0
            queue.append(k)
            arrangetree(forestoffset)
            forestoffset += k.width
    maxx = 10

def colorstr(i):
    if i > 255:
        i = 255
    return "#%02x%02x%02x" % (i, i, i)

def drawnode(n):
    global viewlight
    global nodelight
    global nodefont
    global ovalbgcolor, nodeidcolor

    w = c.create_oval(n.x-ovalwidth/2, n.y-ovalwidth/2, \
                      n.x+ovalwidth/2, n.y+ovalwidth/2, fill=ovalbgcolor)
    if viewlight == 1 and nodelight.has_key(n.id):
        c.itemconfigure(w, fill=colorstr(nodelight[n.id]/2))

    w = c.create_text(n.x, n.y, text=n.id, font=nodefont, fill=nodeidcolor)

    c.pack()

def drawedge(n1, n2):
    global linewidth1
    global linewidth2
    global linewidth3
    global ovalwidth

    if len(n1.info) > curtask.index(16):
       linkquality = n1.info[curtask.index(16)]
    else:
       linkquality = 700

    lwidth = 1
    if linewidth2 > linkquality >= linewidth3:
        lwidth = 3
    if linewidth1 > linkquality >= linewidth2:
        lwidth = 2
    if linkquality >= linewidth1:
        lwidth = 1

    w = c.create_line(n1.x, n1.y-int(ovalwidth/2), n2.x, n2.y+int(ovalwidth/2), arrow=LAST, width=lwidth)
    c.pack()

taskclose = 1
curitem = 0
def readpkts(curitem):
    global taskclose
    global nodelight
    global nodedata
    global tidinfo
    global tidlight

    if tidinfo > 0 or tidlight > 0:
        r = tenet.read_response(50)
        while r.mote_addr != -1:
            if r.tid == tidinfo:
                if r.attrs.has_key(11):
                    c = addedge(r.attrs[11], r.mote_addr)
                    for item in curtask:
                        if r.attrs.has_key(item+10):
                            c.info.append(r.attrs[item+10])
                nodedata[r.mote_addr] = r.attrs
            if r.tid == tidlight and r.attrs.has_key(150):
                nodelight[r.mote_addr] = r.attrs[150]/2
            r = tenet.read_response(50)
        
    refresh()
    if taskclose == 0:
        root.after(300, readpkts, curitem)

def refresh():
    c.delete(ALL)
    annotateforest({})
    arrangeforest()
    sw = marginx
    sh = 0
    nodes = []
    for k, v in forest.iteritems():
      try:
         x = nodes.index(k.id)
      except ValueError:
          nodes.append(k.id)
      drawnode(k)
      if isroot(k) == 1:
         sw += k.width * (ovalwidth + horiz_sep)
      if sh < k.y:
         sh = k.y
      for n in v:
         if sh < n.y:
            sh = n.y
         try:
            x = nodes.index(n.id)
         except ValueError:
            nodes.append(n.id)
         drawnode(n)
         drawedge(n, k)

    if sw < 300:
        sw = 300
    if sh  < 200:
        sh = 200
    c.create_text(5, sh+ovalwidth-2, text=time.asctime(), anchor=SW)
    c.config(width=sw, height=sh+ovalwidth)
    c.configure(scrollregion=(0,0,sw,sh+ovalwidth))
    c.pack()
    s.set("%d nodes" % len(nodes))

def savedata():
   global nodedata

   fname = tkFileDialog.asksaveasfilename()

   if len(fname) > 0:
      title = "Node ID"
      for t in curtask:
         l = attrs[t-1]
         w = 10
         title = title + ", %s" % l
      title = title + "\n"

      f = open(fname, "w+")
      f.write(title)
      for nodeid, v in nodedata.iteritems():
         row = "%s" % nodeid
         for t in curtask:
            if v.has_key(t+10):
               row = row + ", %s" % v[t+10]
            else:
               row = row + ", Error"
         row = row + "\n"
         f.write(row)
      f.close()

def savescreen():
   global c
   fname = tkFileDialog.asksaveasfilename()
   if len(fname) > 0:
      c.postscript(file=fname, height=c.winfo_reqheight(), width=c.winfo_reqwidth())
    
def closetask():
    global taskclose
    global tidinfo
    global tidlight
    if tidinfo > 0:
        tenet.delete_task(tidinfo)
    if tidlight > 0:
        tenet.delete_task(tidlight)
    taskclose = 1


def mousepointer(event):
   for a, b in forest.iteritems():
        l = [a]
        l.extend(b)
        for k in l:
            if k.x - ovalwidth/2 <= event.x <= k.x + ovalwidth/2 and\
               k.y - ovalwidth/2 <= event.y <= k.y + ovalwidth/2 and\
               nodedata.has_key(k.id):
                root.configure(cursor='hand2')
                return
        root.configure(cursor='')
    

def shownodeinfo(event):
    for a, b in forest.iteritems():
        l = [a]
        l.extend(b)
        for k in l:
            if k.x - ovalwidth/2 <= event.x <= k.x + ovalwidth/2 and\
               k.y - ovalwidth/2 <= event.y <= k.y + ovalwidth/2 and\
               nodedata.has_key(k.id):
                nodeinfo(root, k)
                return
        

class nodeinfo:
    def __init__(self, parent, node):

        top = self.top = Toplevel(parent)

        top.config(bg='#ffffff')
        title = "node %d" % node.id
        Label(top, text=title, font=titlefont, bg='#ffffff').grid()
        self.top.title(title)

        idx = 0
        for t in curtask:
            Label(top, text=attrs[attribute_idx(t)].name, bg='#ffffff').grid(row=idx+1, column=0, sticky=W)
            if len(node.info) > idx and attribute_idx(t) >= 0:
                Label(top, text=attrs[attribute_idx(t)].formatfn(node.info[idx]), font=datafont, bg='#ffffff').grid(row=idx+1, column=1, sticky=W)
            idx += 1

        b = Button(top, text="OK", command=self.ok)
        b.grid(columnspan=2)

    def ok(self):
        self.top.destroy()

firsttime = 0

def sendtask():
    global taskclose
    global tidinfo
    global tidlight
    global viewlight
    global curtask
    global newtask
    global firsttime
    global refreshrate

    global nodedata, nodelight

    nodedata = {}
    nodelight = {}
    
    if tidinfo > 0:
        tenet.delete_task(tidinfo)
    if tidlight > 0:
        tenet.delete_task(tidlight)
    image.pack_forget()
    label.pack_forget()
    curtask = newtask
    tidinfo = tenet.send_task(task_str(curtask))
    print 'sent task', task_str(curtask), 'with tid', tidinfo


    if viewlight == 1:
        lighttask = "repeat(2000)->sample(250,1,22,150)->send()"
        tidlight = tenet.send_task(lighttask)
        print 'sent task', lighttask, 'with tid', tidlight
        
    initforest()
    c.bind("<Button-1>", shownodeinfo)
    c.bind("<Motion>", mousepointer)

    if firsttime == 0:
        Button(root, text="Retask the network and refresh", command=cancel_autorefresh_retask).pack()
        scrolly = Scrollbar(root, orient=VERTICAL, command=c.yview)
        scrollx = Scrollbar(root, orient=HORIZONTAL, command=c.xview)
        c.configure(xscrollcommand=scrollx.set)
        c.configure(yscrollcommand=scrolly.set)
        scrolly.pack(side=RIGHT, fill=Y)
        scrollx.pack(side=BOTTOM, fill=X)
        firsttime = 1
        root.after(refreshrate, autorefresh_sendtask)

    if taskclose == 1:
        taskclose = 0
        root.after(300, readpkts, 0)

def autorefresh_sendtask():
    global refreshrate
    if refreshrate > 0:
        sendtask()
        root.after(refreshrate, autorefresh_sendtask)

def cancel_autorefresh_retask():
    global refreshrate
    refreshrate = 0
    sendtask()

def configuretask():
    d = configtaskdialog(root)

def configuretransport():
    global host
    global port
    d = configtransportdialog(root)
    tenet.config_transport(host, int(port))

from MultiListbox import *
tableview = ""
def tabularview():
   global nodedata
   top = Toplevel(root)

   title = []
   title.append(('Node ID', 10))
   for t in curtask:
      l = attrs[attribute_idx(t)].name
      w = 10
      title.append((l, w))
   
   tableview = MultiListbox(top, title)
   for nodeid, v in nodedata.iteritems():
      row = [nodeid]
      for t in curtask:
         if v.has_key(t+10) and attribute_idx(t) >= 0:
            row.append(attrs[attribute_idx(t)].formatfn(v[t+10]))
         else:
            row.append('N/A')
      tableview.insert(END, row)
   tableview.pack(expand=YES, fill=BOTH)

def viewoptions():
    d = viewoptionsdialog(root)

def help():
    d = helpdialog(root)

def about():
    d = aboutdialog(root)

class aboutdialog:
    def __init__(self, parent):
        top = self.top = Toplevel(parent)
        top.config(bg='#ffffff')
        Label(top, text="Tenet Network Visualization (TeNetViz)", font=titlefont, bg='#ffffff').grid()
        Label(top, text="Works with Tenet 1.0", font=titlefont, bg='#ffffff').grid()
        Label(top, text="http://tenet.usc.edu/", font=titlefont, bg='#ffffff').grid()
        Label(top, text="TeNetViz was written by Omprakash Gnawali", bg='#ffffff').grid()

    def ok(self):
        self.top.destroy()



class helpdialog:
    def __init__(self, parent):


        try:
            f = open('README', 'r')
            helptext = f.readlines()
            f.close()
        except IOError:
            helptext = 'Documentation available at http://tenet.usc.edu'

        top = self.top = Toplevel(parent)
        top.config(bg='#ffffff')

        scrollbar = Scrollbar(top)
        scrollbar.pack(side=RIGHT, fill=Y)

        text = Text(top, wrap=WORD, yscrollcommand=scrollbar.set)
        for l in helptext:
            text.insert(END, l)
        text.pack()

        scrollbar.config(command=text.yview)


class configtransportdialog(Dialog.Dialog):
    def body(self, master):

        Label(master, text="Connect to Tenet", font=titlefont).grid(row=0, columnspan=2)

        Label(master, text="Hostname").grid(row=1)
        Label(master, text="Port").grid(row=2)

        self.hostentry = Entry(master)
        self.hostentry.insert(0, host)
        self.portentry = Entry(master)
        self.portentry.insert(0, port)

        self.hostentry.grid(row=1, column=1)
        self.portentry.grid(row=2, column=1)

        self.title("Connection configuration")

        return self.hostentry

    def apply(self):
        global host
        global port
        host = self.hostentry.get()
        port = self.portentry.get()


class viewoptionsdialog(Dialog.Dialog):

    def changeovalcolor(self, event):
        global ovalbgcolor, nodeidcolor
        ovalbgcolor = tkColorChooser.askcolor(color=ovalbgcolor)[1]
        self.ovalcolorlabel.config(bg=ovalbgcolor, fg=nodeidcolor)
        self.nodeidcolorlabel.config(bg=ovalbgcolor, fg=nodeidcolor)

    def changenodeidcolor(self, event):
        global nodeidcolor, ovalbgcolor
        nodeidcolor = tkColorChooser.askcolor(color=nodeidcolor)[1]
        self.ovalcolorlabel.config(bg=ovalbgcolor, fg=nodeidcolor)
        self.nodeidcolorlabel.config(fg=nodeidcolor, bg=ovalbgcolor)

    def body(self, master):
        global viewtree
        global viewlight
        global linewidth1
        global linewidth2
        global linewidth3
        global ovalwidth, horiz_sep, vert_sep
        global nodefontsize, nodefontcolor, ovalbgcolor, ovalcolorlabel
        global refreshrate

        Label(master, text="Select View options", font=titlefont).grid()

        self.viewtree = IntVar()
        self.cb1 = Checkbutton(master, text="View Tree", variable=self.viewtree, state=DISABLED)
        self.cb1.grid(column=0, sticky=W)
        if viewtree == 1:
            self.cb1.select()

        self.viewlight = IntVar()
        self.cb2 = Checkbutton(master, text="View light level", variable=self.viewlight)
        self.cb2.grid(column=0, sticky=W)
        if viewlight == 1:
            self.cb2.select()

        Label(master, text="Link thickness 1 if link quality > ").grid(column=0, row=3, sticky=W)
        Label(master, text="Link thickness 2 if link quality > ").grid(column=0, row=4, sticky=W)
        Label(master, text="Link thickness 3 if link quality > ").grid(column=0, row=5, sticky=W)
        self.lw1 = Entry(master)
        self.lw1.insert(0, linewidth1)
        self.lw1.grid(column=1, row=3)
        self.lw2 = Entry(master)
        self.lw2.insert(0, linewidth2)
        self.lw2.grid(column=1, row=4)
        self.lw3 = Entry(master)
        self.lw3.insert(0, linewidth3)
        self.lw3.grid(column=1, row=5)

        Label(master, text="Node diameter").grid(column=0, row=6, sticky=W)
        Label(master, text="Inter-node distance (horizantal)").grid(column=0, row=7, sticky=W)
        Label(master, text="Inter-node distance (vertical)").grid(column=0, row=8, sticky=W)
        self.ovalwidth = Entry(master)
        self.ovalwidth.insert(0, ovalwidth)
        self.ovalwidth.grid(column=1, row=6)
        self.horiz_sep = Entry(master)
        self.horiz_sep.insert(0, horiz_sep)
        self.horiz_sep.grid(column=1, row=7)
        self.vert_sep = Entry(master)
        self.vert_sep.insert(0, vert_sep)
        self.vert_sep.grid(column=1, row=8)

        Label(master, text="Node ID font size").grid(column=0, row=9, sticky=W)
        self.nodefontsize = Entry(master)
        self.nodefontsize.insert(0, nodefontsize)
        self.nodefontsize.grid(column=1, row=9)

        self.ovalcolorlabel = Label(master, text="Node background color", bg=ovalbgcolor, fg=nodeidcolor)
        self.ovalcolorlabel.grid(columnspan=2, row=10, sticky=W)
        self.ovalbutton = Button(master, text="Change...", command=lambda : self.changeovalcolor(self.ovalcolorlabel))
        self.ovalbutton.grid(column=1, row=10)
        
        self.nodeidcolorlabel = Label(master, text="Node ID color", fg=nodeidcolor, bg=ovalbgcolor)
        self.nodeidcolorlabel.grid(columnspan=2, row=11, sticky=W)
        self.nodeidbutton = Button(master, text="Change...", command=lambda : self.changenodeidcolor(self.nodeidcolorlabel))
        self.nodeidbutton.grid(column=1, row=11)

        Label(master, text="Refresh rate (s)").grid(column=0, row=12, sticky=W)
        self.rrate = Entry(master)
        self.rrate.insert(0, int(refreshrate/1000))
        self.rrate.grid(column=1, row=12)

    def apply(self):
        global viewtree
        global viewlight
        global linewidth1
        global linewidth2
        global linewidth3
        global ovalwidth, horiz_sep, vert_sep, marginy, marginx
        global nodefontsize, nodefont
        global refreshrate

        viewtree = self.viewtree.get()
        viewlight = self.viewlight.get()
        linewidth1 = int(self.lw1.get())
        linewidth2 = int(self.lw2.get())
        linewidth3 = int(self.lw3.get())
        ovalwidth = int(self.ovalwidth.get())
        horiz_sep = int(self.horiz_sep.get())
        vert_sep = int(self.vert_sep.get())
        marginx = ovalwidth + 20
        marginy = ovalwidth + 20
        nodefontsize = int(self.nodefontsize.get())
        nodefont=tkFont.Font(root, ('helvetica', nodefontsize, tkFont.NORMAL))
        refreshrate = int(self.rrate.get())*1000


class configtaskdialog(Dialog.Dialog):

    def body(self, master):
        Label(master, text="Select desired node information", font=titlefont).grid()

        idx = 0
        self.checkbutton = {}
        self.cbvar = {}
        for item in attrs:
            self.cbvar[idx] = IntVar()
            self.checkbutton[idx] = Checkbutton(master, text=item.name, \
                                                variable=self.cbvar[idx])
            self.checkbutton[idx].grid(column=0, sticky=W)
            idx += 1

        for item in newtask:
           if attribute_idx(item) >= 0:
              self.checkbutton[attribute_idx(item)].select()
              self.cbvar[attribute_idx(item)].set(1)

        if attribute_idx(1) >= 0:
           self.checkbutton[attribute_idx(1)]['state'] = DISABLED

        if attribute_idx(16) >= 0:
           self.checkbutton[attribute_idx(16)]['state'] = DISABLED

        self.title("Task configuration")

    def apply(self):
        global newtask
        newtask = []
        idx = 0
        for item in attrs:
            if self.cbvar[idx].get() == 1:
                newtask.append(item.id)
            idx += 1

menu = Menu(root)
root.config(menu=menu)

fm = Menu(menu)
menu.add_cascade(label="File", menu=fm)
fm.add_command(label="Save Data", command=savedata)
fm.add_command(label="Save Screenshot", command=savescreen)
fm.add_command(label="Connect...", command=configuretransport)
fm.add_command(label="Disconnect", command=closetask)
fm.add_command(label="Exit", command=root.destroy)

tm = Menu(menu)
menu.add_cascade(label="Task", menu=tm)
tm.add_command(label="Configure Task", command=configuretask)
tm.add_command(label="Send Task", command=sendtask)
tm.add_command(label="Stop Task", command=closetask)

vm = Menu(menu)
menu.add_cascade(label="View", menu=vm)
vm.add_command(label="Options", command=viewoptions)
vm.add_command(label="Tabular View", command=tabularview)

hm = Menu(menu)
menu.add_cascade(label="Help", menu=hm)
hm.add_command(label="Help", command=help)
hm.add_command(label="About", command=about)


mainloop()
