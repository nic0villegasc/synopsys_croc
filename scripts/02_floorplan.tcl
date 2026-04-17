###############################################################################
# Croc SoC Physical Design Flow
# Author: Nicolás Villegas - Universidad de los Andes, Chile
# Description: Floorplanning and Power Grid
###############################################################################

source [file dirname [info script]]/common/open_lib.tcl
open_block read_rtl

set SITE_DEF unit
#set SITE_DEF GF018hv5v_mcu_sc7

initialize_floorplan \
    -control_type die \
    -shape R \
    -side_ratio {1 1} \
    -core_utilization 0.7 \
    -core_offset 400

compile_fusion -to initial_map
check_design_states -verbose

create_io_ring -name io_ring -corner_height 355

set CORNER_CELL [get_lib_cells */gf180mcu_fd_io__cor]
create_cell {corner_0 corner_1 corner_2 corner_3} $CORNER_CELL

set pads_top {
    pad_gpio18_io pad_vss3 pad_gpio5_io pad_gpio6_io pad_gpio7_io pad_gpio8_io 
    pad_gpio9_io pad_gpio10_io pad_gpio11_io pad_gpio12_io pad_gpio13_io 
    pad_gpio14_io pad_gpio15_io pad_jtag_trst_ni pad_gpio16_io pad_gpio17_io
}

set pads_right {
    pad_vdd0 pad_vddio0 pad_status_o pad_gpio19_io pad_jtag_tdo_o pad_vdd2 
    pad_rst_ni pad_gpio1_io pad_vdd3 pad_vddio3 pad_gpio3_io pad_uart_rx_i 
    pad_vdd1 pad_vddio1 pad_gpio4_io pad_vssio3
}

set pads_bottom {
    pad_gpio20_io pad_gpio21_io pad_jtag_tms_i pad_gpio22_io pad_gpio23_io 
    pad_gpio24_io pad_gpio25_io pad_gpio26_io pad_jtag_tck_i pad_gpio27_io 
    pad_unused0_o pad_gpio28_io pad_gpio29_io pad_gpio30_io pad_unused1_o pad_unused2_o
}

set pads_left {
    pad_vss0 pad_vss1 pad_ref_clk_i pad_vss2 pad_unused3_o pad_uart_tx_o 
    pad_gpio2_io pad_vssio0 pad_vssio1 pad_clk_i pad_vddio2 pad_vssio2 
    pad_jtag_tdi_i pad_fetch_en_i pad_gpio0_io pad_gpio31_io
}

# 3. Apply Physical Constraints
set_signal_io_constraints -io_guide_object io_ring.top \
    -constraint "{ {order_only} $pads_top }"

set_signal_io_constraints -io_guide_object io_ring.right \
    -constraint "{ {order_only} $pads_right }"

set_signal_io_constraints -io_guide_object io_ring.bottom \
    -constraint "{ {order_only} $pads_bottom }"

set_signal_io_constraints -io_guide_object io_ring.left \
    -constraint "{ {order_only} $pads_left }"

# 4. Place the IOs and add fillers
place_io

create_io_filler_cells -reference_cells {gf180mcu_fd_io__fill10 gf180mcu_fd_io__fill5 gf180mcu_fd_io__fill1} -overlap_cells gf180mcu_fd_io__fillnc

shape_blocks

set all_macros [get_cells -hierarchical -filter "is_hard_macro && !is_physical_only"]
create_keepout_margin -type hard_macro -outer {10 10 10 10} $all_macros
create_keepout_margin -type hard -outer {10 10 10 10} $all_macros

create_placement -floorplan

set_fixed_objects [get_flat_cells -filter "is_hard_macro"]

# 5. Boundary and Tap Cells
set BOUNDARY_CELL [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__endcap]
set TAP_CELL      [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__filltie]

set_boundary_cell_rules -left_boundary_cell $BOUNDARY_CELL -right_boundary_cell $BOUNDARY_CELL
compile_targeted_boundary_cells -all_targets

set_app_options -name place.legalize.enable_advanced_legalizer -value true

# distance according to design rule LU.4: 15um
create_tap_cells -lib_cell $TAP_CELL -pattern stagger -distance 39.72

save_block -as floorplan_pre_pg

source [file dirname [info script]]/common/power_grid.tcl

save_block -as floorplan_post_pg
print_message_info -ids * -summary