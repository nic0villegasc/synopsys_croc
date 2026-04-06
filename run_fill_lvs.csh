
#!/bin/csh
# ==============================================================================
# Run ICV LVS on the filled GDS (standalone, flat approach) [C Shell version]
# ==============================================================================
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

set DESIGN_NAME = "top"
set PROJECT_DIR = `pwd`
set FILL_DIR    = "$PROJECT_DIR/fill/${DESIGN_NAME}.icv.fill"
set FILL_LVS_DIR = "$PROJECT_DIR/fill/${DESIGN_NAME}.icv.fill.lvs"
set LVS_RUNSET  = "$PDK_DIR/LVS_ICV/LVS/ICV/cmos018hv.3p3.6v.lvs.rs"
set NETTRAN_CDL = "$PROJECT_DIR/work/${DESIGN_NAME}_lvs_merged.cdl"

# Locate filled GDS
set FILLED_GDS_LIST = (`ls "$FILL_DIR"/*.gds`)

if ( $#FILLED_GDS_LIST == 0 ) then
  echo "[FILL LVS] Error: No filled GDS found in $FILL_DIR"
  echo "            Run ./run_fill.csh first."
endif

set FILLED_GDS = "$FILLED_GDS_LIST[1]"

# Check netlist
if ( ! -f "$NETTRAN_CDL" ) then
  echo "[FILL LVS] Error: Nettran CDL not found: $NETTRAN_CDL"
  echo "            Run nettran or 'make nettran' first."
endif

# Make output directory
if ( ! -d "$FILL_LVS_DIR" ) then
  mkdir -p "$FILL_LVS_DIR"
endif

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
  -I "$PDK_DIR/LVS_ICV/LVS/ICV" \
  -s "$NETTRAN_CDL" \
  -sf SPICE \
  -stc "$DESIGN_NAME" \
  -oa_dm6 \
  -vue "$LVS_RUNSET" \
  |& tee stdout.lvs.log

echo "[FILL LVS] Done. Results are in $FILL_LVS_DIR"
