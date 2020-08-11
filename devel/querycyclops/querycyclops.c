
/**
 * @modified 7/2/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/
 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <stddef.h>
#include <stdint.h>
#include <signal.h>
#include <unistd.h>

#include "TestCyclopsMsg.h"
#include "cyapp_util.h"
#include "cyclops_query.h"
#include "tosmsg.h"
#include "tosserial.h"
#include "sfsource.h"
#include "serialsource.h"

int sf_fd;              // serial forwarder socket fd
serial_source src = 0;  // serial port source
int fromsf = -1;        // whether we are connecting to sf or serial

uint16_t m_dst_addr = 0xffff;       // send query to which addr
query_state_t m_qstate;
result_item_t *outlist = NULL;      // list of result items (each from different nodes)

/*************************************************************/

void query_send(query_state_t *p) {
    char buf[128]; /* Allocate a buffer for the entire packet structure */
    int len;

    memset(buf, 0, sizeof(buf));    // clear buffer

    TestCyclopsMsg_t *c_pkt = (TestCyclopsMsg_t *)buf;
    cyclops_query_t *qmsg = (cyclops_query_t *)c_pkt->data;

    /*******************INIT link_pkt header******************/
    c_pkt->sender = 0xffff;     // sender address... don't care
    c_pkt->qid  = p->tid;
    c_pkt->type = 1;            // start

    /**********************************************************/
    qmsg->nSignal     = p->nSignal;

    /**********************************************************/
    if (p->nSignal == NEURON_ACTIVE_EYE) {
        if (p->activeQ.type == ACTIVE_EYE_GET_PARAMS) {
            qmsg->length = offsetof(activeEye_query_t, cp);
            printf("offsetof(activeEyeQ,offset) %d", qmsg->length);
        } else {
            qmsg->length = sizeof(activeEye_query_t);
            printf("sizeof(activeEyeQ) %d", qmsg->length);
        }
        memcpy((char *)qmsg->data, (char *)&p->activeQ, qmsg->length);
    } 
    else if (p->nSignal == NEURON_GET_IMAGE) {
        qmsg->length = sizeof(getImage_query_t);
        memcpy(&p->getImageQ.snapQ, &p->snapQ, sizeof(p->snapQ));
        memcpy((char *)qmsg->data, (char *)&p->getImageQ, qmsg->length);
        printf("sizeof(getImageQ) %d", sizeof(getImage_query_t));
    }
    else if (p->nSignal == NEURON_SNAP_ONLY) {
        qmsg->length = sizeof(snap_query_t);
        memcpy((char *)qmsg->data, (char *)&p->snapQ, qmsg->length);
        printf("sizeof(snapQ) %d", sizeof(snap_query_t));
    }
    else if (p->nSignal == NEURON_DETECT_OBJECT) {
        if (p->activeQ.type == DETECT_SET_PARAM) {
            qmsg->length = sizeof(detect_query_t);
            printf("sizeof(dDetectQ) %d", sizeof(detect_query_t));
        } else {
            qmsg->length = offsetof(detect_query_t, detectParam);
            printf("offsetof(detectQ) %d", offsetof(detect_query_t, detectParam));
        }
        memcpy(&p->detectQ.snapQ, &p->snapQ, sizeof(p->snapQ));
        memcpy((char *)qmsg->data, (char *)&p->detectQ, qmsg->length);
    }
    else if (p->nSignal == NEURON_GET_RLE_IMAGE) {
        qmsg->length = sizeof(getRle_query_t);
        memcpy(&p->getRleQ.snapQ, &p->snapQ, sizeof(p->snapQ));
        memcpy((char *)qmsg->data, (char *)&p->getRleQ, qmsg->length);
        printf("sizeof(getRleQ) %d", sizeof(getRle_query_t));
    }
    else if (p->nSignal == NEURON_GET_PACKBITS_IMAGE) {
        qmsg->length = sizeof(getPackBits_query_t);
        memcpy(&p->getPackBitsQ.snapQ, &p->snapQ, sizeof(p->snapQ));
        memcpy((char *)qmsg->data, (char *)&p->getPackBitsQ, qmsg->length);
        printf("sizeof(getPackBitsQ) %d", sizeof(getPackBits_query_t));
    }
    else if (p->nSignal == NEURON_COPY_IMAGE) {
        qmsg->length = sizeof(copy_query_t);
        memcpy(&p->copyQ.snapQ, &p->snapQ, sizeof(p->snapQ));
        memcpy((char *)qmsg->data, (char *)&p->copyQ, qmsg->length);
        printf("sizeof(copyQ) %d", sizeof(copy_query_t));
    }
    else {
        printf("BUG\n");
        exit(0);
    }

    /**********************************************************/
    len =  offsetof(TestCyclopsMsg_t, data) + offsetof(cyclops_query_t, data) + qmsg->length;
    printf(" + offsetof(qMsg) %d", offsetof(cyclops_query_t, data));
    printf(" + offsetof(cMsg) %d = len %d\n", offsetof(TestCyclopsMsg_t, data), len);
    
    if (fromsf == 1)
        send_TOS_Msg(sf_fd, buf, len, 0x06, m_dst_addr, 0x7d);
    else
        send_TOS_Msg_serial(src, buf, len, 0x06, m_dst_addr, 0x7d);
}


