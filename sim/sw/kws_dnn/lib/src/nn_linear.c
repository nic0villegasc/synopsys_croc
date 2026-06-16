/*
 * nn_linear.c  --  see nn_linear.h for the quantization contract.
 *
 * The inner MAC loop here is exactly what PULP-NN's pulp_nn_linear.c falls back
 * to in its `while (col_cnt)` tail when no Xpulp SIMD is available; on Ibex that
 * tail *is* the whole computation, so nothing is lost functionally.
 */
#include "nn_linear.h"

/* Rounding requantization to uint8 with ReLU folded in (lower clamp at 0).
 * int64 intermediate avoids overflow of acc*out_mult; on RV32 this pulls in a
 * libgcc 64-bit multiply. If you want to stay strictly 32-bit, bound out_mult
 * so that |acc| * out_mult < 2^31 and drop the cast. */
static inline uint8_t requant_u8(int32_t acc, int32_t out_mult, int out_shift)
{
    int64_t t = (int64_t)acc * (int64_t)out_mult;
    if (out_shift > 0)
        t += ((int64_t)1 << (out_shift - 1));   /* round-half-up */
    t >>= out_shift;
    if (t < 0)   t = 0;
    if (t > 255) t = 255;
    return (uint8_t)t;
}

void nn_linear_u8_relu(const uint8_t *x, const int8_t *w, const int32_t *bias,
                       uint8_t *y, int dim_in, int dim_out,
                       int32_t out_mult, int out_shift)
{
    for (int o = 0; o < dim_out; o++) {
        int32_t acc = bias ? bias[o] : 0;
        const int8_t *wr = w + (int)o * dim_in;     /* row o of [dim_out][dim_in] */
        for (int i = 0; i < dim_in; i++)
            acc += (int32_t)wr[i] * (int32_t)x[i];
        y[o] = requant_u8(acc, out_mult, out_shift);
    }
}

void nn_linear_out32(const uint8_t *x, const int8_t *w, const int32_t *bias,
                     int32_t *y, int dim_in, int dim_out)
{
    for (int o = 0; o < dim_out; o++) {
        int32_t acc = bias ? bias[o] : 0;
        const int8_t *wr = w + (int)o * dim_in;
        for (int i = 0; i < dim_in; i++)
            acc += (int32_t)wr[i] * (int32_t)x[i];
        y[o] = acc;
    }
}

int nn_argmax_i32(const int32_t *v, int n)
{
    int best = 0;
    int32_t bv = v[0];
    for (int i = 1; i < n; i++)
        if (v[i] > bv) { bv = v[i]; best = i; }
    return best;
}
