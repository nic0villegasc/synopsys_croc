# "Hey Croc" keyword spotting — reduced DS-CNN (single-core Ibex)

The depthwise-separable CNN version of the KWS example: the architecture the
field and MLPerf Tiny actually use for keyword spotting, run as a **reduced**
model that fits 16 KB. It is the citable counterpart to the plain-DNN baseline.

Pipeline and tooling are the same as every other example; the new pieces are
three scalar conv kernels (standard conv, depthwise 3×3, pointwise 1×1) plus
global average pooling. The final classifier reuses `nn_linear_out32`.

- **Model basis:** DS-CNN, *Hello Edge* (Zhang et al., arXiv:1711.07128),
  reduced; MLPerf Tiny uses the full-size variant.
- **Data basis:** Google Speech Commands (Warden, arXiv:1804.03209).

## Architecture (reduced to fit 16 KB)

```
MFCC [25 x 10 x 1]
  conv1   3x3 stride 2 VALID  -> [12 x 4 x 16]  + ReLU
  block1  depthwise 3x3 (pad1) + ReLU, pointwise 1x1 + ReLU   [12 x 4 x 16]
  block2  depthwise 3x3 (pad1) + ReLU, pointwise 1x1 + ReLU   [12 x 4 x 16]
  global avg pool -> [16]
  FC 16 -> 12 -> argmax
```

No BatchNorm (keeps per-tensor quant identical to the FC examples; folding BN is
the obvious accuracy upgrade later). The canonical DS-CNN-S (~38 KB weights, much
larger feature maps) does **not** fit 16 KB — hence the reduced channels/blocks.

## Why DS-CNN over the DNN

Among the Hello Edge models the DNN has the worst accuracy-per-byte; DS-CNN is
Pareto-optimal and is what MLPerf Tiny standardizes, so it is the comparable,
defensible KWS number. The two together make a good story:

| | DNN baseline | **reduced DS-CNN** |
|---|---:|---:|
| weights+bias (`.rodata`) | 9712 B | **1504 B** |
| activation buffers (`.bss`) | 112 B | **1600 B** |
| feature vector | 250 B | 250 B |
| dominant cost | weights | **activations** |

The headline finding: DS-CNN cuts weight memory ~6× but the **activation buffers
become the bottleneck** — a qualitatively different memory profile from every FC
model, and direct ammunition for "CNNs need working SRAM the FC models don't."

## Directory layout

```
kws_dscnn/
├── main.c                      # from dscnn_infer.c
├── lib/
│   ├── inc/ { nn_linear.h, nn_conv.h, dscnn_model.h(generated) }
│   └── src/ { nn_linear.c, nn_conv.c }     # nn_linear.c SHARED with MNIST/DNN-KWS
└── model/ { .venv/, train_export_dscnn.py, dscnn_demo_host.c, nn_conv_test.c }
```

## A. Build and size

```sh
make
riscv32-unknown-elf-size -A bin/main.elf
```

Expected UART output (trained weights):

```
DS-CNN predicted class: <hex>
<keyword>
expected: <hex>
```

Ships with a **placeholder** `dscnn_model.h` (real dimensions) so it builds and
sizes before training.

## B. Train and export

```sh
cd model
python3 -m venv .venv && source .venv/bin/activate
pip install torch torchaudio
python train_export_dscnn.py        # edit output path to ../lib/inc/dscnn_model.h
```

Prints the int8 test accuracy (the on-chip number) and writes the header,
transposing the PyTorch NCHW weights to the kernels' HWC layout. Data pipeline is
the same simplified Speech Commands setup as the DNN example.

## C. Verify on the host

Conv/pool kernel self-test (exact integer equality vs reference):

```sh
gcc -O2 -I../lib/inc ../lib/src/nn_conv.c nn_conv_test.c -o ctest && ./ctest
```

Full DS-CNN forward + footprint split:

```sh
gcc -O2 -I../lib/inc ../lib/src/nn_linear.c ../lib/src/nn_conv.c dscnn_demo_host.c -o demo && ./demo
```

## Quantization contract

Same per-tensor int8 scheme as the FC examples, in HWC layout:

- **conv1 input:** signed MFCC → asymmetric uint8 zero-point `z_x`; correction
  `-z_x · Σ(filter weights)` folded into `ds_conv1_b`. conv1 is **valid** so
  padding never sees `z_x`.
- **Depthwise:** zero-padded (correct — inputs are ReLU outputs, zero-point 0).
- **Hidden layers:** ReLU, zero-point 0; per-tensor `mult`/`shift` requant.
- **Global avg pool:** preserves scale; **FC:** raw int32 logits → argmax.

Weight layouts (HWC): conv1 `[Co][KH][KW][Ci]`, depthwise `[C][3][3]`,
pointwise `[Co][Ci]`, FC `[NUM_CLASS][C]` row-major.

## Notes

- On-chip MFCC is still a separate ~4–7 KB DSP block, not included here.
- Same two scratch buffers (`bufA`/`bufB`, ping-pong) hold every feature map;
  `MAXFM = C1_H·C1_W·DS_C`. Raising channel count or input size grows these
  first — that is the knob that decides whether a bigger DS-CNN fits.
