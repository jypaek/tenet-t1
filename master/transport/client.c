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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>

#include "trsource.h"
#include "client.h"
#include "tidlist.h"
#include "transport.h"

struct client_list *clients;
extern int packets_read, packets_written;
extern int verbosemode;

int unix_check(const char *msg, int result) {
    if (result < 0) {
        perror(msg);
        exit(2);
    }
    return result;
}

void *xmalloc(size_t s) {
    void *p = malloc(s);
    if (!p) {
        fprintf(stderr, "out of memory\n");
        exit(2);
    }
    return p;
}

void fd_wait(fd_set *fds, int *maxfd, int fd) {
    if (fd > *maxfd)
        *maxfd = fd;
    FD_SET(fd, fds);
}

void pstatus(void) {
    if (verbosemode)
    printf("clients %d, tids %d, read %d, wrote %d\n", 
        num_clients, tidlist_num_tids(), packets_read, packets_written);
}

void add_client(int fd) {
    struct client_list *c = xmalloc(sizeof *c);
    c->next = clients;
    clients = c;
    num_clients++;
    //pstatus();
    c->fd = fd;
}

void rem_client(struct client_list **c) {
    struct client_list *dead = *c;
    close_all_tid_for_a_client((*c)->fd);
    *c = dead->next;
    num_clients--;
    //pstatus();
    close(dead->fd);
    free(dead);
}

void new_client(int fd) {
    if (init_tr_source(fd) < 0) {
        printf("init_tr_source failed for new client \n");
        close(fd);
    } else {
        //printf("New client added \n");
        add_client(fd);
    }
}

void wait_clients(fd_set *fds, int *maxfd) {
    struct client_list *c;

    for (c = clients; c; c = c->next)
        fd_wait(fds, maxfd, c->fd);
}

void rem_client_list() {
    struct client_list **c;
    for (c = &clients; *c; )
        rem_client(c);
}

void dispatch_packet(const void *packet, int len) {
    struct client_list **c;

    for (c = &clients; *c; )
        if (write_tr_packet((*c)->fd, packet, len) >= 0) // send UP to all clients
            c = &(*c)->next;
        else
            rem_client(c);
}

void open_server_socket(int port) {
    struct sockaddr_in me;
    int opt;

    server_socket = unix_check("socket", socket(AF_INET, SOCK_STREAM, IPPROTO_TCP));

    #ifndef __APPLE__
    /* this line caused init_tr_source error on APPLE machies
       not sure about the reason.  -jpaek (Mar.4.2007) */
    unix_check("socket", fcntl(server_socket, F_SETFL, O_NONBLOCK));
    #endif
    memset(&me, 0, sizeof me);
    me.sin_family = AF_INET;
    me.sin_port = htons(port);

    opt = 1;
    unix_check("setsockopt", setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR,
                     (char *)&opt, sizeof(opt)));
                                                                             
    unix_check("bind", bind(server_socket, (struct sockaddr *)&me, sizeof(me)));
    unix_check("listen", listen(server_socket, 5));
}

void check_new_client(void) {
    int clientfd = accept(server_socket, NULL, NULL);
    if (clientfd >= 0)
        new_client(clientfd);
}

