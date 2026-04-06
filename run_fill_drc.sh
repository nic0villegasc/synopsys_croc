#!/bin/bash
# ==============================================================================
# Run ICV DRC on the filled GDS (standalone, flat approach)
# ==============================================================================
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu


set -o pipefail   

DESIGN_NAME="top"
PROJECT_DIR="${PWD}"
FILL_DIR="${PROJECT_DIR}/fill/${DESIGN_NAME}.icv.fill"
FILL_DRC_DIR="${PROJECT_DIR}/fill/${DESIGN_NAME}.icv.fill.drc"
FILL_RUNSET="${PDK_DIR}/DRC_ICV/DRC/ICV/gf180mcu_drc.rs"

# Locate filled GDS
FILLED_GDS=$(ls "$FILL_DIR"/*.gds 2>/dev/null | head -n1 || true)

if [ -z "$FILLED_GDS" ]; then
  echo "[FILL DRC] Error: No filled GDS found in $FILL_DIR"
  echo "           Run ./run_fill.sh first."
fi

mkdir -p "$FILL_DRC_DIR"

echo "[FILL DRC] Running ICV DRC"
echo "           Input GDS : $FILLED_GDS"
echo "           Runset    : $FILL_RUNSET"
echo "           Output Dir: $FILL_DRC_DIR"

cd "$FILL_DRC_DIR"
icv \
  -f gdsii \
  -i "$FILLED_GDS" \
  -c "$DESIGN_NAME" \
  -vue "$FILL_RUNSET" \
  2>&1 | tee stdout.drc.log

echo "[FILL DRC] Done. Results are in $FILL_DRC_DIR"
