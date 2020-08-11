#
# "Copyright (c) 2007 The Regents of the University of California.
# All rights reserved.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without written
# agreement is hereby granted, provided that the above copyright
# notice, the following two paragraphs and the author appear in all
# copies of this software.
#
# IN NO EVENT SHALL THE REGENTS BE LIABLE TO
# ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
# DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
# DOCUMENTATION, EVEN IF THE REGENTS HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# THE REGENTS SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
# PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
# SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
# SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
#

# Author: Vinayak Naik (naik@cens.ucla.edu)
# $Id: Makefile,v 1.1 2007-08-27 20:11:05 naik Exp $

CC=gcc

all: tenetrun 

tenetrun.tab.c: tenetrun.y process.h
	bison -v -t -d $<
	
lex.yy.c: tenetrun.l
	flex $<
	#flex -d $<
	
tenetrun: tenetrun.tab.c lex.yy.c
	$(CC) -g $^ -lfl -o $@

clean:
	rm tenetrun tenetrun.output tenetrun.tab.c tenetrun.tab.h lex.yy.c
