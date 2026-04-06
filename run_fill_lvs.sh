
#!/bin/bash
# ==============================================================================
# Run ICV LVS on the filled GDS (standalone, flat approach)
# ==============================================================================
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

set -o pipefail   # stop on errors, propagate pipeline failures

DESIGN_NAME="top"
PROJECT_DIR="${PWD}"
FILL_DIR="${PROJECT_DIR}/fill/${DESIGN_NAME}.icv.fill"
FILL_LVS_DIR="${PROJECT_DIR}/fill/${DESIGN_NAME}.icv.fill.lvs"
LVS_RUNSET="${PDK_DIR}/LVS_ICV/LVS/ICV/cmos018hv.3p3.6v.lvs.rs"
NETTRAN_CDL="${PROJECT_DIR}/work/${DESIGN_NAME}_lvs_merged.cdl"

# Locate filled GDS
FILLED_GDS=$(ls "$FILL_DIR"/*.gds 2>/dev/null | head -n1 || true)

if [ -z "$FILLED_GDS" ]; then
  echo "[FILL LVS] Error: No filled GDS found in $FILL_DIR"
  echo "            Run ./run_fill.sh first."
fi

# Check netlist
if [ ! -f "$NETTRAN_CDL" ]; then
  echo "[FILL LVS] Error: Nettran CDL not found: $NETTRAN_CDL"
  echo "            Run nettran or 'make nettran' first."
fi

mkdir -p "$FILL_LVS_DIR"

echo "[FILL LVS] Running ICV LVS"
echo "           Input GDS : $FILLED_GDS"
echo "           Netlist   : $NETTRAN_CDL"
echo "           Runset    : $LVS_RUNSET"
echo "           Output Dir: $FILL_LVS_DIR"

cd "$FILL_LVS_DIR"
icv \
  -f gdsii \
  -i "$FILLED_GDS" \
  -c "$DESIGN_NAME" \
  -I "${PDK_DIR}/LVS_ICV/LVS/ICV" \
  -s "$NETTRAN_CDL" \
  -sf SPICE \
  -stc "$DESIGN_NAME" \
  -oa_dm6 \
  -vue "$LVS_RUNSET" \
  2>&1 | tee stdout.lvs.log

echo "[FILL LVS] Done. Results are in $FILL_LVS_DIR"
