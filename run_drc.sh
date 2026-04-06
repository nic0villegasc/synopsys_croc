#!/bin/sh
# All Rights Reserved.
# Copyright 2025 North Carolina State University
# W. Shepherd Pitts (PhD) - wspitts2@ncsu.edu


unset TCL_LIBRARY
export START_DIR="${PWD}"
export PROJECT_DIR="${START_DIR}"
export DESIGN="top"
export RUN_DIR=${START_DIR}/synopsys_custom
export DRC_RUN_SET=gf180mcu_drc.rs
export ICV_DRC=${PDK_DIR}/DRC_ICV/DRC/ICV
#export DESIGN_GDS=${RUN_DIR}/${DESIGN}.icv.lvs.bak/${DESIGN}.custom_compiler.gds
#export DESIGN_GDS=${RUN_DIR}/${DESIGN}.icv.lvs/${DESIGN}.custom_compiler.gds
export DESIGN_GDS=${PROJECT_DIR}/work/${DESIGN}.gds
#export DESIGN_GDS=${OPENPDKS_DIR_BASE}/dk_open/share/pdk/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/gds/gf180mcu_fd_sc_mcu7t5v0.gds

mkdir -p ${RUN_DIR}/${DESIGN}.icv.drc
cd ${RUN_DIR}/${DESIGN}.icv.drc


icv \
 -f gdsii \
 -host_init 32 \
 -i ${DESIGN_GDS} \
 -c ${DESIGN} \
 -elpc 99999999 \
 -runset_config ${START_DIR}/drc.runset.config \
 -vue "${ICV_DRC}/${DRC_RUN_SET}" 2>&1 | tee "${RUN_DIR}/${DESIGN}.icv.drc/stdout.drc.log"

