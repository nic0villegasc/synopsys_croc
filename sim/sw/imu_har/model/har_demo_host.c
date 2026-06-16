/*
 * har_demo_host.c  --  run the HAR MLP on the host and read off the footprint.
 *
 *   gcc -O2 -I../lib/inc ../lib/src/nn_linear.c har_demo_host.c -o demo && ./demo
 */
#include <stdio.h>
#include "nn_linear.h"
#include "har_model.h"

int main(void)
{
    static uint8_t h[H];
    static int32_t logits[NUM_CLASS];

    nn_linear_u8_relu(har_test_feat, har_W1, har_b1, h,
                      NUM_FEAT, H, har_out_mult1, har_out_shift1);
    nn_linear_out32(h, har_W2, har_b2, logits, H, NUM_CLASS);
    int pred = nn_argmax_i32(logits, NUM_CLASS);

    printf("predicted=%d  expected=%d\n", pred, har_test_label);

    unsigned w = sizeof(har_W1) + sizeof(har_b1) + sizeof(har_W2) + sizeof(har_b2);
    printf("model weights+bias (.rodata) : %u bytes (W1 %u b1 %u W2 %u b2 %u)\n",
           w, (unsigned)sizeof(har_W1), (unsigned)sizeof(har_b1),
           (unsigned)sizeof(har_W2), (unsigned)sizeof(har_b2));
    printf("feature vector (.rodata)     : %u bytes\n", (unsigned)sizeof(har_test_feat));
    printf("activation buffers (.bss)    : %u bytes (h %u + logits %u)\n",
           (unsigned)(sizeof(h) + sizeof(logits)),
           (unsigned)sizeof(h), (unsigned)sizeof(logits));
    return 0;
}
