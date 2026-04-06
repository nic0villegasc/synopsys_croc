###############################################################################
# ASIC Flow Environment Configuration Script
#
# This script is sourced at the *start of the synthesis flow*
# before any design or library data is loaded.
#
# It performs the following key functions:
# - Defines base directories, including project and script paths
# - Sets default values for synthesis environment variables
# - Specifies technology file locations and reference libraries
# - Declares top-level module and clock port names
# - Sets constraints for synthesis flow behavior (e.g., ignored cells)
#
# NOTE: At this stage, design and library data are *not yet* loaded.
#       Avoid using commands like `get_lib_cells` or `get_designs`.
###############################################################################


# Set paths to useful directories
set SCRIPT_DIR [file normalize [file dirname [info script]]/..]
set REPO_DIR   [file normalize $SCRIPT_DIR/..]
set PDK_DIR $::env(PDK_DIR)
#set GF180MCU_PDK_BASE "/mnt/designkits/gf180MCU/dk_open"
set GF180MCU_PDK_BASE $::env(OPENPDKS_DIR_BASE)
set GF180MCU_DIR_PATH $::env(OPENPDKS_DIR_PATH)
set GF180MCU_FLAVOR $::env(OPENPDKS_FLAVOR)
set GF180MCU_PDK "${GF180MCU_PDK_BASE}/${GF180MCU_DIR_PATH}/${GF180MCU_FLAVOR}"
# Configure Track Size of logic cells (only 7 and 9 is available)
set STDCELL_TRACK_SIZE 7
set GF180MCU_TRACK "gf180mcu_fd_sc_mcu${STDCELL_TRACK_SIZE}t5v0"
set TECH_FILE "${PDK_DIR}/PnR/latest_ENC/5LM_1TM_11K/gf180nm_mcu_5LM_1TM_11K_${STDCELL_TRACK_SIZE}t_mw.tf"
set ICC2GDS_LAYERMAP "${PDK_DIR}/PnR/latest_ENC/5LM_1TM_11K/gf180nm_mcu_5LM_1TM_11K_icc2gds.layermap"

set LPE_SPEC "typ"
set LPE_LAYERMAP ${PDK_DIR}/PEX_StarRC/latest/gf180mcu_1p5m_1tm_11k_sp_smim_OPTB/gf180mcu_1p5m_1tm_11k_sp_smim_OPTB_typ.layermap 
set LPE_NXTGRD ${PDK_DIR}/PEX_StarRC/latest/gf180mcu_1p5m_1tm_11k_sp_smim_OPTB/gf180mcu_1p5m_1tm_11k_sp_smim_OPTB_typ.nxtgrd

# Name of design library
set DESIGN_LIBRARY design.dlib

set TECHNOLOGY      gf180mcu
set TOP_MODULE      top

set CLOCK_PORT_NAME     clk_pad
set CLOCK_PERIOD        100

# Path to synopsys technology data for gf180mcu
#set GF180MCU_PATH  $::env(GF180MCU_SNPS)
set GF180MCU_NDM_PATH  ${REPO_DIR}/..
set REFERENCE_LIBRARY [list \
    $GF180MCU_NDM_PATH/ndm/gf180mcu_fd_sc_mcu${STDCELL_TRACK_SIZE}t5v0.ndm \
    $GF180MCU_NDM_PATH/ndm/gf180mcu_fd_io.ndm \
]
#set GF180MCU_NDM_PATH  ${PDK_DIR}/PnR/GEN_NDM
#set REFERENCE_LIBRARY [list \
#    $GF180MCU_NDM_PATH/gf180mcu_fd_sc_mcu${STDCELL_TRACK_SIZE}t5v0.ndm \
#    $GF180MCU_NDM_PATH/gf180mcu_fd_io.ndm \
#]

# OR

#set GF180MCU_NDM_PATH "/mnt/designkits/gf180MCU/dk_synopsys/pdk-180/example_digital_flow/waiver_padring_example/library_compiler.gf180mcu/build"
#set REFERENCE_LIBRARY [list \
#    $GF180MCU_NDM_PATH/fc_lib/gf180mcu_fd_sc_mcu${STDCELL_TRACK_SIZE}t5v0_3v3.ndm \
#    $GF180MCU_NDM_PATH/fc_lib/gf180mcu_fd_io_3v3.ndm \
#]

# Exclude oversized cells and clock-related cells from synthesis:
# - Large drive cells (e.g., *_12, *_16, *_20) are reserved for later stages (e.g. final ECO optimization)
# - Clock-specific cells (e.g., *__clk*) are excluded to avoid clock cells in datapaths
set SYN_IGNORE_CELLS    {*/*_12 */*_16 */*_20 */*__clk*}

# Define the set of cells eligible for Clock Tree Synthesis (CTS):
# - Includes clock buffers/drivers (*clk*), integrated clock gating cells (*icg*),
#   latches (*lat*), and flip-flops (*dff*)
set CTS_CELLS           {*/*clk* */*icg* */*lat* */*dff*}

