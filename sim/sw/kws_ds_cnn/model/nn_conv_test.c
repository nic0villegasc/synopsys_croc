/*
 * nn_conv_test.c  --  verify the conv/pool kernels by exact integer equality
 * against independent references.
 *
 *   gcc -O2 nn_conv.c nn_conv_test.c -o ctest && ./ctest
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "nn_conv.h"

static uint8_t rq(int32_t acc, int32_t m, int sh)
{
    long long t = (long long)acc * m;
    if (sh > 0) t += (1LL << (sh - 1));
    t >>= sh;
    if (t < 0) t = 0; if (t > 255) t = 255;
    return (uint8_t)t;
}

int main(void)
{
    srand(7);
    const int32_t m = 9000; const int sh = 14;
    int fails = 0;

    /* ---- standard conv: H=8 W=6 Cin=3 -> Cout=5, 3x3 stride 2, valid ---- */
    {
        int H = 8, W = 6, Cin = 3, Cout = 5, KH = 3, KW = 3, st = 2;
        static uint8_t in[8 * 6 * 3];
        static int8_t  w[5 * 3 * 3 * 3];
        static int32_t b[5];
        for (int i = 0; i < H * W * Cin; i++)        in[i] = rand() & 0xFF;
        for (int i = 0; i < Cout * KH * KW * Cin; i++) w[i] = (int8_t)(rand() % 255 - 127);
        for (int i = 0; i < Cout; i++)               b[i] = (rand() % 4001) - 2000;
        static uint8_t out[5 * 5 * 5];
        int OH, OW;
        nn_conv2d_u8_relu(in, H, W, Cin, w, b, out, Cout, KH, KW, st, m, sh, &OH, &OW);
        int f = 0;
        for (int oh = 0; oh < OH; oh++) for (int ow = 0; ow < OW; ow++) for (int co = 0; co < Cout; co++) {
            int32_t acc = b[co];
            for (int kh = 0; kh < KH; kh++) for (int kw = 0; kw < KW; kw++) {
                int ih = oh * st + kh, iw = ow * st + kw;
                for (int ci = 0; ci < Cin; ci++)
                    acc += (int32_t)w[((co * KH + kh) * KW + kw) * Cin + ci]
                         * (int32_t)in[(ih * W + iw) * Cin + ci];
            }
            if (rq(acc, m, sh) != out[(oh * OW + ow) * Cout + co]) f++;
        }
        printf("conv2d      exact-match: %-4s (OH=%d OW=%d, %d mismatches)\n", f ? "FAIL" : "OK", OH, OW, f);
        fails += f;
    }

    /* ---- depthwise 3x3 s1 pad1: H=7 W=5 C=4 ---- */
    {
        int H = 7, W = 5, C = 4;
        static uint8_t in[7 * 5 * 4];
        static int8_t  w[4 * 3 * 3];
        static int32_t b[4];
        for (int i = 0; i < H * W * C; i++) in[i] = rand() & 0xFF;
        for (int i = 0; i < C * 9; i++)     w[i] = (int8_t)(rand() % 255 - 127);
        for (int i = 0; i < C; i++)         b[i] = (rand() % 4001) - 2000;
        static uint8_t out[7 * 5 * 4];
        nn_depthwise3x3_u8_relu(in, H, W, C, w, b, out, m, sh);
        int f = 0;
        for (int oh = 0; oh < H; oh++) for (int ow = 0; ow < W; ow++) for (int c = 0; c < C; c++) {
            int32_t acc = b[c];
            for (int kh = 0; kh < 3; kh++) for (int kw = 0; kw < 3; kw++) {
                int ih = oh - 1 + kh, iw = ow - 1 + kw;
                int32_t xv = (ih >= 0 && ih < H && iw >= 0 && iw < W) ? in[(ih * W + iw) * C + c] : 0;
                acc += (int32_t)w[(c * 3 + kh) * 3 + kw] * xv;
            }
            if (rq(acc, m, sh) != out[(oh * W + ow) * C + c]) f++;
        }
        printf("depthwise   exact-match: %-4s (%d mismatches)\n", f ? "FAIL" : "OK", f);
        fails += f;
    }

    /* ---- pointwise 1x1: H=4 W=4 Cin=6 -> Cout=8 ---- */
    {
        int H = 4, W = 4, Cin = 6, Cout = 8;
        static uint8_t in[4 * 4 * 6];
        static int8_t  w[8 * 6];
        static int32_t b[8];
        for (int i = 0; i < H * W * Cin; i++) in[i] = rand() & 0xFF;
        for (int i = 0; i < Cout * Cin; i++)  w[i] = (int8_t)(rand() % 255 - 127);
        for (int i = 0; i < Cout; i++)        b[i] = (rand() % 4001) - 2000;
        static uint8_t out[4 * 4 * 8];
        nn_pointwise_u8_relu(in, H, W, Cin, w, b, out, Cout, m, sh);
        int f = 0;
        for (int p = 0; p < H * W; p++) for (int co = 0; co < Cout; co++) {
            int32_t acc = b[co];
            for (int ci = 0; ci < Cin; ci++)
                acc += (int32_t)w[co * Cin + ci] * (int32_t)in[p * Cin + ci];
            if (rq(acc, m, sh) != out[p * Cout + co]) f++;
        }
        printf("pointwise   exact-match: %-4s (%d mismatches)\n", f ? "FAIL" : "OK", f);
        fails += f;
    }

    /* ---- global avgpool: H=5 W=5 C=3 ---- */
    {
        int H = 5, W = 5, C = 3, n = H * W;
        static uint8_t in[5 * 5 * 3];
        for (int i = 0; i < n * C; i++) in[i] = rand() & 0xFF;
        uint8_t out[3];
        nn_avgpool_global_u8(in, H, W, C, out);
        int f = 0;
        for (int c = 0; c < C; c++) {
            uint32_t s = 0;
            for (int p = 0; p < n; p++) s += in[p * C + c];
            if ((uint8_t)((s + n / 2) / n) != out[c]) f++;
        }
        printf("avgpool     exact-match: %-4s (%d mismatches)\n", f ? "FAIL" : "OK", f);
        fails += f;
    }

    return fails ? 1 : 0;
}
