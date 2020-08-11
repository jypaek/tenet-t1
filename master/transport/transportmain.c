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
 * main() file for master transport layer.
 *
 * Accepts applictions to connect to the transport layer.
 * Connects to the routing layer to send/receive packets from other nodes,
 * including both masters and motes.
 * When an application sends a task, assign an unique tid and disseminate 
 * the task with that tid.
 * Maintains the list of tid's used for tasks.
 * When an application disconnects, automatically send out DELETE task
 * for the tid's that belong to that application.
 * When this transport itself terminates, automatically send out DELETE task
 * for all the tid's in the list.
 * When a DELETE task is sent from the application, delete the corresponding
 * tid from the list.
 * When a packet is received from the routing layer, check the protocol type
 * of that packet and pass it to the appropriate module.
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
#include <sys/time.h>
#include <stddef.h>
#include <limits.h>

#include "transportmain.h"
#include "trsource.h"
#include "transport.h"
#include "routinglayer.h"
#include "service.h"
#include "timeval.h"
#include "tidlist.h"
#include "tosmsg.h"
#include "sfsource.h"
#include "tcmp.h"
#include "client.h"
#include "tr_if.h"
#include "packettransport.h"
#include "streamtransport.h"
#include "rcrtransport.h"
#include "trd_transport.h"
#include "multihoplqibase.h"
#include "Network.h"

#include "tenet_task.h" // from 'mote/lib/'

//#define DEBUG_TOSMSG

int rt_fd; /* fd of tenet router 
              - that this program is going to connect to.
              - we will send packets to the mote world using this socket */
char *router_host; /* the host name where the router program will reside */
char *transport_dir;
char rhostbuf[100];
int router_port;   /* the port number which the router program will open */


extern struct client_list *clients; /* list of client applications 
                                       - which connected to this transport.
                                       - it is maintained by the files client.c */
    
extern char *tid_filename; /* transport uses a file to maintain the 'tid' */
extern char tid_filebuf[20];

int tr_server_port; /* the transport server port number
                       - that this program will open, and
                       - the applications will connect to. */
    
uint16_t LOCAL_ADDRESS; /* 16-bit address of 'this' transport
                           - this must match that of the router, and
                           - the TOS_LOCAL_ADDRESS of the BaseStation */

int base_station = 0;
int verbosemode = 0;

int packets_read, packets_written;

#ifdef LOG_INCOMING
FILE *infptr;
char *infilename = "tr_log.in";
#endif
#ifdef LOG_OUTGOING
FILE *outfptr;
char *outfilename = "tr_log.out";
#endif

int ready_to_task = 0;

/* By default, my LOCAL_ADDRESS is the least-significant 16-bits of my IP */
uint16_t get_my_local_address() {
    uint32_t ip;
    uint16_t addr;
    /* Get IP */
    ip = GetMyIP();
    /* parse lower 16-bits of ip (ip is in reverse order) */
    addr = ((ip>>8)&0x0000ff00);
    addr += ((ip>>24)&0x000000ff);
    return addr;    
}

/* When transport terminates, we should send STOP/CLOSE task to all
   the tasks sent through this transport layer */
void sig_int_handler(int signo) {
    fprintf(stderr, "transport terminating... (closing all tasks/tid/clients)\n");
    tidlist_terminate();
    rem_client_list();
    packettransport_terminate();
    streamtransport_terminate();
    rcrtransport_terminate();
    exit(1);
}

/* Send tasking packet to the mote world  */
int tr_send_packet(uint16_t tid, uint16_t addr, unsigned char *packet, int len) {
    if (addr == TOS_BCAST_ADDR) { // send using TRD
        int seqno = trd_transport_send(tid, len, packet);
        if (seqno < 0) {
            printf("tr_send_packet: failed. (tid %d)(len %d)(err %d)\n", tid, len, seqno);
            fflush(stdout);
            return -1;
        } else {
            if (verbosemode) printf("trd_send... OK ! (tid %d seqno %d)\n", tid, seqno);
        }
    } else { // if unicast, send using packet transport
        int cid = packettransport_send(tid, addr, len, packet);
        if (cid < 0) {
            printf("tr_send_packet: failed. (tid %d, addr %d)\n", tid, addr);
            fflush(stdout);
            return -1;
        } else {
            if (verbosemode) printf("ptr_send... OK ! (tid %d addr %d)\n", tid, addr);
            /* Although the unicast tasking packet has been sent via packet transport,
               we cannot be sure whether the delivery is successful or not. */
            return 2;
        }
    }
    return 1;
}

