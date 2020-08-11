/*
 * "Copyright (c) 2006~2007 University of Southern California.
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
 *
 * Children Table Interface
 *
 * This interfaces defines functions that provide read access
 * to the children table maintained by the router.
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 **/

interface ChildrenTable {
  
    command uint8_t isChild(uint16_t childid);
    command uint8_t refreshChild(uint16_t childid);
    command uint16_t lookupChildNextHop(uint16_t childid);
    command void deleteChild(uint16_t childid);
    command void addChild(uint16_t prevhop, uint16_t childid);
    command void ageChildren();

  /* get the list of routing children:
     - fill up 'buf' with children ID's upto 'maxlen' number of children.
     - return the number of children ID filled 
     - size of 'buf' should be greater than sizeof(uint16_t)*maxlen */
    command uint8_t getChildrenList(uint8_t *buf, uint8_t maxlen);

    command uint8_t getChildrenListSize();
}

