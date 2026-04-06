#!/bin/csh

# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu

# Make a copy of this file into your own directory. Then you should simply be able 
# to use this file to take an input verilog from ICC2 that is ${DESIGN}.v
# Where ${DESIGN} is the name of your top cell and the name of your .v file
# Change the DESIGN to be the design name of the top cell in the export command.

# 


unsetenv TCL_LIBRARY
setenv PROJECT_DIR $PWD/work
setenv DESIGN top
setenv DESIGN_VERILOG ${PROJECT_DIR}/${DESIGN}.v
setenv RUN_DIR ${PROJECT_DIR}/../synopsys_custom
setenv LVS_RUN_SET cmos018hv.3p3.6v.lvs.rs
setenv ICV_LVS ${PDK_DIR}/LVS_ICV/LVS/ICV
setenv DESIGN_GDS ${PROJECT_DIR}/${DESIGN}.gds
setenv DESIGN_CDL ${PROJECT_DIR}/${DESIGN}.cdl
setenv STDCELLS_CDL ${OPENPDKS_DIR_BASE}/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/cdl/gf180mcu_fd_sc_mcu7t5v0.cdl
setenv IO_CDL ${OPENPDKS_DIR_BASE}/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_io/cdl/gf180mcu_fd_io.cdl
setenv MERGED_CDL ${PROJECT_DIR}/${DESIGN}_lvs_merged.cdl


# CREATE MERGED NETLIST It takes the design and adds the standard cell CDL to it for LVS
icv_nettran -verilog ${DESIGN_VERILOG} -sp ${STDCELLS_CDL} ${IO_CDL} -outType SPICE -outName ${MERGED_CDL}

# Make your run directories
mkdir -p ${RUN_DIR}/${DESIGN}.icv.lvs
cd ${RUN_DIR}/${DESIGN}.icv.lvs

# execute the icv.
( icv \
 -f gdsii \
 -i ${DESIGN_GDS} \
 -c ${DESIGN} \
 -I ${ICV_LVS} \
 -s ${MERGED_CDL} \
 -sf SPICE \
 -stc ${DESIGN} \
 -oa_dm6 \
 -vue ${ICV_LVS}/${LVS_RUN_SET} ) |& tee ${RUN_DIR}/${DESIGN}.icv.lvs/stdout.lvs.log
