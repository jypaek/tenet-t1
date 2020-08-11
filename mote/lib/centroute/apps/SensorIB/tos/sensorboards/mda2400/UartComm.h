#ifndef UARTCOMM_H
#define UARTCOMM_H

// Size of uart command buffer.  Only one byte each command so feel free to
// ..make larger if you need.
#define UART_BUFFER_SIZE 10

// Function declarations
task void service_command();
result_t enqueue_command(uint8_t data);
uint8_t dequeue_command();

task void return_response();
result_t enqueue_response(uint8_t data);
uint8_t dequeue_response();

result_t write_uart(uint8_t data);


#endif // UARTCOMM_H
