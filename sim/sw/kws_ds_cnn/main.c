// Copyright (c) 2026.
// Licensed under the Apache License, Version 2.0.
//
// "Hey Croc" keyword spotting via a reduced DS-CNN on Croc (single-core Ibex).
// Input MFCC [25x10x1] -> conv1(3x3 s2 valid) -> 2x[depthwise 3x3 + pointwise 1x1]
//                      -> global avg pool -> FC -> argmax.
// Uses nn_conv.c (conv/pool) + nn_linear.c (final FC + argmax).

#include "uart.h"
#include "print.h"
#include "config.h"

#include "nn_conv.h"
#include "nn_linear.h"
#include "dscnn_model.h"

#define MAXFM (C1_H * C1_W * DS_C)   // largest feature map (conv1 output)

static void print_label(int c)
{
    switch (c) {
        case 0:  printf("silence\n"); break;
        case 1:  printf("unknown\n"); break;
        case 2:  printf("yes\n");     break;
        case 3:  printf("no\n");      break;
        case 4:  printf("up\n");      break;
        case 5:  printf("down\n");    break;
        case 6:  printf("left\n");    break;
        case 7:  printf("right\n");   break;
        case 8:  printf("on\n");      break;
        case 9:  printf("off\n");     break;
        case 10: printf("stop\n");    break;
        case 11: printf("go\n");      break;
        default: printf("?\n");       break;
    }
}

static uint8_t bufA[MAXFM];
static uint8_t bufB[MAXFM];
static uint8_t pooled[DS_C];
static int32_t logits[NUM_CLASS];

int main(void)
{
    uart_init();

    int H, W;
    nn_conv2d_u8_relu(ds_test_feat, IN_T, IN_F, IN_C,
                      ds_conv1_w, ds_conv1_b, bufA, DS_C, 3, 3, 2,
                      ds_conv1_mult, ds_conv1_shift, &H, &W);

    nn_depthwise3x3_u8_relu(bufA, H, W, DS_C, ds_dw1_w, ds_dw1_b, bufB,
                            ds_dw1_mult, ds_dw1_shift);
    nn_pointwise_u8_relu(bufB, H, W, DS_C, ds_pw1_w, ds_pw1_b, bufA, DS_C,
                         ds_pw1_mult, ds_pw1_shift);

    nn_depthwise3x3_u8_relu(bufA, H, W, DS_C, ds_dw2_w, ds_dw2_b, bufB,
                            ds_dw2_mult, ds_dw2_shift);
    nn_pointwise_u8_relu(bufB, H, W, DS_C, ds_pw2_w, ds_pw2_b, bufA, DS_C,
                         ds_pw2_mult, ds_pw2_shift);

    nn_avgpool_global_u8(bufA, H, W, DS_C, pooled);
    nn_linear_out32(pooled, ds_fc_w, ds_fc_b, logits, DS_C, NUM_CLASS);

    int pred = nn_argmax_i32(logits, NUM_CLASS);

    printf("DS-CNN predicted class: %x\n", (unsigned)pred);
    print_label(pred);
    printf("expected: %x\n", (unsigned)ds_test_label);

    uart_write_flush();
    return 0;
}