/* Send close/stop task packet to the mote world */
int tr_send_close_task(uint16_t tid, uint16_t addr) {
    int len = offsetof(task_msg_t, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    task_msg_t *tMsg = (task_msg_t *) packet;
    int ok = 1;
   
    if (verbosemode) {
        if (addr != TOS_BCAST_ADDR)
            printf("closing tid %d node %d\n", tid, addr);
        else
            printf("closing tid %d\n", tid);
    }

    /* transport must know how to send 'delete' task
       when a client closes it's connection */
    //len = construct_delete(packet, tid);
    tMsg->type = TASK_DELETE; // DELETE @ mote/lit/tenet_task.h
    tMsg->numElements = 0;
    ok = tr_send_packet(tid, addr, packet, len);

    free((void *)packet);
    return ok;
}

/**
 * function that transport layer uses to send packet to the application
 **/
void send_toApp(const void *msg, int len, uint8_t type, uint16_t tid, uint16_t addr) {
    // 'len' is the total length of 'msg'
    // 'msg' does not have TransportIfHdr yet. We'll put it here
    int length = len + offsetof(tr_if_msg_t, data);
    unsigned char *packet = (unsigned char *) malloc(length);
    tr_if_msg_t *appmsg = (tr_if_msg_t *) packet;

    appmsg->type = type;
    appmsg->tid = tid;
    appmsg->addr = addr;
    if ((len > 0) && (msg))
        memcpy(appmsg->data, msg, len);
 
    // send to a client associated with 'tid'
    if (tid == ALL_TID)
        dispatch_packet(packet, length);
    else
        send_to_tid(packet, length, tid, addr);
    free((void *)packet);
}

void close_transport_connections(uint16_t tid) {
    packettransport_delete_tid(tid);
    streamtransport_delete_tid(tid);
    rcrtransport_delete_tid(tid);
}

int check_transport_connections(uint16_t tid) {
    if (packettransport_tid_is_alive(tid))
        return 1;
    if (streamtransport_tid_is_alive(tid))
        return 1;
    if (rcrtransport_tid_is_alive(tid))
        return 1;
    return 0;
}

void check_close_done(uint16_t tid) {
    struct tid_list *t = tidlist_find_tid(tid);
    if (t == NULL) return;
    if (t->type != TRANS_TYPE_CLOSE) {
        printf("check for buggggggggggggggg\n");
    }
    if (check_transport_connections(tid) == 0) {
        if (verbosemode) printf("check close done...\n");
        send_toApp(NULL, 0, TRANS_TYPE_CLOSE_ACK, tid, t->addr);
        tidlist_remove_tid(tid);
    }
    fflush(stdout);
}

/* We have received a packet from a client application */
void check_clients(fd_set *fds) {
    struct client_list **c;
    unsigned char *packet;
    int len;
    uint16_t tid, addr;
    uint8_t type;
    struct tid_list *t;
    int ok;

    for (c = &clients; *c; ) {
        int next = 1;

        if (FD_ISSET((*c)->fd, fds)) {
            void *payload = NULL;
            packet = read_transport_msg((*c)->fd, &len, &type, &tid, &addr, &payload);

            if (packet) {

                printf("from client: tid %d, addr %d, type %d, len %d:\n", tid, addr, type, len);
            #ifdef DEBUG_TOSMSG
                fdump_packet(stdout, payload, len);
            #endif

                switch (type) {

                    /* a new task has been requested to be sent */
                    case (TRANS_TYPE_TASK):
                        tid = assign_new_tid(0); // assign new tid
                        t = tidlist_add_tid(tid, addr, type, (*c)->fd);

                        /* If you use SEND_TASK to send DELETE TASK,
                           the binding will not be deleted.  Don't do that!!! */
                        ok = tr_send_packet(tid, addr, payload, len);
                        if (ok < 0) {
                            send_toApp(NULL, 0, TRANS_TYPE_CMD_NACK, tid, addr);    // NACK - failed
                            tidlist_remove_tid(tid);    // remove (don't need anymore)
                        } else {
                            if (addr == TOS_BCAST_ADDR) // sent using TRD
                                send_toApp(NULL, 0, TRANS_TYPE_CMD_ACK, tid, addr);
                            /* Since packet transport (unicast) awaits for acknowledgement,
                               we return 'RETURN', not ACK nor NACK. */
                            else
                                send_toApp(NULL, 0, TRANS_TYPE_CMD_RETURN, tid, addr);
                        }
                        break;

                    case (TRANS_TYPE_CLOSE):
                        t = tidlist_find_tid(tid);
                        if (t) {
                            t->type = TRANS_TYPE_CLOSE; // close pending
                            tr_send_close_task(tid, addr); // send close/delete task
                            close_transport_connections(tid);
                            check_close_done(tid);
                        }
                        break;

                        /* special services... might be deprecated later */
                    case (TRANS_TYPE_SERVICE):
                        tid = assign_new_tid(0);
                        t = tidlist_add_tid(tid, TOS_LOCAL_ADDRESS(), type, (*c)->fd);
                        service_send_request(rt_fd, tid, len, payload);
                        break;

                    case (TRANS_TYPE_PING):
                        tid = assign_new_tid(0);
                        t = tidlist_add_tid(tid, addr, type, (*c)->fd);
                        TCMP_send_ping(tid, addr);
                        break;

                    case (TRANS_TYPE_TRACERT):
                        tid = assign_new_tid(0);
                        t = tidlist_add_tid(tid, addr, type, (*c)->fd);
                        TCMP_send_tracert(tid, addr);
                        break;

                    case (TRANS_TYPE_SNOOP):
                        t = tidlist_add_tid(ALL_TID, TOS_BCAST_ADDR, type, (*c)->fd);
                        break;

                    default:
                        printf( "  check_client: unidentified type app pkt detected\n");
                }// End of switch

                free((void *)packet);
            } else {
                rem_client(c);
                next = 0;
            }
        }
        if (next)
            c = &(*c)->next;
    }
}

void check_init() {
    if ((ready_to_task == 0) && (is_trd_transport_sendReady())) {
        ready_to_task = 1;
        //if (verbosemode)
        printf("Transport init done. Ready to send task.\n");
        fflush(stdout);

        // Write PID file. Added by Ki-Young Jang
        {
            int pid = fork();
            if (pid) {
                char pStr[256];
                char pOut[256];
                realpath( transport_dir, pStr );
                sprintf( pOut, "echo %d > $(dirname %s)/transport.pid", pid, pStr );
                system( pOut );
                exit(0);
            }
        }
    }
}

void check_router(void) {   // a packet came from below (router or serial_forwarder)
    int len;
    unsigned char *packet = read_sf_packet(rt_fd, &len);// read from the router 

    if (packet) {
        TOS_Msg *msg = (TOS_Msg*)packet;

#ifdef DEBUG_TOSMSG
        printf("from router: ");
        fdump_packet(stdout, packet, len);
#endif
        packets_read++;
#ifdef LOG_INCOMING 
        struct timeval tv;
        gettimeofday(&tv, NULL);
        fprintf(infptr, "%06ld.%03ld ",tv.tv_sec, tv.tv_usec/1000);
        fdump_packet(infptr, packet, len);
#endif
    
        if (msg->type == AM_BS_SERVICE) { // service packet
            service_receive_response(len, (uint8_t *)msg->data);
        }
        else if (is_trd_transport_packet(len, packet)) { // TRD packet
            trd_transport_receive(len, packet);
        }
        else if (msg->type == AM_TENET_ROUTING) { // Routed packet (PTR or STR or TCMP)
            uint16_t srcAddr, dstAddr, prevhop;
            uint8_t protocol, ttl;
            int paylen;
            // TOS header and routing header are both removed in rt_payload.
            unsigned char *rt_payload = read_routing_msg(len, packet, &paylen,
                            &srcAddr, &dstAddr, &prevhop, &protocol, &ttl);
            protocol = protocol & PROTOCOL_MASK;
            if ((rt_payload == NULL) || (paylen <= 0)) {
                // INVALID PACKET
            } 
            else if (protocol == PROTOCOL_PACKET_TRANSPORT) {
                packettransport_receive(paylen, rt_payload, srcAddr);
            } 
            else if (protocol == PROTOCOL_STREAM_TRANSPORT) {
                streamtransport_receive(paylen, rt_payload, srcAddr);
            } 
            else if (protocol == PROTOCOL_RCR_TRANSPORT) {
                rcrtransport_receive(paylen, rt_payload, srcAddr);
            } 
            else if (protocol == PROTOCOL_TCMP) {
                TCMP_receive(paylen, rt_payload, srcAddr, dstAddr, ttl);
            }
        } else {
            //printf("unidentified packet received at transport layer\n");
            //dump_packet(packet, len);
        }
        free((void *)packet);
    }
}

void print_intro() {
    printf("\n");
    printf("------------------------------------------------------------\n");
    printf(" Tenet Tasking/Transport Layer \n");
    printf("------------------------------------------------------------\n");
    printf("\n");
}

void print_usage(char *arg0) {
    printf("   - Usage: %s [options]\n",arg0);
    printf("   - [options] \n");
    printf("       -h                : print this message\n");
    printf("       -a                : set local address (16bit)\n");
    printf("       -s <server port>  : set the server port (which applications connect to)\n");
    printf("       -rp <router port> : set the router port\n");
    printf("       -rh <router host> : set the router host\n");
    printf("       -r <router host> <router port>\n");
    printf("       -b                : become a base-station (send MultihopLQI beacon\n");
    printf("                         : (This assumes TOSBase or BaseNic)\n");
    printf("       -f <tid_filename> : set the filename for tid file\n");
    printf("       -t <rcrt setting> : set the setting # for rcrt\n");
}

void parse_argv(int argc, char **argv) {
    int ind;
    char *tmp;
    int first_ind = 1;

    if (argc < first_ind) {
        print_usage(argv[0]);
        exit(2);
    }
 
    transport_dir = argv[0];

    /* Set up the default values for 
       - LOCAL_ADDRESS,
       - transport server port (that applications will connect to)
       - router host/port (that transport will connect to) */

    LOCAL_ADDRESS = 0;

    tid_filename = TID_LOGFILE;
    tmp = getenv("TENET_TRANSPORT_PORT");
    if (tmp) tr_server_port = atoi(tmp);
    else tr_server_port = DEFAULT_TRANSPORT_PORT;
    tmp = getenv("TENET_ROUTER_PORT");
    if (tmp) router_port = atoi(tmp);
    else router_port = DEFAULT_ROUTER_PORT;
    tmp = getenv("TENET_ROUTER_HOST");
    if (tmp) router_host = tmp;
    else router_host = DEFAULT_ROUTER_HOST;

    /* Check for options passed through arguments */
    for (ind = first_ind; ind < argc; ind++) {
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'r':   // router host/port
                    if (argv[ind][2] == 'h') {
                        strcpy(rhostbuf, argv[++ind]);
                        router_host = rhostbuf;
                    } else if (argv[ind][2] == 'p') {
                        router_port = atoi(argv[++ind]);
                    } else {
                        strcpy(rhostbuf, argv[++ind]);
                        router_host = rhostbuf;
                        router_port = atoi(argv[++ind]);
                    }
                    break;
                case 'a':   // LOCAL_ADDRESS
                    LOCAL_ADDRESS = atoi(argv[++ind]);
                    break;
                case 's':   // server port
                    tr_server_port = atoi(argv[++ind]);
                    break;
                case 'b':   // become a MultihopLQI base station
                    base_station = 1;
                    break;
                case 'f':   // tid filename
                    strcpy(tid_filebuf, argv[++ind]);
                    tid_filename = tid_filebuf;
                    break;
                case 'n':
                    setenv("TENET_ROUTER_INTERFACE", argv[++ind], 1);
                    break;
                case 't':   // rcrt setting
                    rcrt_configure(atoi(argv[++ind]));
                    break;
                case 'h':   // help
                    print_usage(argv[0]);
                    exit(0);
                    break;
                default :
                    printf("Unknown switch '%c'\n", argv[ind][1]);
                    print_usage(argv[0]);
                    exit(0);
                    break;
            }
        } else {
            print_usage(argv[0]);
            exit(2);
        }
    }

    if (!LOCAL_ADDRESS) {
    #ifdef __APPLE__
        fprintf(stderr, "ERROR! specify LOCAL_ADDRESS!\n");
    #else
        /* Below does not work on APPLE machines.
           gives "ioctl() error".
           - jpaek (Mar. 4. 2007) */
        char pStr[256];
        if( ! getenv("TENET_ROUTER_INTERFACE"))
        {
            if (!GetDefaultNetworkInterface(pStr)) {
                fprintf( stderr, "No network interface found\n" );
            } else {
                setenv("TENET_ROUTER_INTERFACE", pStr, 1);
            }
        }
        if (getenv("TENET_ROUTER_INTERFACE")) {
            LOCAL_ADDRESS = get_my_local_address();
        } else {
            fprintf(stderr, "ERROR! specify LOCAL_ADDRESS!\n");
        }
    #endif // end of if not __APPLE__
    }

    /* set tid filename */
    sprintf(tid_filebuf, "%s.%d", tid_filename, LOCAL_ADDRESS);
    tid_filename = tid_filebuf;
}

