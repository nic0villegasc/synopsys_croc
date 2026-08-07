// Copyright (c) 2026 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
//
// Blinks GPIO pin 0 (wired to LD0 in rtl/fpga/croc_zedboard_top.sv) forever.
// Uses a plain mcycle-counted busy-wait instead of clint_sleep_ms(): CLINT's
// mtime ticks once per rising edge of ref_clk_i, and on the ZedBoard build
// ref_clk_i is currently tied to the 20 MHz system clock rather than a real
// ~32.768 kHz RTC, so clint_sleep_ms()'s hardcoded "33 ticks per ms" would
// be off by ~3 orders of magnitude there. mcycle counts actual core clock
// cycles, so this delay is accurate on both the Verilator sim (20 MHz) and
// the FPGA (20 MHz via the MMCM) without depending on that assumption.

#include "gpio.h"
#include "util.h"
#include "config.h"

#define LED_PIN 0

static void delay_ms(uint32_t ms) {
    uint64_t cycles = ((uint64_t)TB_FREQUENCY / 1000) * ms;
    uint64_t start  = get_mcycle();
    while ((get_mcycle() - start) < cycles) { }
}

int main() {
    gpio_pin_set_output(LED_PIN);
    gpio_pin_enable(LED_PIN);

    while (1) {
        gpio_pin_toggle(LED_PIN);
        delay_ms(500);
    }
}