void cancel_query(query_state_t *p) {
    char buf[100];
    int len;
    TestCyclopsMsg_t *c_pkt = (TestCyclopsMsg_t *)buf;
    c_pkt->sender = 0xffff;
    c_pkt->qid  = p->tid;
    c_pkt->type = TEST_CYCLOPS_MSG_TYPE_CANCEL;
    len = offsetof(TestCyclopsMsg_t, data);
    printf("terminating query %d\n", p->tid);
    if (fromsf == 1)
        send_TOS_Msg(sf_fd, buf, len, 0x06, m_dst_addr, 0x7d);
    else
        send_TOS_Msg_serial(src, buf, len, 0x06, m_dst_addr, 0x7d);
}


/* Ctrl-C handler */
void sig_int_handler(int signo) {
    struct result_item *r;
    for (r = outlist; r; r = r->next) {
        if (r->incomplete_image) {
            if (r->data_type == CYCLOPS_RESPONSE_IMAGE)
                output_result_to_file(&m_qstate, r);
            else
                printf("un-decodable incomplete data reception\n");
        }

        printf("mote %d: num_pkts %d ", r->addr, r->num_pkts);
        if (m_qstate.numExpectedPkts > 0)
            printf("(%.1lf%%) ", 100.0*r->num_pkts/(r->image_cnt*m_qstate.numExpectedPkts));
        if (r->image_cnt)
            printf("num_images %d ", r->image_cnt);
        printf("received\n");
    }
    remove_outlist(&outlist);
    //cancel_query(&m_qstate);
    exit(0);
}

/* decode simple RLE directly (does not buffer) from *in to *out */
int decode_rle(char *in, int inlen, char *out) {
    unsigned char val, runlen;
    int codelen = 0;
    int rawlen = 0;
    while (codelen < inlen) {
        val = (unsigned char) in[codelen++];
        runlen = (unsigned char) in[codelen++];

        while (runlen > 0) {
            out[rawlen++] = val;
            if (rawlen > BUF_SIZE) break;   // error, abort
            runlen--;
        }
        if (rawlen > BUF_SIZE) {
            printf("invalid (decoded) data length during simple RLE decoding.\n");
            break;   // error, abort
        }
    }
    return rawlen;
}

/* decode PackBits RLE from *in to *out */
int decode_packbits(char *in, int inlen, char *out) {
    char outbuf[BUF_SIZE];
    unsigned char val;      /* current character */
    char lenbyte;           /* (signed) run/copy count */
    int runlen;             /* actual run length */
    int rawlen = 0;
    int codelen = 0;

    while (codelen+1 < inlen) {
        lenbyte = in[codelen++];

        if (lenbyte < 0) {
            runlen = 1 - (int)lenbyte;

            val = in[codelen++];
            while (runlen > 0) {
                outbuf[rawlen++] = val;
                if (rawlen > BUF_SIZE) break;   // error, abort
                runlen--;
            }
        } else {
            runlen = 1 + (int)lenbyte;
            while (runlen > 0) {
                val = in[codelen++];
                outbuf[rawlen++] = val;
                if (rawlen > BUF_SIZE) break;   // error, abort
                runlen--;
                if (codelen >= inlen)
                    break;
            }
        }
        if (rawlen > BUF_SIZE) {
            printf("invalid (decoded) data length during PackBits RLE decoding.\n");
            break;   // error, abort
        }
    }
    memcpy(out, outbuf, rawlen);
    return rawlen;
}

