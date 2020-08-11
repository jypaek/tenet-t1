includes EmStar;

interface EmSocketI
{
    command result_t ServerInit(char *name, int count);
    command result_t ClientInit(char *name);	

    // The nomenclature is based on the CLIENT's perspective
    // In other words, ReceiveMsg is a command: calling it will cause the
    // CLIENT to receive said message. And SendMsg is an event: when it
    // happens, the client has sent us a message
    command result_t ReceiveMsg(void *msg, int16_t length);

    // write a packet to a socket - note this is slightly different
    // functionality to the old emstar code
    command result_t WriteToSocket(void *msg, int16_t length,
	client_type_t client_type);

    event result_t SendMsg(void *msg, int16_t length);

    command int pd_unblock();
}
