module UartCommM {
  provides interface StdControl as UartControl;
  provides interface UartCommI as UartComm;

  uses interface Leds;
}
implementation {
#include "UartComm.h"

  // FIFO buffer to hold incoming UART commands
  uint8_t command_buffer[UART_BUFFER_SIZE];
  // command buffer head and tail pointer
  uint8_t command_buffer_head;
  uint8_t command_buffer_tail;
  uint8_t num_elements_command_buffer;

  // FIFO buffer to hold UART response data
  uint8_t response_buffer[UART_BUFFER_SIZE];
  // response buffer head and tail pointer
  uint8_t response_buffer_head;
  uint8_t response_buffer_tail;
  uint8_t num_elements_response_buffer;

  /********************************************************
   * UartControl implementation
   * Setup UART1 registers to prepare communication with the MDA2400
   ********************************************************/
  command result_t UartControl.init() {
    // Initialize buffers and pointers
    memset(command_buffer, 0, UART_BUFFER_SIZE);
    memset(response_buffer, 0, UART_BUFFER_SIZE);

    // To keep the compiler from complaining this is atomic (no interrupts
    // ..should be happening during initialization)
    atomic {
      command_buffer_head = 0;
      command_buffer_tail = 0;
      num_elements_command_buffer = 0;
      response_buffer_head = 0;
      response_buffer_tail = 0;
      num_elements_response_buffer = 0;
    }

    return SUCCESS;
  }

  // Initialize UART1 to 38.4 KBps and 8-N-1 frame format
  // Enable both send and receive registers and their associated interrupts
  command result_t UartControl.start() {
    // Set 38.4 KBps
    outp(0, UBRR1H);
    outp(11,UBRR1L);
    
    // Enable reciever and transmitter and their interrupts
    outp(((1 << RXCIE) | (1 << TXCIE) | (1 << RXEN) | (1 << TXEN)), UCSR1B);
    
    // Set frame format: 8 data-bits, 1 stop-bit, no parity
    outp(((1 << UCSZ1) | (1 << UCSZ0)), UCSR1C);

    return SUCCESS;
  }

  // Turn off the UART
  command result_t UartControl.stop() {
    outp(0x00, UCSR1A);
    outp(0x00, UCSR1B);
    outp(0x00, UCSR1C);
    return SUCCESS;
  }

  /***********************************************************
   * Error handling functions
   ***********************************************************/

  // Something went wrong, signal up
  task void taskFail() {
    signal UartComm.dataResponse(0, FAIL);
  }

  /***********************************************************
   * Buffer management functions
   *  - Both send and receive buffers will be FIFO.
   *  - If the buffers fill, data will be dropped with an error notification
   *    sent up.
   ***********************************************************/

  task void service_command() {
    // Grab the oldest command from the buffer
    uint8_t data = dequeue_command();

    // If command exists, send it out over Uart
    if (data != 0) {
      write_uart(data);
    }
  }

  // Add a command into the command buffer.  No need to make these operations
  // ..atomic as they will not be called from an interrupt context.  Return 
  // ..SUCCESS if there is room, FAIL if there is not.
  result_t enqueue_command(uint8_t data) {
    result_t result;

    // Atomic access to the buffers
    atomic {
      // Make sure the buffer is not full
      if (num_elements_command_buffer >= UART_BUFFER_SIZE) {
        result = FAIL;
      }
      else {
        // Enqueue the command
        command_buffer[command_buffer_tail] = data;
        
        // Increment the element count.
        num_elements_command_buffer++;
        
        // Move the tail
        if (command_buffer_tail == UART_BUFFER_SIZE - 1) {
          command_buffer_tail = 0;
        }
        else {
          command_buffer_tail++;
        }
        
        // If this is the first command in an empty buffer, send it out.
        if (num_elements_command_buffer == 1)
          post service_command();

        result = SUCCESS;
      }
    } // end atomic

    return result;
  }

  // Remove and service a command from the command buffer.  This function can be
  // ..called from an interrupt context so we need to be careful.
  uint8_t dequeue_command() {
    uint8_t command_tosend;

    // Makes this a bit safer as it can be called from an interrupt context
    atomic {
      // Make sure the buffer is not empty
      if (num_elements_command_buffer == 0) {
        command_tosend = 0;
      }
      else {
        // Grab the command
        command_tosend = command_buffer[command_buffer_head];
        
        // Zero out the command
        command_buffer[command_buffer_head] = 0;
        
        // Decrement the element count.
        num_elements_command_buffer--;
        
        // Move the head forward
        if (command_buffer_head == UART_BUFFER_SIZE - 1) {
          command_buffer_head = 0;
        }
        else {
          command_buffer_head++;
        }
      }
    } // end atomic

    // Send command out over UART.
    return command_tosend;
   }

  // Called when a response is received from the uart.  Queue into the response
  // ..buffer to wait to be shipped up.
  result_t enqueue_response(uint8_t data) {
    result_t result;

    // Insert into queue atomically
    atomic {
      // Check for room
      if (num_elements_response_buffer >= UART_BUFFER_SIZE) {
        result = FAIL;
      }
      else {
        // Insert the byte
        response_buffer[response_buffer_tail] = data;
        
        // Increment the element count.
        num_elements_response_buffer++;
        
        // Move the tail
        if (response_buffer_tail == UART_BUFFER_SIZE - 1) {
          response_buffer_tail = 0;
        }
        else {
          response_buffer_tail++;
        }
        
        // Send the response back up
        post return_response();

        result = SUCCESS;
      }
    } //end atomic
    
    return result;
  }
  
  // Grabs a response off the response buffer
  uint8_t dequeue_response() {
    uint8_t response;
    
    // Makes this a bit safer as it can be called from an interrupt context
    atomic {
      // Grab the response
      response = response_buffer[response_buffer_head];
      
      // Zero out the response
      response_buffer[response_buffer_head] = 0;
      
      // Decrement the element count.
      num_elements_response_buffer--;
      
      // Move the head forward
      if (response_buffer_head == UART_BUFFER_SIZE - 1) {
        response_buffer_head = 0;
      }
      else {
        response_buffer_head++;
      }
    } // end atomic

    return response;
  }

  // Task to return the oldest uart response in the buffer up
  task void return_response() {
    uint8_t response;

    // Make sure the buffer is not empty (guard access to
    // ..num_elemenes_response_buffer)
    atomic {
      if (num_elements_response_buffer == 0) {
        post taskFail();
      }
      else {
        // Grab the oldest response from the buffer
        response = dequeue_response();
        
        // Send the response up
        signal UartComm.dataResponse(response, SUCCESS);
      }
    }
  }
    
  /************************************************************************
   * Uart Control functions
   *  - These send commands out over the UART and receive interrupts when a
   *    command has successfully been sent and when data has been received.
   ************************************************************************/

  result_t write_uart(uint8_t data) {
    atomic {
      // Wait for an empty transmit buffer
      while ( !(UCSR1A & (1 << UDRE)) )
        ;
      // Copy byte to transmit register
      outp(data, UDR1);
    }

    return SUCCESS;
  }

  // Interrupt triggered when a USART send has completed.
  TOSH_INTERRUPT(SIG_UART1_TRANS) {
    uint8_t next_command;
   
    // Attempt to send the next command if available.
    if ((next_command = dequeue_command()) != 0) {
      write_uart(next_command);
    }
  }

  // Interrupt triggered when a USART receive has completed.  We must read
  // ..UCSRnA to clear the interrupt.
  TOSH_SIGNAL(SIG_UART1_RECV) {
    // Read in the UART status register
    uint8_t status = inp(UCSR1A);
    uint8_t recv;

    // Check to be sure RXC is set (Not necesary, interrupt can only be raised
    // ..if that bit is set)
    if (status & (1 << RXC)) {
      // Read the data from the register
      recv = inp(UDR1);

      // Make sure no error bits were set
      if (status & ((1<<FE) | (1<<DOR) | (1<<UPE)))
        call Leds.redOn();

      // Insert the byte into its correct location in the receive buffer.
      if (enqueue_response(recv) == FAIL) {
        // Uh oh failed to move into buffer.  Signal FAIL
        post taskFail();
      }
    }
  }

  // Main entrance to this module.  Shove the command into the command buffer.
  command result_t UartComm.sendCommand(uint8_t data) {
    return enqueue_command(data);
  }
}

