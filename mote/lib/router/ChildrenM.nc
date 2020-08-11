/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * 'children' table is maintained here
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/21/2007
 * @author Jeongyeup Paek
 * @author Omprakash Gnawali
 **/

module ChildrenM {
    provides {
        interface ChildrenTable as Table;
    }
}

implementation {

enum {
    CHILDREN_TIMEOUT = 10,

#ifdef CHILDREN_TABLE_SIZE
    CHILDREN_MAX_NUM = CHILDREN_TABLE_SIZE,
#else
    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2) || defined(PLATFORM_TMOTE)
        CHILDREN_MAX_NUM = 90,
    #elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        CHILDREN_MAX_NUM = 20,
    #endif
#endif
};

    typedef struct Child {
        uint16_t prevhop;
        uint16_t childid;
        uint8_t  age;
    } Child;

    struct Child ChildrenArray[CHILDREN_MAX_NUM]; // children table for downlink routing
    uint8_t childidx = 0;

    command uint8_t Table.isChild(uint16_t childid) {
        uint8_t i;
        for (i = 0; i < childidx; i++) {
            if (ChildrenArray[i].childid == childid) {
                return 1;
            }
        }
        return 0;
    }

    command uint8_t Table.refreshChild(uint16_t childid) {
        uint8_t i;
        for (i = 0; i < childidx; i++) {
            if (ChildrenArray[i].childid == childid) {
                ChildrenArray[i].age = 0;
                return 1;
            }
        }
        return 0;
    }

    command uint16_t Table.lookupChildNextHop(uint16_t childid) {
        uint8_t i;
        for (i = 0; i < childidx; i++) {
            if (ChildrenArray[i].childid == childid)
                return ChildrenArray[i].prevhop;
        }
        return TOS_BCAST_ADDR;
    }

    command void Table.deleteChild(uint16_t childid) {
        uint8_t i;

        if (childid == TOS_BCAST_ADDR)
            return;

        for (i = 0; i < childidx; i++) {
            if (ChildrenArray[i].childid == childid) {
                break;
            }
        }
        if (i == childidx)
            return;

        ChildrenArray[i].prevhop = ChildrenArray[childidx - 1].prevhop;
        ChildrenArray[i].childid = ChildrenArray[childidx - 1].childid;
        ChildrenArray[i].age = ChildrenArray[childidx - 1].age;

        childidx--;
    }

    command void Table.addChild(uint16_t prevhop, uint16_t childid) {
        if (call Table.isChild(childid) == 1) {  // if child exists
            if (call Table.lookupChildNextHop(childid) == prevhop) { // if route to child didn't change
                call Table.refreshChild(childid);
                return; // already exists. refresh and return
            } else {
                call Table.deleteChild(childid); // delete and re-add
            }
        }

        if (childidx < CHILDREN_MAX_NUM) {
            ChildrenArray[childidx].prevhop = prevhop;
            ChildrenArray[childidx].childid = childid;
            ChildrenArray[childidx].age = 0;
            childidx++;
        } else {
            call Table.ageChildren();
        }
    }

    command void Table.ageChildren() {
        uint8_t i;

        for (i = 0; i < childidx; i++) {
            ChildrenArray[i].age++;
            if (ChildrenArray[i].age > CHILDREN_TIMEOUT) {
                call Table.deleteChild(ChildrenArray[i].childid);
                i--;
            }
        }
    }

    command uint8_t Table.getChildrenListSize() { return childidx; }

    command uint8_t Table.getChildrenList(uint8_t *buf, uint8_t maxlen) {
        uint8_t i;
        uint16_t *list = (uint16_t *)buf;
        for (i = 0; i < childidx; i++) {
            if (i < maxlen)
                list[i] = ChildrenArray[i].childid;
            else
                break;
        }
        return i;
    }

}

