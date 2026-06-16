/*
 * kws_demo_host.c  --  run the KWS classifier on the host with whatever
 * kws_model.h is present, and read off the static model size.
 *
 *   gcc -O2 -I../lib/inc ../lib/src/nn_linear.c kws_demo_host.c -o demo && ./demo
 */
#include <stdio.h>
#include "nn_linear.h"
#include "kws_model.h"

int main(void)
{
    static uint8_t h1[H1];
    static uint8_t h2[H2];
    static int32_t logits[NUM_CLASS];

    nn_linear_u8_relu(kws_test_feat, kws_W1, kws_b1, h1,
                      NUM_FEAT, H1, kws_out_mult1, kws_out_shift1);
    nn_linear_u8_relu(h1, kws_W2, kws_b2, h2,
                      H1, H2, kws_out_mult2, kws_out_shift2);
    nn_linear_out32(h2, kws_W3, kws_b3, logits, H2, NUM_CLASS);
    int pred = nn_argmax_i32(logits, NUM_CLASS);

    printf("predicted=%d  expected=%d\n", pred, kws_test_label);

    unsigned w = sizeof(kws_W1) + sizeof(kws_b1)
               + sizeof(kws_W2) + sizeof(kws_b2)
               + sizeof(kws_W3) + sizeof(kws_b3);
    printf("model weights+bias (.rodata) : %u bytes\n", w);
    printf("  W1 %u  b1 %u  W2 %u  b2 %u  W3 %u  b3 %u\n",
           (unsigned)sizeof(kws_W1), (unsigned)sizeof(kws_b1),
           (unsigned)sizeof(kws_W2), (unsigned)sizeof(kws_b2),
           (unsigned)sizeof(kws_W3), (unsigned)sizeof(kws_b3));
    printf("feature vector (.rodata)     : %u bytes\n",
           (unsigned)sizeof(kws_test_feat));
    printf("activation buffers (.bss)    : %u bytes (h1 %u + h2 %u + logits %u)\n",
           (unsigned)(sizeof(h1) + sizeof(h2) + sizeof(logits)),
           (unsigned)sizeof(h1), (unsigned)sizeof(h2), (unsigned)sizeof(logits));
    return 0;
}
