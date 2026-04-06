
#!/bin/csh
# ==============================================================================
# Run ICV DRC on the filled GDS (standalone, flat approach) [C Shell version]
# ==============================================================================
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

set DESIGN_NAME = "top"
set PROJECT_DIR = `pwd`
set FILL_DIR    = "$PROJECT_DIR/fill/${DESIGN_NAME}.icv.fill"
set FILL_DRC_DIR = "$PROJECT_DIR/fill/${DESIGN_NAME}.icv.fill.drc"
set FILL_RUNSET = "$PDK_DIR/DRC_ICV/DRC/ICV/gf180mcu_drc.rs"

# Locate filled GDS
set FILLED_GDS_LIST = (`ls "$FILL_DIR"/*.gds`)

if ( $#FILLED_GDS_LIST == 0 ) then
  echo "[FILL DRC] Error: No filled GDS found in $FILL_DIR"
  echo "            Run ./run_fill.csh first."
endif

set FILLED_GDS = "$FILLED_GDS_LIST[1]"

# Make output directory
if ( ! -d "$FILL_DRC_DIR" ) then
  mkdir -p "$FILL_DRC_DIR"
endif

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
  |& tee stdout.drc.log

echo "[FILL DRC] Done. Results are in $FILL_DRC_DIR"
