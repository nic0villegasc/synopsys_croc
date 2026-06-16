/*
 * nn_conv.c  --  see nn_conv.h for the layout and quantization contract.
 */
#include "nn_conv.h"

static inline uint8_t requant_u8(int32_t acc, int32_t out_mult, int out_shift)
{
    int64_t t = (int64_t)acc * (int64_t)out_mult;
    if (out_shift > 0)
        t += ((int64_t)1 << (out_shift - 1));
    t >>= out_shift;
    if (t < 0)   t = 0;
    if (t > 255) t = 255;
    return (uint8_t)t;
}

void nn_conv2d_u8_relu(const uint8_t *in, int H, int W, int Cin,
                       const int8_t *w, const int32_t *bias,
                       uint8_t *out, int Cout, int KH, int KW, int stride,
                       int32_t out_mult, int out_shift,
                       int *outH, int *outW)
{
    int OH = (H - KH) / stride + 1;
    int OW = (W - KW) / stride + 1;

    for (int oh = 0; oh < OH; oh++) {
        for (int ow = 0; ow < OW; ow++) {
            for (int co = 0; co < Cout; co++) {
                int32_t acc = bias ? bias[co] : 0;
                for (int kh = 0; kh < KH; kh++) {
                    int ih = oh * stride + kh;
                    for (int kw = 0; kw < KW; kw++) {
                        int iw = ow * stride + kw;
                        const uint8_t *xp = in + (long)(ih * W + iw) * Cin;
                        const int8_t  *wp = w  + (long)(((co * KH + kh) * KW) + kw) * Cin;
                        for (int ci = 0; ci < Cin; ci++)
                            acc += (int32_t)wp[ci] * (int32_t)xp[ci];
                    }
                }
                out[(long)(oh * OW + ow) * Cout + co] =
                    requant_u8(acc, out_mult, out_shift);
            }
        }
    }
    *outH = OH;
    *outW = OW;
}

void nn_depthwise3x3_u8_relu(const uint8_t *in, int H, int W, int C,
                             const int8_t *w, const int32_t *bias,
                             uint8_t *out,
                             int32_t out_mult, int out_shift)
{
    for (int oh = 0; oh < H; oh++) {
        for (int ow = 0; ow < W; ow++) {
            for (int c = 0; c < C; c++) {
                int32_t acc = bias ? bias[c] : 0;
                for (int kh = 0; kh < 3; kh++) {
                    int ih = oh - 1 + kh;          /* zero-pad 1 */
                    for (int kw = 0; kw < 3; kw++) {
                        int iw = ow - 1 + kw;
                        int32_t xv = 0;
                        if (ih >= 0 && ih < H && iw >= 0 && iw < W)
                            xv = (int32_t)in[(long)(ih * W + iw) * C + c];
                        int8_t wv = w[(c * 3 + kh) * 3 + kw];
                        acc += (int32_t)wv * xv;
                    }
                }
                out[(long)(oh * W + ow) * C + c] =
                    requant_u8(acc, out_mult, out_shift);
            }
        }
    }
}

void nn_pointwise_u8_relu(const uint8_t *in, int H, int W, int Cin,
                          const int8_t *w, const int32_t *bias,
                          uint8_t *out, int Cout,
                          int32_t out_mult, int out_shift)
{
    int npix = H * W;
    for (int p = 0; p < npix; p++) {
        const uint8_t *x = in  + (long)p * Cin;
        uint8_t       *o = out + (long)p * Cout;
        for (int co = 0; co < Cout; co++) {
            int32_t acc = bias ? bias[co] : 0;
            const int8_t *wr = w + (long)co * Cin;
            for (int ci = 0; ci < Cin; ci++)
                acc += (int32_t)wr[ci] * (int32_t)x[ci];
            o[co] = requant_u8(acc, out_mult, out_shift);
        }
    }
}

void nn_avgpool_global_u8(const uint8_t *in, int H, int W, int C, uint8_t *out)
{
    int n = H * W;
    for (int c = 0; c < C; c++) {
        uint32_t s = 0;
        for (int p = 0; p < n; p++)
            s += in[(long)p * C + c];
        out[c] = (uint8_t)((s + (uint32_t)n / 2) / (uint32_t)n);   /* rounded */
    }
}
