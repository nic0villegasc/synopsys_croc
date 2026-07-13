###############################################################################
# Croc SoC Physical Design Flow
# Author: Nicolás Villegas - Universidad de los Andes, Chile
# Description: Floorplanning and Power Grid
###############################################################################

source [file dirname [info script]]/common/open_lib.tcl
open_block read_rtl

set SITE_DEF unit

set target_utilization 0.63
set slot_width_limit 1000.0 
set external_gap 15.0

set macro_width [expr {$slot_width_limit - (2 * $external_gap)}]

# TODO: Probably a better way to do this
redirect -variable area_rpt {report_area}
regexp {Total cell area:\s+([0-9.]+)} $area_rpt full_match total_cell_area

set required_macro_area [expr {$total_cell_area / $target_utilization}]
set macro_height [expr {$required_macro_area / $macro_width}]

puts "INFO: Generating Macro with actual dimensions: ${macro_width}x${macro_height} um"

initialize_floorplan \
    -control_type die \
    -shape R \
    -side_length "$macro_width $macro_height" \
    -core_offset 2.0

compile_fusion -to initial_map
check_design_states -verbose

set_block_pin_constraints -self -allowed_layers {Metal1 Metal2 Metal3} -pin_spacing 2

set ports_top {
    gpio_i[5] gpio_o[5] gpio_out_en_o[5]
    gpio_i[6] gpio_o[6] gpio_out_en_o[6]
    gpio_i[7] gpio_o[7] gpio_out_en_o[7]
    gpio_i[8] gpio_o[8] gpio_out_en_o[8]
    gpio_i[9] gpio_o[9] gpio_out_en_o[9]
    gpio_i[10] gpio_o[10] gpio_out_en_o[10]
    gpio_i[11] gpio_o[11] gpio_out_en_o[11]
    gpio_i[12] gpio_o[12] gpio_out_en_o[12]
    gpio_i[13] gpio_o[13] gpio_out_en_o[13]
    gpio_i[14] gpio_o[14] gpio_out_en_o[14]
    gpio_i[15] gpio_o[15] gpio_out_en_o[15]
    jtag_trst_ni
    testmode_i
}

set ports_right {
    status_o
    jtag_tdo_o
    rst_ni
    gpio_i[1] gpio_o[1] gpio_out_en_o[1]
    gpio_i[3] gpio_o[3] gpio_out_en_o[3]
    uart_rx_i
    gpio_i[4] gpio_o[4] gpio_out_en_o[4]
}

set ports_bottom {
    jtag_tms_i
    jtag_tck_i
}

set ports_left {
    ref_clk_i
    uart_tx_o
    gpio_i[2] gpio_o[2] gpio_out_en_o[2]
    clk_i
    jtag_tdi_i
    fetch_en_i
    gpio_i[0] gpio_o[0] gpio_out_en_o[0]
}

create_pin_constraint -type individual -ports $ports_top -sides 2
create_pin_constraint -type individual -ports $ports_right -sides 3
create_pin_constraint -type individual -ports $ports_bottom -sides 4
create_pin_constraint -type individual -ports $ports_left -sides 1

create_pin_constraint -type individual -ports [get_ports *clk_i] -width 0.1 -length 0.4

place_pins -self

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

set ACTIVE_STEP "02_floorplan"
source [file dirname [info script]]/common/reporting.tcl

save_block -as floorplan
print_message_info -ids * -summary
