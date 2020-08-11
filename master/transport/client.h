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
 * Header file for the client list that the transport layer maintains,
 * where a client to this transport layer is an application that connects 
 * to this transport layer.
 *
 * This file referenced the C serial forwarder in tinyos-1.x/toosl/sf.
 * Client list maintains the socket file descriptor to the clients
 * so that transport layer can forward packets to the clients, and
 * listen to all the clients for any packets.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _CLIENT_H
#define _CLIENT_H

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

int server_socket;
int num_clients;

struct client_list {
	struct client_list *next;
	int fd;
};

void fd_wait(fd_set *fds, int *maxfd, int fd);
void check_new_client(void);
void open_server_socket(int port);
void dispatch_packet(const void *packet, int len);
void wait_clients(fd_set *fds, int *maxfd);
void new_client(int fd);
void rem_client(struct client_list **c);
void rem_client_list(void);
void add_client(int fd);
void pstatus(void);

#endif

