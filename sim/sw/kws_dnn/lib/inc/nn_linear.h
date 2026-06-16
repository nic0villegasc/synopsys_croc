/*
 * nn_linear.h  --  scalar int8 fully-connected kernels for single-core RV32 (Croc / Ibex)
 *
 * Basis: this is the *scalar* path of PULP-NN's pulp_nn_linear.c
 * (Garofalo et al., PULP-NN, UniBo/ETH), with the Xpulp SIMD builtins
 * (__builtin_pulp_sdotusp4 / clipu_r) and the cluster primitives removed.
 * The quantization scheme is the standard TFLite-style integer-only one:
 *
 *   activations : uint8, asymmetric with zero-point = 0  (non-negative reals,
 *                 i.e. ReLU outputs and [0,1]-normalized inputs)
 *   weights     : int8,  symmetric  (zero-point = 0)
 *   bias        : int32, already in the accumulator domain  b / (s_x * s_w)
 *   accumulate  : int32   acc = sum_j w[j]*x[j] + bias
 *   requant     : y = clamp_u8( round(acc * out_mult * 2^-out_shift) )
 *                 (ReLU is folded in by clamping the lower bound to 0)
 *
 * Weight layout is row-major [dim_out][dim_in] (matches torch.nn.Linear.weight).
 */
#ifndef NN_LINEAR_H
#define NN_LINEAR_H

#include <stdint.h>

/* Hidden / intermediate FC layer: uint8 in -> int32 acc -> requant+ReLU -> uint8 out. */
void nn_linear_u8_relu(const uint8_t *x, const int8_t *w, const int32_t *bias,
                       uint8_t *y, int dim_in, int dim_out,
                       int32_t out_mult, int out_shift);

/* Final FC layer: uint8 in -> int32 logits (no requant; argmax is scale-invariant). */
void nn_linear_out32(const uint8_t *x, const int8_t *w, const int32_t *bias,
                     int32_t *y, int dim_in, int dim_out);

/* Index of the largest element. */
int nn_argmax_i32(const int32_t *v, int n);

#endif /* NN_LINEAR_H */
