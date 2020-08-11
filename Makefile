#
# "Copyright (c) 2006~2007 University of Southern California.
# All rights reserved.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without written
# agreement is hereby granted, provided that the above copyright
# notice, the following two paragraphs and the author appear in all
# copies of this software.
#
# IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
# ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
# DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
# DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
# PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
# SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
# SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
#

DIST_PATH="./dist"
TOP=$(pwd)
MASTER_DIR="master"
APPS_DIR="apps"
MOTE_DIR="mote"
TOOLS_DIR="tools"

MODULE_DIRS= $(MASTER_DIR) $(APPS_DIR) $(TOOLS_DIR)

all:
	for i in $(MODULE_DIRS); do \
		$(MAKE) -C $$i || exit 1; \
    done

arm:
	for i in $(MODULE_DIRS); do \
		$(MAKE) -C $$i PLATFORM=arm|| exit 1; \
    done

release:
	@tools/create_dist -d $(DIST_PATH) -t $(TARGET) -c $(VERSION)


clean:
	for i in $(MODULE_DIRS); do \
		$(MAKE) -C $$i clean || exit 1; \
    done