void open_router(const char *host, int port) {
    /* open a TCP socket to the router program using 'sf' protocol. */
    rt_fd = open_sf_source(host, port);
    if (rt_fd < 0) {
        fprintf(stderr, "Couldn't open router at %s:%d\n", host, port);
        print_usage("transport");
        exit(1);
    }
}

void initialize_transport() {
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
        fprintf(stderr, "Warning: failed to ignore SIGPIPE.\n");
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SININT handler");
    if (signal(SIGTERM, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINTERM handler");

    open_router(router_host, router_port);
    open_server_socket(tr_server_port);

#ifdef LOG_INCOMING
    infptr = fopen(infilename, "w");
#endif
#ifdef LOG_OUTGOING
    outfptr = fopen(outfilename, "w");
#endif

    printf("[ENV] TENET_TRANSPORT_PORT (FOR APPLICATION) : %d\n", tr_server_port);
    printf("[ENV] TENET_ROUTER_HOST                      : %s\n", router_host);
    printf("[ENV] TENET_ROUTER_PORT                      : %d\n", router_port);
    printf("[ENV] TENET_LOCAL_ADDRESS                    : %d\n", LOCAL_ADDRESS);
    printf("[ENV] TENET NEXT LOCAL TID                   : %d\n", tidlist_init());
#if defined(LOG_INCOMING)
    printf("[ENV] LOG FILE INCOMING                      : %s\n", infilename);
#elif defined(LOG_OUTGOING)
    printf("[ENV] LOG FILE OUTGOING                      : %s\n", outfilename);
#endif
    printf("\n");
    fflush(stdout);

    /* Initialize TRD, the dissemination protocol */
    trd_transport_init(get_router_fd(), LOCAL_ADDRESS);

    /* Transport acts as a MultihopLQI base-station.
        - sends out beacons to advertise itself as a root. */
    if (base_station) {
        printf("running as a base station\n");
        multihoplqi_beacon_timer_start();
    }

#ifndef USE_CENTROUTE
    // this function isn't currently supported by centroute
    base_id_request(rt_fd);
#endif
}

void check_timer() {
    /* Check/poll any piece of program which requires timer events */
    polling_packettransport_timer();
    polling_streamtransport_timer();
    polling_rcrtransport_timer();
    polling_trd_transport_timer();
    polling_tcmp_timer();
    if (base_station)
        polling_multihoplqi_beacon_timer();
}

int main(int argc, char **argv)
{
    int timeout = 0;

    print_intro();          /* print anything that looks great */

    parse_argv(argc, argv); /* parse command-line arguments/options */

    initialize_transport(); /* initialize transport (socket, etc) */

    for (;;)
    {
        fd_set rfds;
        int maxfd = -1;
        int ret;
        struct timeval tv;

        FD_ZERO(&rfds);
        fd_wait(&rfds, &maxfd, rt_fd);
        fd_wait(&rfds, &maxfd, server_socket);
        wait_clients(&rfds, &maxfd);

        tv.tv_sec = 0;
        tv.tv_usec = 49000; // poll for timer events every 49ms

        ret = select(maxfd + 1, &rfds, NULL, NULL, &tv);   // block

        if (ret > 0) {
            if (FD_ISSET(rt_fd, &rfds))
                check_router();     /* received a packet from router (or sf) */

            if (FD_ISSET(server_socket, &rfds))
                check_new_client(); /* received new connection request from a client */

            check_clients(&rfds);   /* received a packet from a client. */

            if (++timeout > 9) {   /* for at least every 10 pkts, check the timer. */
                timeout = 0;
                check_timer();    // if polling is used
            }
        } 
        else  if (ret == 0) {
            timeout = 0;
            check_timer();    // if polling is used
            check_init();
        }
    }
}


/****************************************************************
  event functions required by used modules
  - TRD
  - packet transport
  - stream transport
  - rcr    transport
  - TCMP
  - timesync
 *****************************************************************/
int get_router_fd() {
    return rt_fd;
}   
void receive_trd_transport(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a packet through TRD transport protocol with 'tid' from 'addr'.
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_BCAST, tid, addr);
}
void receive_packettransport(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a packet through packettransport protocol with 'tid' from 'addr'.
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_RESPONSE, tid, addr);
}
void senddone_packettransport(uint16_t tid, uint16_t addr, int len, unsigned char *msg, int success) {
    /* We have received a packet transport ACK for the packet that we've sent out.
       - notify this event UP to the application (send_done event) */
    struct tid_list *t = tidlist_find_tid(tid);
    if (t == NULL) return;
    if (t->type == TRANS_TYPE_CLOSE) { // close transaction done
        check_close_done(tid);
    } else if (success) {
        send_toApp(NULL, 0, TRANS_TYPE_CMD_ACK, tid, addr);
    } else {
        send_toApp(NULL, 0, TRANS_TYPE_CMD_NACK, tid, addr);    // NACK - failed
        tidlist_remove_tid(tid);    // remove (don't need anymore)
    }
}
void receive_streamtransport(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a packet through streamtransport protocol with 'tid' from 'addr'.
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_RESPONSE, tid, addr);
}
void receive_rcrtransport(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a packet through rcrtransport protocol with 'tid' from 'addr'.
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_RESPONSE, tid, addr);
}
void receive_TCMP_ping_ack(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a TCMP ping ack
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_PING, tid, addr);
}
void receive_TCMP_tracert_ack(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a TCMP trace route ack
       - send this UP to the application */
    send_toApp(msg, len, TRANS_TYPE_TRACERT, tid, addr);
}
void receive_service_response(uint16_t tid, uint16_t addr, int len, unsigned char *msg) {
    /* We have received a response to the service requestion that we've sent:
       - either mote-world-global-time request, or
       - rfpower set request.
       Send the result UP to the application */
    send_toApp(msg, len, TRANS_TYPE_SERVICE, tid, addr);
}
void packettransport_tid_delete_done(uint16_t tid) {
    check_close_done(tid);
}
void streamtransport_tid_delete_done(uint16_t tid) {
    check_close_done(tid);
}
void rcrtransport_tid_delete_done(uint16_t tid) {
    check_close_done(tid);
}

