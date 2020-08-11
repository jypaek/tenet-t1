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
 * Neighbor Table
 *
 * Implementation of Neighbor Table. The user of this component
 * can add a node to the neighbor table, delete a node from
 * the neighbor table, and read the node ids from the neighbor table
 *
 * @author Marcos Vieira
 * @author Omprakash Gnawali
 * @author Jeongyeup Paek
 * @modified 11/12/2006
 * @modified 03/27/2007 - added Aging
 * @modified 06/16/2007 - merge Neighbors & NeighborTable interface
 *                      - added link quality field
 **/


module NeighborsM {
    provides {
        interface NeighborTable as Neighbors;
    }
}

implementation {

    enum {
#if defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2) || defined(PLATFORM_TMOTE)
        MAX_NEIGHBORS = 25,
#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    #ifdef NEIGHBOR_TABLE_SIZE   // going around RAM shortage problem in micaz
        MAX_NEIGHBORS = NEIGHBOR_TABLE_SIZE,
    #else
        MAX_NEIGHBORS = 10,
    #endif
#endif
        NEIGHBORS_TIMEOUT = 5,
    };

    typedef struct Neighbor {
        uint16_t id;
        uint8_t lq;    // link quality
        uint8_t age;
    } Neighbor;

    struct Neighbor NeighborsArray[MAX_NEIGHBORS];
    uint8_t nelements = 0;

    command void Neighbors.addNeighbors(uint16_t id, uint8_t linkquality) {
    #if NEIGHBOR_TABLE_SIZE > 0
        int i;
        if ((id == TOS_LOCAL_ADDRESS) || (id == TOS_BCAST_ADDR))
            return;

        for (i = 0; i < nelements; i++) {
            if (NeighborsArray[i].id == id) {
                NeighborsArray[i].age = 0; //refresh
                NeighborsArray[i].lq = linkquality; //refresh
                return;
            }
        }

        if (nelements < MAX_NEIGHBORS) {
            NeighborsArray[nelements].id = id;
            NeighborsArray[nelements].lq = linkquality;
            NeighborsArray[nelements].age = 0;
            nelements++;
        } else {
            call Neighbors.ageNeighbors();
        }
    #endif
    }

    command void Neighbors.deleteNeighbor(uint16_t id) {
    #if NEIGHBOR_TABLE_SIZE > 0
        int i;
        for (i = 0; i < nelements; i++) {
            if (NeighborsArray[i].id == id)
                break;
        }
        if (i == nelements)
            return;

        NeighborsArray[i].id = NeighborsArray[nelements-1].id;
        NeighborsArray[i].lq = NeighborsArray[nelements-1].lq;
        NeighborsArray[i].age = NeighborsArray[nelements-1].age;

        nelements--;
    #endif
    }

    command void Neighbors.ageNeighbors() {
    #if NEIGHBOR_TABLE_SIZE > 0
        int i;
        for (i = 0; i < nelements; i++) {
            NeighborsArray[i].age++;
            if (NeighborsArray[i].age > NEIGHBORS_TIMEOUT) {
                call Neighbors.deleteNeighbor(NeighborsArray[i].id);
                i--;
            }
        }
    #endif
    }

    command uint8_t Neighbors.getNeighbors(uint8_t *buf, uint8_t maxlen) {
        int i = 0;
    #if NEIGHBOR_TABLE_SIZE > 0
        uint16_t *list = (uint16_t *)buf;
        for (i = 0; i < nelements; i++) {
            if (i < maxlen)
                list[i] = NeighborsArray[i].id;
            else
                break;
        }
    #endif
        return i;
    }

    command uint8_t Neighbors.getNeighborsSize() {
        return nelements;
    }

    command uint8_t Neighbors.getLinkQuality(uint16_t n) {
    #if NEIGHBOR_TABLE_SIZE > 0
        int i;
        for (i = 0; i < nelements; i++) {
            if (NeighborsArray[i].id == n) {
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2) || defined(PLATFORM_MICAZ)
                // LQI value from MultihopLQI
                uint16_t result = (80 - (NeighborsArray[i].lq - 50));
                result = (((result * result) >> 3) * result) >> 3;
            #else
                uint16_t result = NeighborsArray[i].lq;
            #endif
                return result;
            }
        }
    #endif
        return 0;
    }

}

