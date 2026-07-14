#include "gpio.h"


#define LED_REG (*(volatile unsigned int*)0x00010000)

void gpio_init(void) {

    LED_REG = 0;
}

void gpio_write_leds(unsigned int value) {
    LED_REG = value;
}