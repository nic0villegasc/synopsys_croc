// Copyright (c) 2026.
// Licensed under the Apache License, Version 2.0.
//
// IMU human-activity recognition on Croc (single-core Ibex).
// MLP (288 -> 32 -> 6) over a flattened window of 32 timesteps x 9 IMU channels.
// Reuses the SAME kernels as MNIST (nn_linear.c) -- no new code.

#include "uart.h"
#include "print.h"
#include "config.h"

#include "nn_linear.h"
#include "har_model.h"

// Class order (UCI HAR), must match train_export_har.py and har_model.h.
static void print_label(int c)
{
    switch (c) {
        case 0: printf("walking\n");          break;
        case 1: printf("walking_upstairs\n"); break;
        case 2: printf("walking_downstairs\n"); break;
        case 3: printf("sitting\n");          break;
        case 4: printf("standing\n");         break;
        case 5: printf("laying\n");           break;
        default: printf("?\n");               break;
    }
}

int main(void)
{
    uart_init();

    static uint8_t h[H];
    static int32_t logits[NUM_CLASS];

    // Layer 1: IMU window (uint8, asymmetric; zero-point folded into har_b1) -> 32 ReLU
    nn_linear_u8_relu(har_test_feat, har_W1, har_b1, h,
                      NUM_FEAT, H, har_out_mult1, har_out_shift1);
    // Layer 2: 32 -> 6 logits (no requant; argmax)
    nn_linear_out32(h, har_W2, har_b2, logits, H, NUM_CLASS);

    int pred = nn_argmax_i32(logits, NUM_CLASS);

    printf("HAR predicted activity: %x\n", (unsigned)pred);
    print_label(pred);
    printf("expected: %x\n", (unsigned)har_test_label);

    uart_write_flush();
    return 0;
}
