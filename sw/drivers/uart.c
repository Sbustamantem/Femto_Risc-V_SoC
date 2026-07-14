
#include "uart.h"

#define UART_DATA   (*(volatile unsigned int*)0x00020000)
#define UART_STATUS (*(volatile unsigned int*)0x00020004)

void uart_init(void) {

}

void uart_putchar(char c) {
    while (UART_STATUS & 1); 
    UART_DATA = c;
}

void uart_putstr(const char* str) {
    while (*str) {
        uart_putchar(*str++);
    }
}