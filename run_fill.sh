#!/bin/bash
# ==============================================================================
# Run ICV metal fill (standalone, flat approach)
# ==============================================================================
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

set -o pipefail

DESIGN_NAME="top"
PROJECT_DIR="${PWD}"
GDS="${PROJECT_DIR}/work/${DESIGN_NAME}.gds"
FILL_DIR="${PROJECT_DIR}/fill/${DESIGN_NAME}.icv.fill"
FILL_RUNSET="${PDK_DIR}/DRC_ICV/DRC/ICV/gf180mcu_fill.rs"

mkdir -p "$FILL_DIR"

echo "[FILL] Running ICV metal fill with BEOL_DENSITY=1"
echo "       Input GDS : $GDS"
echo "       Runset    : $FILL_RUNSET"
echo "       Output Dir: $FILL_DIR"

cd "$FILL_DIR"
BEOL_DENSITY=1 icv \
  -f gdsii \
  -i "$GDS" \
  -c "$DESIGN_NAME" \
  -vue "$FILL_RUNSET" \
  2>&1 | tee stdout.fill.log

FILLED_GDS=$(ls *.gds 2>/dev/null | head -n1 || true)
if [ -z "$FILLED_GDS" ]; then
  echo "[FILL] Warning: no filled GDS was generated."
else
  echo "[FILL] Filled GDS created: $FILL_DIR/$FILLED_GDS"
fi

