/*
 * nn_conv.h  --  scalar int8 conv/pool kernels for DS-CNN on single-core RV32.
 *
 * Basis: scalar paths of PULP-NN's standard / depthwise / pointwise conv and
 * avgpool kernels, with Xpulp SIMD + cluster removed. Same quant contract as
 * nn_linear.h (uint8 acts zero-point 0 on ReLU outputs, int8 symmetric weights,
 * int32 bias in accumulator domain, per-tensor requant with ReLU clamp).
 *
 * Data layout is HWC: activations  in[h][w][c]      -> ((h*W + w)*C + c)
 *                     std-conv wt   w[co][kh][kw][ci]
 *                     depthwise wt  w[c][kh][kw]
 *                     pointwise wt  w[co][ci]
 *
 * Zero-point note: only the FIRST layer's input (MFCC) carries a non-zero
 * zero-point; that correction is folded into its bias by the exporter, and the
 * first layer is run as a "valid" (no-pad) conv so padding never sees it.
 * Depthwise layers pad with 0, which is correct because their inputs are ReLU
 * outputs (zero-point 0).
 */
#ifndef NN_CONV_H
#define NN_CONV_H

#include <stdint.h>

/* Standard conv, "valid" (no padding). Writes output dims to outH and outW. */
void nn_conv2d_u8_relu(const uint8_t *in, int H, int W, int Cin,
                       const int8_t *w, const int32_t *bias,
                       uint8_t *out, int Cout, int KH, int KW, int stride,
                       int32_t out_mult, int out_shift,
                       int *outH, int *outW);

/* Depthwise 3x3, stride 1, zero-pad 1 -> output dims == input dims. */
void nn_depthwise3x3_u8_relu(const uint8_t *in, int H, int W, int C,
                             const int8_t *w, const int32_t *bias,
                             uint8_t *out,
                             int32_t out_mult, int out_shift);

/* Pointwise 1x1 conv == per-pixel linear over channels. */
void nn_pointwise_u8_relu(const uint8_t *in, int H, int W, int Cin,
                          const int8_t *w, const int32_t *bias,
                          uint8_t *out, int Cout,
                          int32_t out_mult, int out_shift);

/* Global average pool over H*W per channel -> out[C]. */
void nn_avgpool_global_u8(const uint8_t *in, int H, int W, int C, uint8_t *out);

#endif /* NN_CONV_H */