/* Received a response packet from the cyclops node */
void response_receiver(query_state_t *p, unsigned char* packet, int len) {
    result_item_t *r;
    /* Get a pointer to the data portion of the the link packet */
    TestCyclopsMsg_t *r_pkt = (TestCyclopsMsg_t *) packet;
    /* Get a pointer to the data portion and type cast appropriately */
    cyclops_response_t * cResp = (cyclops_response_t *) r_pkt->data;

    printf("Received from cyclops: %d QID: %d ", r_pkt->sender, r_pkt->qid);
    printf("tclen/crlen (%d/%d) ", len, len - offsetof(TestCyclopsMsg_t, data));

    if (p->tid  != r_pkt->qid) {
        printf("got a packet not meant for us - filter failed!\n");
        return;
    }

    r = find_outitem(outlist, r_pkt->sender);  // find the result item for this node
    if (r == NULL)
        r = add_outitem(&outlist, r_pkt->sender);
    r->num_pkts++;      // number of packets received from this node
    //r = &m_rstate;

    if (cResp->type == CYCLOPS_RESPONSE_IMAGE) {
        char *currentbufPtr;
        image_response_t *ir = (image_response_t *) cResp->data;

        if (ir->fragNum < r->lastpkt)
            output_result_to_file(p, r);

        //Set pointer to correct buffer location based on fragment number.
        currentbufPtr = &r->buffer[(ir->fragNum - 1) * p->getImageQ.fragmentSize];
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        r->data_type = CYCLOPS_RESPONSE_IMAGE;
        printf("Fragment [%d/%d] RecvBytes [%d]\n", ir->fragNum, ir->fragTotal, r->recv_bytes);
        
        if (ir->fragNum == ir->fragTotal ) {        // when we receive LAST packet
            r->incomplete_image = 0;
            output_result_to_file(p, r);            // output result to a file
            r->lastpkt = 0;
        } else { //if (ir->fragNum < ir->fragTotal) // for any packets >1 && <Total
            r->incomplete_image = 1;
            r->lastpkt = ir->fragNum;
        }
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_CAPTURE_PARAM) {
        capture_param_t *cp = (capture_param_t *)cResp->data;
        print_neuron_module_name(p->nSignal);
        print_capture_parameters(cp);
    }
    else if (cResp->type == CYCLOPS_RESPONSE_RESULT) {
        result_response_t *dr = (result_response_t *) cResp->data;
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query result = %d\n", dr->result);
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_FAIL) {
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query execution FAIL.\n");
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_SUCCESS) {
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query execution SUCCESS.\n");
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_RLE_IMAGE) {
        char *currentbufPtr;
        rle_image_response_t *ir = (rle_image_response_t *) cResp->data;

        r->recv_bytes += ir->dataLength;
        printf("StartByte [%d] RecvBytes [%d]\n", ir->seqNum, r->recv_bytes);
        
        currentbufPtr = &r->buffer[ir->seqNum];  // assume reliable delivery
        decode_rle((char *)ir->data, ir->dataLength, currentbufPtr);

        if (cResp->more_left == 0) {
            r->incomplete_image = 0;
            r->data_type = CYCLOPS_RESPONSE_IMAGE;
            output_result_to_file(p, r);
        } else { // more_left == 1
            r->incomplete_image = 1;
        }
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_PACKBITS_IMAGE) {
        char *currentbufPtr;
        rle_image_response_t *ir = (rle_image_response_t *) cResp->data;

        currentbufPtr = &r->buffer[r->recv_bytes];  // assume reliable delivery
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        printf("SeqNum [%d] RecvBytes [%d]\n", ir->seqNum, r->recv_bytes);

        if (ir->seqNum != (r->lastpkt+1)) {
            printf("Error: SeqNum %d >> LastPkt %d\n", ir->seqNum, r->lastpkt);
            printf("PackBits RLE will work only with 100%% reliable data delivery!!\n");
        }

        if (cResp->more_left == 0) {
            decode_packbits(r->buffer, r->recv_bytes, r->buffer);
            r->data_type = CYCLOPS_RESPONSE_IMAGE;      // after decoding
            r->incomplete_image = 0;
            output_result_to_file(p, r);
            r->lastpkt = 0;
        } else { // more_left == 1
            r->data_type = CYCLOPS_RESPONSE_PACKBITS_IMAGE;  // before decoding
            r->incomplete_image = 1;
            r->lastpkt = ir->seqNum;
        }
    }
}


