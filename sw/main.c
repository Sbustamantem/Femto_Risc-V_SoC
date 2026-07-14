#include "drivers/gpio.h"
#include "drivers/uart.h"

void delay_half_second() {
    for (int i = 3375000; i > 0; i--) {
        asm volatile (""); 
    }
}

int main(void) {

    gpio_init();
    uart_init();

    int count = 0;
    int state = 0; 

    uart_putstr("SoC Boot Successfully!\r\n");

    while (1) {
        
        gpio_write_leds(count);
        
        uart_putchar(count + '0'); 
        uart_putstr("\r\n"); 

        delay_half_second();

        // Counter logic
        if (state == 0) {
            count++;
            if (count >= 8) state = 1;
        } else {
            count -= 2;
            if (count <= 0) {
                count = 0;
                state = 0;
            }
        }
    }
}