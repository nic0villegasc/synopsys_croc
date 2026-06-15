/*
 * mnist_demo_host.c  --  run the full inference on the host with whatever
 * mnist_model.h is present (placeholder or trained). Use it locally to sanity
 * check the forward path and to read off the static model size.
 *
 *   gcc -O2 nn_linear.c mnist_demo_host.c -o demo && ./demo
 */
#include <stdio.h>
#include "nn_linear.h"
#include "mnist_model.h"

int main(void)
{
    static uint8_t h[DIM_H];
    static int32_t logits[DIM_OUT];

    nn_linear_u8_relu(mnist_test_image, mnist_W1, mnist_b1, h,
                      DIM_IN, DIM_H, mnist_out_mult1, mnist_out_shift1);
    nn_linear_out32(h, mnist_W2, mnist_b2, logits, DIM_H, DIM_OUT);
    int pred = nn_argmax_i32(logits, DIM_OUT);

    printf("predicted=%d  expected=%d\n", pred, mnist_test_label);

    unsigned w = sizeof(mnist_W1) + sizeof(mnist_b1)
               + sizeof(mnist_W2) + sizeof(mnist_b2);
    printf("model weights+bias (.rodata) : %u bytes\n", w);
    printf("  W1 %u  b1 %u  W2 %u  b2 %u\n",
           (unsigned)sizeof(mnist_W1), (unsigned)sizeof(mnist_b1),
           (unsigned)sizeof(mnist_W2), (unsigned)sizeof(mnist_b2));
    printf("activation buffers (.bss)    : %u bytes (h %u + logits %u + image %u)\n",
           (unsigned)(sizeof(h) + sizeof(logits) + sizeof(mnist_test_image)),
           (unsigned)sizeof(h), (unsigned)sizeof(logits),
           (unsigned)sizeof(mnist_test_image));
    return 0;
}
