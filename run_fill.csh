#!/bin/csh
# ==============================================================================
# Run ICV metal fill (standalone, flat approach) [C Shell version]
# ==============================================================================

# --- variables ---
set DESIGN_NAME = "top"
set PROJECT_DIR = `pwd`
set GDS         = "$PROJECT_DIR/work/${DESIGN_NAME}.gds"
set FILL_DIR    = "$PROJECT_DIR/fill/${DESIGN_NAME}.icv.fill"
set FILL_RUNSET = "$PDK_DIR/DRC_ICV/DRC/ICV/gf180mcu_fill.rs"

# --- make output directory ---
if ( ! -d "$FILL_DIR" ) then
  mkdir -p "$FILL_DIR"
endif

echo "[FILL] Running ICV metal fill with BEOL_DENSITY=1"
echo "       Input GDS : $GDS"
echo "       Runset    : $FILL_RUNSET"
echo "       Output Dir: $FILL_DIR"

cd "$FILL_DIR"

# --- run icv with BEOL_DENSITY=1 ---
env BEOL_DENSITY=1 icv \
  -f gdsii \
  -i "$GDS" \
  -c "$DESIGN_NAME" \
  -vue "$FILL_RUNSET" \
  |& tee stdout.fill.log

# --- detect output GDS ---
set FILLED_GDS = `ls *.gds 2>/dev/null | head -n1`

if ( "$FILLED_GDS" == "" ) then
  echo "[FILL] Warning: no filled GDS was generated."
else
  echo "[FILL] Filled GDS created: $FILL_DIR/$FILLED_GDS"
endif
