#!/bin/bash
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu
# It is provided *“as is”* without warranty of any kind, express or implied,  
# including but not limited to correctness or fitness for a particular purpose.


# Make a copy of this file into your own directory. Then you should simply be able 
# to use this file to take an input verilog from ICC2 that is ${DESIGN}.v
# Where ${DESIGN} is the name of your top cell and the name of your .v file
# Change the DESIGN to be the design name of the top cell in the export command.

# Clear TCL_LIBRARY if set
unset TCL_LIBRARY

# --- Environment variables ---
export PROJECT_DIR="$PWD/work"
export DESIGN="top"
export DESIGN_VERILOG="${PROJECT_DIR}/${DESIGN}.v"
export RUN_DIR="${PROJECT_DIR}/../synopsys_custom"
export LVS_RUN_SET="cmos018hv.3p3.6v.lvs.rs"
export ICV_LVS="${PDK_DIR}/LVS_ICV/LVS/ICV"
export DESIGN_GDS="${PROJECT_DIR}/${DESIGN}.gds"
export DESIGN_CDL="${PROJECT_DIR}/${DESIGN}.cdl"
export STDCELLS_CDL="${OPENPDKS_DIR_BASE}/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/cdl/gf180mcu_fd_sc_mcu7t5v0.cdl"
export IO_CDL="${OPENPDKS_DIR_BASE}/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_io/cdl/gf180mcu_fd_io.cdl"
export MERGED_CDL="${PROJECT_DIR}/${DESIGN}_lvs_merged.cdl"

# --- Create merged netlist ---
# Takes the design and adds the standard cell + IO CDL for LVS
icv_nettran -verilog "${DESIGN_VERILOG}" -sp "${STDCELLS_CDL}" "${IO_CDL}" -outType SPICE -outName "${MERGED_CDL}"

# --- Make run directories ---
mkdir -p "${RUN_DIR}/${DESIGN}.icv.lvs"
cd "${RUN_DIR}/${DESIGN}.icv.lvs" || exit 1

# --- Execute ICV ---
icv \
 -f gdsii \
 -i "${DESIGN_GDS}" \
 -c "${DESIGN}" \
 -I "${ICV_LVS}" \
 -s "${MERGED_CDL}" \
 -sf SPICE \
 -stc "${DESIGN}" \
 -oa_dm6 \
 -vue "${ICV_LVS}/${LVS_RUN_SET}" 2>&1 | tee "${RUN_DIR}/${DESIGN}.icv.lvs/stdout.lvs.log"
