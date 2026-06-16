/*
 * dscnn_demo_host.c  --  run the reduced DS-CNN on the host and report the
 * weight vs activation footprint separately (the point of the DS-CNN study).
 *
 *   gcc -O2 -I../lib/inc ../lib/src/nn_linear.c ../lib/src/nn_conv.c dscnn_demo_host.c -o demo && ./demo
 */
#include <stdio.h>
#include "nn_conv.h"
#include "nn_linear.h"
#include "dscnn_model.h"

#define MAXFM (C1_H * C1_W * DS_C)   /* largest feature map */

static uint8_t bufA[MAXFM];
static uint8_t bufB[MAXFM];
static uint8_t pooled[DS_C];
static int32_t logits[NUM_CLASS];

int main(void)
{
    int H, W;
    /* conv1 (valid) : [IN_T][IN_F][1] -> bufA [C1_H][C1_W][DS_C] */
    nn_conv2d_u8_relu(ds_test_feat, IN_T, IN_F, IN_C,
                      ds_conv1_w, ds_conv1_b, bufA, DS_C, 3, 3, 2,
                      ds_conv1_mult, ds_conv1_shift, &H, &W);
    /* block 1 */
    nn_depthwise3x3_u8_relu(bufA, H, W, DS_C, ds_dw1_w, ds_dw1_b, bufB,
                            ds_dw1_mult, ds_dw1_shift);
    nn_pointwise_u8_relu(bufB, H, W, DS_C, ds_pw1_w, ds_pw1_b, bufA, DS_C,
                         ds_pw1_mult, ds_pw1_shift);
    /* block 2 */
    nn_depthwise3x3_u8_relu(bufA, H, W, DS_C, ds_dw2_w, ds_dw2_b, bufB,
                            ds_dw2_mult, ds_dw2_shift);
    nn_pointwise_u8_relu(bufB, H, W, DS_C, ds_pw2_w, ds_pw2_b, bufA, DS_C,
                         ds_pw2_mult, ds_pw2_shift);
    /* global average pool + classifier */
    nn_avgpool_global_u8(bufA, H, W, DS_C, pooled);
    nn_linear_out32(pooled, ds_fc_w, ds_fc_b, logits, DS_C, NUM_CLASS);
    int pred = nn_argmax_i32(logits, NUM_CLASS);

    printf("predicted=%d  expected=%d  (conv1 out %dx%dx%d)\n",
           pred, ds_test_label, H, W, DS_C);

    unsigned wts = sizeof(ds_conv1_w)+sizeof(ds_conv1_b)
                 + sizeof(ds_dw1_w)+sizeof(ds_dw1_b)+sizeof(ds_pw1_w)+sizeof(ds_pw1_b)
                 + sizeof(ds_dw2_w)+sizeof(ds_dw2_b)+sizeof(ds_pw2_w)+sizeof(ds_pw2_b)
                 + sizeof(ds_fc_w)+sizeof(ds_fc_b);
    unsigned act = sizeof(bufA)+sizeof(bufB)+sizeof(pooled)+sizeof(logits);
    printf("weights+bias (.rodata)    : %u bytes\n", wts);
    printf("feature vector (.rodata)  : %u bytes\n", (unsigned)sizeof(ds_test_feat));
    printf("activation buffers (.bss) : %u bytes (bufA %u + bufB %u + pooled %u + logits %u)\n",
           act, (unsigned)sizeof(bufA), (unsigned)sizeof(bufB),
           (unsigned)sizeof(pooled), (unsigned)sizeof(logits));
    return 0;
}
