# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

source [file dirname [info script]]/common/open_lib.tcl
open_block read_rtl

set SITE_DEF unit
#set SITE_DEF GF018hv5v_mcu_sc7

initialize_floorplan \
    -control_type die -side_length {2935 2935} \
    -core_offset {400.14 401.26} -site_def $SITE_DEF

foreach idx {0 1 2 3} {
    create_cell corner_$idx *_io_*/*cor
}

create_io_ring -name io_ring -corner_height 355

set_power_io_constraints \
    -reference_cell {gf180mcu_fd_io__dvdd gf180mcu_fd_io__dvss} \
    -ratio {{4 gf180mcu_fd_io__dvdd} {4 gf180mcu_fd_io__dvss}}

place_io

create_io_filler_cells -reference_cells {gf180mcu_fd_io__fill10 gf180mcu_fd_io__fill5 gf180mcu_fd_io__fill1} -overlap_cells gf180mcu_fd_io__fillnc

set BOUNDARY_CELL [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__endcap]
set TAP_CELL      [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__filltie]

set_boundary_cell_rules -left_boundary_cell $BOUNDARY_CELL -right_boundary_cell $BOUNDARY_CELL
compile_targeted_boundary_cells -all_targets

set_app_options -name place.legalize.enable_advanced_legalizer -value true

# distance according to design rule LU.4: 15um
create_tap_cells -lib_cell $TAP_CELL -pattern stagger -distance 39.72

source -e $SCRIPT_DIR/common/power_grid.tcl

save_block -as floorplan
