
#!/bin/csh
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

# Clear TCL_LIBRARY if set
unsetenv TCL_LIBRARY

# --- Environment variables ---
setenv START_DIR "$PWD"
setenv PROJECT_DIR "$START_DIR"
setenv DESIGN "top"
setenv RUN_DIR "${START_DIR}/synopsys_custom"
setenv DRC_RUN_SET "gf180mcu_drc.rs"
setenv ICV_DRC "${PDK_DIR}/DRC_ICV/DRC/ICV"

# Example DESIGN_GDS choices
# setenv DESIGN_GDS "${RUN_DIR}/${DESIGN}.icv.lvs.bak/${DESIGN}.custom_compiler.gds"
# setenv DESIGN_GDS "${RUN_DIR}/${DESIGN}.icv.lvs/${DESIGN}.custom_compiler.gds"
setenv DESIGN_GDS "${PROJECT_DIR}/work/${DESIGN}.gds"
# setenv DESIGN_GDS "${OPENPDKS_DIR_BASE}/dk_open/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/gds/gf180mcu_fd_sc_mcu7t5v0.gds"

# --- Create run directory ---
mkdir -p ${RUN_DIR}/${DESIGN}.icv.drc
cd ${RUN_DIR}/${DESIGN}.icv.drc || exit 1

# --- Run ICV DRC ---
icv \
 -f gdsii \
 -host_init 32 \
 -i ${DESIGN_GDS} \
 -c ${DESIGN} \
 -elpc 99999999 \
 -runset_config ${START_DIR}/drc.runset.config \
 -vue "${ICV_DRC}/${DRC_RUN_SET}" |& tee "${RUN_DIR}/${DESIGN}.icv.drc/stdout.drc.log"

echo "[INFO] DRC run complete for ${DESIGN}, log written to:"
echo "       ${RUN_DIR}/${DESIGN}.icv.drc/stdout.drc.log"