void print_usage(char* argv0) {
    printf("\n############# Query Cyclops Testing Program ##############\n\n");
    printf("Usage: %s sf <host> <port> [OPTIONS]\n", argv0);
    printf("       - connect to serial forwarder and do [OPTIONS].\n\n");
    printf("Usage: %s serial <device> <rate> [OPTIONS]\n", argv0);
    printf("       - connect to serial port and do [OPTIONS].\n\n");
    printf("Usage: %s -h\n", argv0);
    printf("       - display this help message.\n\n");
    printf("Usage: %s -a\n", argv0);
    printf("       - display detailed help message for [OPTIONS].\n\n");
    printf("Example:\n");
    printf("       %s serial /dev/ttyUSB5 57600\n", argv0);
    printf("       %s serial /dev/ttyUSB5 57600 SIZE 64 64 IMAGETYPE COLOR\n", argv0);
    printf("       %s sf 127.0.0.1 9000 MODULE ACTIVE_EYE EYETYPE GET\n", argv0);
    printf("       %s sf 127.0.0.1 9000 MODULE GET_RLE THRESH 10\n", argv0);
    printf("\n");
    exit(1);
}


void process_arguments(int argc, char *argv[], query_state_t *p)
{
    int ind;
    char sf_host[200];
    int sf_port;

    /* set bunch of DEFAULT values */
    strcpy(sf_host, "127.0.0.1");
    sf_port = 9000;

    set_query_defaults(p);

    for (ind = 1; ind < argc; ind++) {

        if (strncmp(argv[ind], "-h", 2) == 0) {
            print_usage(argv[0]);
        } else if (strncmp(argv[ind], "-a", 2) == 0) {
            print_cyclops_option_usage();
            exit(0);
        } else if ((ind + 1) >= argc) {
            printf("Wrong formatting of arguments... %s\n", argv[ind]);
            print_usage(argv[0]);
        } 
        
        if (strncasecmp(argv[ind], "sf", 2) == 0) {
            sf_fd = open_sf_source(argv[ind+1], atoi(argv[ind+2]));
            if (sf_fd < 0) {
                fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[ind+1], argv[ind+2]);
                exit(1);
            }
            fromsf = 1;
            ind += 2;
        } else if (strncasecmp(argv[ind], "serial", 2) == 0) {
            src = open_serial_source(argv[ind+1], atoi(argv[ind+2]), 0, stderr_serial_msg);
            if (!src) {   
                fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[ind+1], argv[ind+2]);
                exit(1);
            }
            fromsf = 0;
            ind += 2;
        }

    /************ Generic options ***********/
        else if ((strncmp(argv[ind], "CYCLOPS", 4) == 0) ||
            (strncmp(argv[ind], "ADDRESS", 4) == 0)) {
            m_dst_addr = atoi(argv[++ind]);   //sets the destination
        }
        else if (strncmp(argv[ind], "QID", 3) == 0) {
            p->tid = atoi(argv[++ind]);    //sets the QID, queryID
        }
        else if ((ind = parse_single_argument(argv, ind, p)) < 0) {
            print_usage(argv[0]);
        }
    }

    /* either one of 'sf' or 'serial' must have been selected */
    if (fromsf < 0)
        print_usage(argv[0]);
    
    /* check the query options/arguments for errors, such as image size error */
    check_img_size(p);  /* Do not remove this.... this is required!!! */
    
    /* print out the selected options, including defaults */
    printf("CYCLOPS-ADDR = %d\n", m_dst_addr);

    print_query_state(p);
    
}

/***************** main *****************/
int main(int argc, char *argv[]) {
    printf("\n<< Query Cyclops and get response >>\n\n");
    
    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
        
    /* clean up our state variable */
    memset(&m_qstate, 0, sizeof(query_state_t));

    /* parse command line arguements */
    process_arguments(argc, argv, &m_qstate);

    /* send query */
    query_send(&m_qstate);
    
    while(1) {
        unsigned char *packet;
        int len;

        /* read packet from serial or serial forwarder */
        if (fromsf == 1) {
            packet = read_sf_packet(sf_fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        if (!packet) exit(0);

        TOS_Msg *tosmsg = (TOS_Msg *) packet;
        /* received correct packet for this application */
        if (tosmsg->type == AM_QUERY_CYCLOPS) {
            response_receiver(&m_qstate, tosmsg->data, tosmsg->length);
        } else {
            int i;
            printf("Unknown: ");
            for (i = 0; i < len; i++) printf("%02x ", packet[i]);
            printf("\n");
        }
        fflush(stdout);
        free((void *)packet);
    }
}


