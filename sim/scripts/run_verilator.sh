#!/bin/bash
set -e  # Exit immediately if a command fails

# Resolve repo root from this script's location (sim/scripts -> repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BUILD_DIR="$ROOT/sim/build/verilator"
# Optional: pass a .hex as the first arg, else default to helloworld
HEX="${1:-$ROOT/sim/sw/bin/helloworld.hex}"

echo "=> Setting up Verilator build workspace..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=> Compiling cycle-accurate hardware model..."
verilator --binary -j 0 -Wno-fatal --trace --trace-structs \
  -F "$ROOT/croc_sim.flist" \
  --top-module tb_croc_soc

echo "=> Running Simulation with: $HEX"
# Run from sim/build so the testbench's default '../sw/bin/...' path resolves,
# AND pass an absolute path explicitly so CWD never matters.
# NOTE: confirm the plusarg name below matches tb_croc_soc.sv (see grep output).
cd "$ROOT/sim/build"
./verilator/obj_dir/Vtb_croc_soc +BINARY="$HEX"