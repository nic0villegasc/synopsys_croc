/*
 * test_nn_linear.c  --  host-side verification of the int8 kernels.
 *
 * Strategy: re-derive the accumulation and requantization independently inside
 * the test and check for *exact integer equality* with the kernel output. This
 * validates the dot-product, the row-major indexing, the bias handling and the
 * requant/clamp logic before any real weights are involved.
 *
 *   gcc -O2 nn_linear.c test_nn_linear.c -o test && ./test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "nn_linear.h"

static int32_t ref_acc(const uint8_t *x, const int8_t *w, const int32_t *b,
                       int o, int din)
{
    int32_t a = b ? b[o] : 0;
    for (int i = 0; i < din; i++)
        a += (int32_t)w[(long)o * din + i] * (int32_t)x[i];
    return a;
}

static uint8_t ref_requant(int32_t acc, int32_t m, int sh)
{
    long long t = (long long)acc * m;
    if (sh > 0) t += (1LL << (sh - 1));
    t >>= sh;
    if (t < 0) t = 0;
    if (t > 255) t = 255;
    return (uint8_t)t;
}

int main(void)
{
    srand(1234);
    const int din = 196, dout = 32;
    static uint8_t x[196];
    static int8_t  w[32 * 196];
    static int32_t b[32];

    for (int i = 0; i < din; i++)        x[i] = (uint8_t)(rand() & 0xFF);
    for (int i = 0; i < din * dout; i++) w[i] = (int8_t)(rand() % 255 - 127);
    for (int o = 0; o < dout; o++)       b[o] = (rand() % 2001) - 1000;

    const int32_t out_mult = 12345;
    const int     out_shift = 15;

    /* 1) linear_out32 must match the reference accumulator exactly */
    static int32_t y32[32];
    nn_linear_out32(x, w, b, y32, din, dout);
    int fail = 0;
    for (int o = 0; o < dout; o++)
        if (ref_acc(x, w, b, o, din) != y32[o]) fail++;
    printf("linear_out32   exact-match: %-4s (%d/%d outputs)\n",
           fail ? "FAIL" : "OK", dout - fail, dout);

    /* 2) linear_u8_relu must match reference acc + reference requant exactly */
    static uint8_t y8[32];
    nn_linear_u8_relu(x, w, b, y8, din, dout, out_mult, out_shift);
    int fail2 = 0;
    for (int o = 0; o < dout; o++) {
        uint8_t r = ref_requant(ref_acc(x, w, b, o, din), out_mult, out_shift);
        if (r != y8[o]) fail2++;
    }
    printf("linear_u8_relu exact-match: %-4s (%d/%d outputs)\n",
           fail2 ? "FAIL" : "OK", dout - fail2, dout);

    /* 3) full two-layer forward smoke test (random weights -> just structural) */
    static uint8_t h[32];
    static int8_t  w2[10 * 32];
    static int32_t b2[10];
    static int32_t lg[10];
    for (int i = 0; i < 10 * 32; i++) w2[i] = (int8_t)(rand() % 255 - 127);
    for (int o = 0; o < 10; o++)      b2[o] = (rand() % 2001) - 1000;

    nn_linear_u8_relu(x, w, b, h, din, 32, out_mult, out_shift);
    nn_linear_out32(h, w2, b2, lg, 32, 10);
    int pred = nn_argmax_i32(lg, 10);
    printf("two-layer fwd  smoke      : pred=%d  (in [0,9]: %s)\n",
           pred, (pred >= 0 && pred < 10) ? "OK" : "FAIL");

    return (fail || fail2) ? 1 : 0;
}
