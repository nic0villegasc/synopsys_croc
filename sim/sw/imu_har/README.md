# IMU human-activity recognition on Croc (single-core Ibex)

An IMU/HAR example built to the same recipe as the others: a quantized MLP
(**288 → 32 → 6**) classifies a window of inertial samples into one of six
activities, on a single Ibex core in 16 KB.

It **reuses the MNIST kernel unchanged** (`nn_linear.c`) — only the model, the
`main`, and the exporter are new — and is structurally a near-twin of the MNIST
MLP (288 inputs vs 196).

- **Model basis:** small MLP baseline on windowed IMU.
- **Data basis:** UCI HAR Dataset (Anguita et al., 2013), raw "Inertial Signals".

## Input

UCI HAR provides 9 channels (body acc x/y/z, body gyro x/y/z, total acc x/y/z),
128 samples per 2.56 s window @ 50 Hz. The exporter mean-pools time **128 → 32**
and flattens time-major (`t*9 + c`) → **288 features**. On a real device these
288 values come straight from the IMU FIFO — no hand-crafted feature stage, so
unlike KWS there is no separate front-end to budget.

## Modeling note (honest)

Flattening a raw window into an MLP discards temporal structure — it's a
legitimate small **baseline**, not the best model. A **1D-CNN** is the proper
choice and drops straight into the existing conv kernels: call `nn_conv2d` with
`W = 1`, `KW = 1`, treating the window as a `[T][1][C]` "image". So the same
DNN→DS-CNN upgrade path is available here for free if you want the
temporally-aware version.

## Directory layout

```
har_imu/
├── main.c                      # from har_infer.c
├── lib/
│   ├── inc/ { nn_linear.h, har_model.h(generated) }
│   └── src/ { nn_linear.c }     # SHARED with MNIST / DNN-KWS (unchanged)
└── model/ { .venv/, train_export_har.py, har_demo_host.c }
```

## A. Build and size

```sh
make
riscv32-unknown-elf-size -A bin/main.elf
```

Expected UART output (trained weights):

```
HAR predicted activity: <hex>
<activity name>
expected: <hex>
```

Ships with a **placeholder** `har_model.h` (real dimensions) so it builds and
sizes before training.

## B. Train and export

Download and unzip the "UCI HAR Dataset" from the UCI ML repository, then:

```sh
cd model
python3 -m venv .venv && source .venv/bin/activate
pip install torch numpy
python train_export_har.py        # set DATA_DIR; edit output to ../lib/inc/har_model.h
```

Prints the int8 test accuracy (the on-chip number) and writes the header.

## C. Verify on the host

Kernel self-test is the shared one (`test_nn_linear.c`). Forward + footprint:

```sh
gcc -O2 -I../lib/inc ../lib/src/nn_linear.c har_demo_host.c -o demo && ./demo
```

## Memory budget

Same 16 KB SRAM. Measured from the actual arrays:

| Section            | Bytes  | What it is                          |
|--------------------|-------:|-------------------------------------|
| model weights+bias |  9,560 | W1 9216, b1 128, W2 192, b2 24      |
| feature vector     |    288 | embedded IMU window (`.rodata`)     |
| activation buffers |     56 | h 32 + logits 24                    |
| **model + buffers**| **~9.9 KB** | + ~3.3 KB shared code ⇒ ~13.2 KB / 16 KB |

Another **weights-dominated** FC row, in line with MNIST (~10.4 KB) and the
DNN-KWS (~13.5 KB) — the opposite end of the axis from the DS-CNN, whose
activation buffers dominated. Three FC examples plus the DS-CNN now bracket both
ends of the weights-vs-activations tradeoff for your study.

## Quantization contract

Identical to MNIST plus the signed-input handling from KWS:

- **Input layer:** signed IMU samples → asymmetric uint8 zero-point `z_x`;
  correction `-z_x · Σ_j W1[o][j]` folded into `har_b1`. Kernel byte-identical.
- **Hidden layer:** ReLU, zero-point 0.
- **Output layer:** raw int32 logits → argmax.
