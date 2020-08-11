/* -*- Mode: C; tab-width: 4;c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */


//includes EmStar;
includes AM;
//includes emsocket;
includes emstar_interprocess; 
includes emtos_i; 
       
module EmSocketM
{
	provides {
		interface EmSocketI[uint8_t id];
		interface StdControl;
        interface ReceiveMsg;
	}
    uses {
      interface EmTimerI as SocketTimer;
    }

}



implementation {

  // number of socket connections between NesC and C that we will support
#define MAX_SOCKET_CONNECTIONS 100

  // return immediately if there is no data to read
#define SOCKET_CHECK_TIME 0

  // amount of time (in ms) between which we check for fresh data
#define SOCKET_TASK_TIME 100

/* default amount of time for a server to wait for clients to start 
 * (in seconds)
 */
#define CLIENT_CONNECT_TIME_DEFAULT 30

  // NOTE: duplicated from emstar_interprocess.h - otherwise we get
  // annoying nesc errors to do with function names
#define INTERPROCESS_MAX_READ_SIZE 300

  typedef enum _newSocketType_t
  {
    CONNECTION_SOCKET,
    DATA_SOCKET,
  } newSocketType_t;
  
  // arrays for socket and NesC unique ID.  Kept as 2 seperate
  // arrays for easy of copying.  Matching index in the two arrays
  // are a pair
  // NOTE: these sockets are for exchanging data, not server sockets
  // to establish connections
  static int socket_lookup[MAX_SOCKET_CONNECTIONS];
  static int id_lookup[MAX_SOCKET_CONNECTIONS];
  static client_type_t socket_type[MAX_SOCKET_CONNECTIONS];
  static int socket_count;

  // arrays for socket and NesC unique ID.  Kept as 2 seperate
  // arrays for easy of copying.  Matching index in the two arrays
  // are a pair
  // NOTE: these sockets are server sockets to establish connections,
  // not for data
  static int connection_socket_lookup[MAX_SOCKET_CONNECTIONS];
  static int connection_id_lookup[MAX_SOCKET_CONNECTIONS];
  static int connection_socket_count;

  int GetIdFromSocket(int in_socket, client_type_t *client_type)
  {
    int i;
    
    for (i=0; i<socket_count; i++)
      {
        if (socket_lookup[i] == in_socket)
          {
            // match!
            *client_type = socket_type[i];
            return id_lookup[i];
          }
      }

    // couldn't find an id matching this socket
    return -1;

  }

  int GetSocketFromId(int id, client_type_t client_type)
  {
    int i;
    
    for (i=0; i<socket_count; i++)
      {
        if ((id_lookup[i] == id) && (socket_type[i] == client_type))
          {
            // match!
            return socket_lookup[i];
          }
      }

    // couldn't find a socket matching this id
    return -1;

  }

  void AddNewServerConnection(int connection, int id)
  {
    connection_socket_lookup[connection_socket_count] = connection;
    connection_id_lookup[connection_socket_count] = id;
    
    connection_socket_count++;
    
  }

  int add_new_client(int socket_id, int id)
  {
    dbg(DBG_ERROR, "Adding new client socket: %d socket, %d id, count %d\n",
        socket_id, id, socket_count);

    socket_lookup[socket_count] = socket_id;
    id_lookup[socket_count] = id;
    socket_type[socket_count] = CLIENT_TYPE;
    
    socket_count++;

    return 1;
  }

  int AddNewClientConnection(int server_connection)
  {
    int i;

    if (socket_count == 0)
      {
        dbg(DBG_ERROR, "Asked to create a new client socket, but no sockets made!\n");
        return -1;
      }

    // find the nesc id that corresponds to this socket number
    for (i=0; i<connection_socket_count; i++)
      {
        if (connection_socket_lookup[i] == server_connection)
          {
            // found a match!
            dbg(DBG_ERROR, "Found match on server socket %d!\n", server_connection);
            id_lookup[socket_count - 1] = connection_id_lookup[i];
            socket_type[socket_count - 1] = SERVER_TYPE;
            return 1;
          }
      }
    
    dbg(DBG_ERROR, "Couldn't find match for server socket %d\n", 
        server_connection);
    return -1;
  }


  /*
   * Sending packet from C code into NesC code
   */
int send_to_nesc(uint8_t id, void *msg, int16_t length) 
{
  
  if (id == -1)
    {
      dbg(DBG_ERROR, "Bad Socket to get data from %d!\n", id);
      return FAIL;
    }

    return (signal EmSocketI.SendMsg[id](msg, length));
}


command result_t StdControl.init() 
{
  emtos_state_t *emt = emstar_getState();

  if (emt == NULL)
    {
      dbg(DBG_ERROR, "Uh oh - emt not set yet!\n");
    }
  else
    {
      emt->client_cb = add_new_client;
    }
  /*
  memset(&socket_lookup, 0, sizeof(socket_lookup)); 
  memset(&id_lookup, 0, sizeof(id_lookup)); 
  socket_count = 0;

  memset(&connection_socket_lookup, 0, sizeof(connection_socket_lookup)); 
  memset(&connection_id_lookup, 0, sizeof(connection_id_lookup)); 
  connection_socket_count = 0;
  */
  

  return SUCCESS;
}

//task void WaitForConnection()
event result_t SocketTimer.fired()
{
  char *buf_read;
  int length_read;
  int out_id;
  int ready_sock;
  client_type_t client_type = SERVER_TYPE;

  emstar_select_ret_t ret;

  buf_read = malloc(INTERPROCESS_MAX_READ_SIZE);
  if (buf_read == NULL)
    {
      dbg(DBG_ERROR, "Unable to malloc read buffer!\n");
      return FAIL;
    }

  dbg(DBG_USR3, "Starting EmSocketM task %d connection sockets, %d client sockets, client socket numbers %d, %d, %d!\n",
      connection_socket_count, socket_count, socket_lookup[0], 
      socket_lookup[1], socket_lookup[2]);

  // loop forever processing incoming packets
  while (1)
    {
      
      ret = emstar_link_select(&connection_socket_lookup[0],
                               connection_socket_count,
                               &socket_lookup[0], &socket_count, 
                               buf_read, &length_read, 
                               SOCKET_CHECK_TIME, &ready_sock, SELECT_OK);
      if (ready_sock < 0)
        {
          dbg(DBG_ERROR, "Uh oh: Error waiting on socket\n");
        }
      else if (ready_sock == 0)
        {
          // no data ready yet, check at next timeout
          return SUCCESS;
        }
      else
        {
          // did we get a new connection on a server socket, or 
          // data
          if (ret == SELECT_NEW_CLIENT)
            {
              // new client connection
              if (AddNewClientConnection(ready_sock) < 0)
                {
                  dbg(DBG_ERROR, "Un oh: Unable to add client connection!\n");
                }
            }
          else if (ret == SELECT_NEW_DATA)
            {
              // data on a client connection
              
              // find the NesC id that matches the socket number
              out_id = GetIdFromSocket(ready_sock, &client_type);
              dbg(DBG_ERROR, "Got data on a client connection, from socket %d, to id %d, %d bytes, socket type %d!\n", 
                  ready_sock, out_id, length_read, client_type);
              if (client_type == CLIENT_TYPE)
                {
                  dbg(DBG_ERROR, "Client type packet!\n");
                  pkt_rcvd((link_pkt_t *)buf_read, length_read);
                }
              else if (client_type == SERVER_TYPE)
                {
                  dbg(DBG_ERROR, "Server type packet!\n");
                  signal EmSocketI.SendMsg[out_id](buf_read, length_read);
                }
              else
                {
                  dbg(DBG_ERROR, "Oh noes, invalid client type %d\n", 
                      client_type);
                }

              buf_read = malloc(INTERPROCESS_MAX_READ_SIZE);
              if (buf_read == NULL)
                {
                  dbg(DBG_ERROR, "Unable to malloc read buffer!\n");
                  return FAIL;
                }
            }
          else
            {
              // no data ready yet, check next timeout
              return SUCCESS;
            }
        }
    }
  
  // should never get here
  return FAIL;

}

command result_t StdControl.start()
{
  if (call SocketTimer.start(TIMER_REPEAT, SOCKET_TASK_TIME) != SUCCESS)
    {
      dbg(DBG_ERROR, "Oh noes, couldn't start socket timer!\n");
    }

  return SUCCESS;
}



command result_t StdControl.stop()
{

	return SUCCESS;
}




/* Initialise a socket server to communicate between the NesC code
 * and C code
 */

 command result_t EmSocketI.ServerInit[uint8_t id](char *name, int count)
{
  
  int new_sock;

  dbg(DBG_ERROR, "About to create Server from EmSocket, up to %d connections!\n", count);

  new_sock = emstar_link_server_create(name, count);
  if (new_sock <= 0)
    {
      dbg(DBG_ERROR, "Failed to create connections from server!\n");
      return FAIL;
    }

  AddNewServerConnection(new_sock, id);
  

	return SUCCESS;
}

/*
 * Do we even need this function?
 */

command result_t EmSocketI.ClientInit[uint8_t id](char *name)
{
	
	return SUCCESS;
}


 command result_t EmSocketI.WriteToSocket[uint8_t id](void *msg, 
                                                      int16_t length,
                                                      client_type_t client_type)
{
  int out_sock = GetSocketFromId(id, client_type);

  dbg(DBG_ERROR, "Sending a packet to a socket %p, length %d, socket %d, id %d!\n",
      msg, length, out_sock, id);

	if (msg==NULL || length <= 0) {
      dbg(DBG_ERROR, "Bad msg ptr or length\n");
		return FAIL;
	}
    else if (out_sock <= 0)
      {
        dbg(DBG_ERROR, "Bad out socket\n");
        return FAIL;
      }
    else {
      
      if (emstar_link_write(out_sock, msg, length) < 0)
        {
          dbg(DBG_ERROR, "Unable to write!\n");
          return FAIL;
        }

	}

    return SUCCESS;

}

/*
 * Sending a packet from NesC to C code
 */

command result_t EmSocketI.ReceiveMsg[uint8_t id](void *msg, int16_t length)
{
  // FIXME: is this always the client type?
  int out_sock = GetSocketFromId(id, CLIENT_TYPE);

  dbg(DBG_ERROR, "Sending a packet to the emstar link %p, length %d!\n",
      msg, length);

	if (msg==NULL || length <= 0) {
      dbg(DBG_ERROR, "Bad msg ptr or length\n");
		return FAIL;
	}
    else if (out_sock <= 0)
      {
        dbg(DBG_ERROR, "Bad out socket\n");
        return FAIL;
      }
    else {
      
      signal ReceiveMsg.receive(msg);

	}

    return SUCCESS;

}


default event result_t EmSocketI.SendMsg[uint8_t id]
		(void *msg, int16_t length)
{
  dbg(DBG_ERROR, "Oh noes, bad id\n");
  return FAIL;
}


default event TOS_Msg *ReceiveMsg.receive(TOS_Msg *msg)
{
  dbg(DBG_ERROR, "Oh noes, bad id for ReceiveMsg.receive\n");
	return NULL;
}

command int EmSocketI.pd_unblock[uint8_t id]()
{
  return SUCCESS;
}


}




