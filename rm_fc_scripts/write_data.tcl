##########################################################################################
# Script: write_data.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_setup.tcl
if { [info exists rm_dp_flow] } {rm_source -file ./rm_setup/fc_dp_setup.tcl}
rm_source -file ./rm_setup/header_fc.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

if { [info exists env(RM_VARFILE)] } {
  if { [file exists $env(RM_VARFILE)] } {
    rm_source -file $env(RM_VARFILE)
  } else {
    puts "RM-error: env(RM_VARFILE) specified but not found"
  }
}

if {[info exist INCREMENTAL_INIT_DESIGN]} {rm_source -file ./rm_setup/incremental_design_setup.tcl}
if {$HPC_CORE != ""} {rm_source -file ./inputs/plugin/hpc_vars.tcl}

## This is a common file used in both the DP and PNR flows.  The variable "rm_dp_flow" is passed from the DP Makefile to indicate
## that the DP flow is being run.
if { [info exists rm_dp_flow] } {
  if { $DP_FLOW == "flat" } {
    open_lib $DESIGN_LIBRARY
    copy_block -from ${DESIGN_NAME}/${PLACE_PINS_FLAT_BLOCK_NAME} -to ${DESIGN_NAME}/${WRITE_DATA_BLOCK_NAME}
    current_block ${DESIGN_NAME}/${WRITE_DATA_BLOCK_NAME}
    link_block
  } else {
    set PREVIOUS_STEP $BUDGETING_BLOCK_NAME
    set CURRENT_STEP  $WRITE_DATA_BLOCK_NAME
    rm_open_design -from_lib      ${WORK_DIR}/${DESIGN_LIBRARY} \
                   -block_name    $DESIGN_NAME \
                   -from_label    $PREVIOUS_STEP \
                   -to_label      $CURRENT_STEP \
	           -dp_block_refs $DP_BLOCK_REFS
  }
} else {
  open_lib $DESIGN_LIBRARY
  copy_block -from ${DESIGN_NAME}/${WRITE_DATA_FROM_BLOCK_NAME} -to ${DESIGN_NAME}/${WRITE_DATA_BLOCK_NAME}
  current_block ${DESIGN_NAME}/${WRITE_DATA_BLOCK_NAME}
  link_block
}

## Non-persistent settings to be applied in each step (optional)
rm_source -file $TCL_USER_NON_PERSISTENT_SCRIPT -optional -print "TCL_USER_NON_PERSISTENT_SCRIPT"

########################################################################
## Pre-write_data customizations
########################################################################
rm_source -optional -file $TCL_USER_WRITE_DATA_PRE_SCRIPT -print TCL_USER_WRITE_DATA_PRE_SCRIPT

########################################################################
## change_names
########################################################################
## Purpose : change the names of ports, cells, and nets in a design, in order to make the output netlist, 
#  DEF, SPEF, ... etc conform to specified name rules
#  Note : 
#  - If the current block is a sub cell of another block, make sure no port names are changed during change_names;
#    if there is, you either modify your naming rule to avoid the name change, re-setup the connection between
#    the renamed port and the net at the parent level, or if the blocks are from commit_block then you can run 
#    the same change_names command before commit_block at the parent level.
#  - To preview whether there is any potential port name changes, check the report_names log first
redirect -tee -file ${REPORTS_DIR}/${WRITE_DATA_BLOCK_NAME}.report_names.log {report_names -rules verilog}

change_names -rules verilog -hierarchy

save_block

########################################################################
## write_verilog for logic only, DC, PT, FM, and VC LP
########################################################################
## write_verilog (no pg, and no physical only cells)
set write_verilog_logic_only_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations pg_objects end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.v"

## write_verilog for comparison with a DC netlist (no pg, no physical only cells, and no diodes)
set write_verilog_dc_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations pg_objects end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells diode_cells} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.dc.v"

## write_verilog for PrimeTime (no pg, no physical only cells but with diodes and DCAP for leakage power analysis)
set write_verilog_pt_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations pg_objects end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells flip_chip_pad_cells} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.pt.v"
if {$CHIP_FINISH_METAL_FILLER_LIB_CELL_LIST != ""} {
	lappend write_verilog_pt_cmd -force_reference $CHIP_FINISH_METAL_FILLER_LIB_CELL_LIST
}

## write_verilog for Formality (with pg, no physical only cells, and no supply statements) or (no physical only cells and no supply statements if after compile)
if { ($WRITE_DATA_FROM_BLOCK_NAME == $COMPILE_BLOCK_NAME) && !${UNIFIED_FLOW} } {
        set write_verilog_fm_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells supply_statements pg_objects } -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.fm.v"
} else {
        set write_verilog_fm_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells supply_statements} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.fm.v"
}

## write_verilog for VC LP (with pg, no physical_only cells, no diodes, and no supply statements)
set write_verilog_vclp_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells diode_cells supply_statements} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.vc_lp.v"

puts "RM-info: running $write_verilog_logic_only_cmd"
puts "RM-info: running $write_verilog_dc_cmd"
puts "RM-info: running $write_verilog_pt_cmd"
puts "RM-info: running $write_verilog_fm_cmd"
puts "RM-info: running $write_verilog_vclp_cmd"
parallel_execute -commands_only {
	{eval $write_verilog_logic_only_cmd}
	{eval $write_verilog_dc_cmd}
	{eval $write_verilog_pt_cmd}
	{eval $write_verilog_fm_cmd}
	{eval $write_verilog_vclp_cmd}
}

########################################################################
## write_verilog for LVS, write_gds & write_oasis
########################################################################
## write_verilog for LVS (with pg, and with physical only cells)
set write_verilog_lvs_cmd "write_verilog -compress gzip -exclude {scalar_wire_declarations leaf_module_declarations empty_modules} -hierarchy all ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.lvs.v"

## write_gds
set write_gds_cmd "write_gds -compress -hierarchy all -long_names -keep_data_type ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.gds"
if {[file exists $WRITE_GDS_LAYER_MAP_FILE]} {lappend write_gds_cmd -layer_map $WRITE_GDS_LAYER_MAP_FILE}

## write_oasis
set write_oasis_cmd "write_oasis -compress 6 -hierarchy all -keep_data_type ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.oasis"
if {[file exists $WRITE_OASIS_LAYER_MAP_FILE]} {lappend write_oasis_cmd -layer_map $WRITE_OASIS_LAYER_MAP_FILE}

rm_source -file $SIDEFILE_WRITE_DATA -optional -print "SIDEFILE_WRITE_DATA"

puts "RM-info: running $write_verilog_lvs_cmd"
puts "RM-info: running $write_gds_cmd"
puts "RM-info: running $write_oasis_cmd"
parallel_execute -commands_only {
	{eval $write_verilog_lvs_cmd}
	{eval $write_gds_cmd}
	{eval $write_oasis_cmd}
}

########################################################################
## save_upf
########################################################################
## Write out UPF
if {$UPF_MODE != "none" } {
    switch ${UPF_MODE} {
        prime {
            ## For UPF prime flow
            save_upf ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.upf
        }
        golden {
            ## For golden UPF flow
            ## write supplemental UPF with supply exceptions
            save_upf ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.supplemental.pg.upf
            ## write supplemental UPF without supply exceptions
            set_app_options -name mv.upf.save_upf_include_supply_exceptions -value false
            save_upf ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.supplemental.upf
	    reset_app_options mv.upf.save_upf_include_supply_exceptions
        }
        default {
            puts "RM-error: UPF_MODE(${UPF_MODE}) is invalid. Please correct it."
        }
    }
}

########################################################################
## write_script, write_routing_constraints, and write_parasitics
########################################################################
## write_script
#  writes multiple files to the specified directory. 
#  It writes mode_{mode_name}.tcl for mode specific info, corner_{corner_name}.tcl for corner specific info, 
#  design.tcl for non-mode or corner specific info, cts.tcl for cts options and top.tcl that sources all scripts. 
write_script -force -compress gzip -output ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_wscript
#  -format pt generates PT compatible outputs 
write_script -force -compress gzip -format pt -output ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_wscript_for_pt

## Writes routing constraints of the design in a Tcl script, such as :
## create_routing_rule, set_routing_rule, create_wire_matching, create_length_limit, create_differential_group, 
## create_net_shielding, create_net_priority, create_bus_routing_style and set_ignored_layers.
write_routing_constraints ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_write_routing_constraints

## write_parasitics
update_timing
write_parasitics -compress -output ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}

########################################################################
## write_floorplan and write_def
########################################################################
write_floorplan \
  -format icc2 \
  -def_version 5.8 \
  -force \
  -output ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_write_floorplan \
  -read_def_options {-add_def_only_objects {all} -skip_pg_net_connections} \
  -exclude {scan_chains fills pg_metal_fills routing_rules} \
  -net_types {power ground} \
  -include_physical_status {fixed locked}

## write_def : Enable the following for LEF/DEF based FC to StarRC flow if LEF is from ICC II,
#  since write_lef in FC doesn't currently support WRONGDIRECTION syntax.
#  This is not needed if you are using LEF files which contain the WRONGDIRECTION syntax already.
#	set_app_options -name file.def.wrong_way_wiring_to_special_net -value true
set write_def_cmd "write_def -compress gzip -version 5.8 -include_tech_via_definitions ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.def"
puts "RM-info: running $write_def_cmd"
eval $write_def_cmd

if {$ENABLE_FUSA} {
  ## Dumping out the Safety Specification Format
  save_ssf ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.ssf
}


  ####################################################################################################
## Used by hierarchical design planning flow to write out block data.
## - This can be done serially or distributed.
  ####################################################################################################
if {[info exists rm_dp_flow] && ($DP_FLOW == "hier")} {
    set write_data_script "./rm_fc_scripts/write_data_files.tcl" 
   if {!$DISTRIBUTED} {
    set top_block [get_attribute [current_block] full_name]
    foreach block_ref ${DP_BLOCK_REFS} {
       set block [get_blocks -hier -filter block_name==$block_ref]
       rm_source -file $write_data_script
       current_block $top_block
    }
    current_block $top_block
   } else {
      ## Set host options for all blocks.
      set_host_options -name block_script -submit_command $BLOCK_DIST_JOB_COMMAND
      set HOST_OPTIONS "-host_options block_script"
      report_host_options

      ## Write block data via run_block_script
      eval run_block_script -script ${write_data_script} -blocks [list ${DP_BLOCK_REFS}] -work_dir ./work_dir/block_export ${HOST_OPTIONS}
   }

   ## Remove estimated corner from top-level.
   if {[llength [get_corners estimated_corner -quiet]] != 0} {
     remove_corners estimated_corner
   }

   ## Remove constraint mapping file.
   set_constraint_mapping_file -reset

   ## Set editablity false for all blocks
   set_editability -value false -blocks [get_block -hier]
   save_block
   report_editability -blocks [get_block -hier]
}

if { [ info exists rm_dp_flow ] } {
  ####################################################################################################
  ## Export handshake file between flat design planning & PNR flows.
  ## - Automation to aid in flat design planning flow.
  ####################################################################################################
  set fid [ open "./header_from_dprm.tcl" "w" ]
  puts $fid "## ----------------------------------------"
  puts $fid "##"
  puts $fid "## Created by RM with $synopsys_program_name on [date] "
  puts $fid "## - This file provides automation between the RM DP and PNR flows."
  puts $fid "## - Point to this file in the PNR init_design.tcl via variable \"header_from_dprm\"."
  puts $fid "##"
  puts $fid "## ----------------------------------------"
  puts $fid ""
  puts $fid "if {(\$INIT_DESIGN_INPUT==\"RTL\") && (\$RTL_SOURCE_FORMAT!=\"elaborated_ndm\")} {"
  puts $fid "  set TCL_FLOORPLAN_FILE [file normalize ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_write_floorplan/floorplan.tcl]"
  puts $fid "  ## Below are the input files used during design planning."
  puts $fid "  ## set RTL_SOURCE_FILES [list $RTL_SOURCE_FILES]"
  puts $fid "  ## set RTL_SOURCE_FORMAT $RTL_SOURCE_FORMAT"
  puts $fid "  ## set TCL_MCMM_SETUP_FILE [file normalize [which $TCL_MCMM_SETUP_FILE]]"
  puts $fid "  ## set UPF_FILE [file normalize [which $UPF_FILE]]"
  puts $fid "  if {\[file exists ${DESIGN_LIBRARY}_dp\]} {"
  puts $fid "    file delete -force ${DESIGN_LIBRARY}_dp"
  puts $fid "  }"
  puts $fid "  file rename -force $DESIGN_LIBRARY ${DESIGN_LIBRARY}_dp"
  puts $fid "}"
  puts $fid ""
  puts $fid "if {(\$INIT_DESIGN_INPUT==\"RTL\") && (\$RTL_SOURCE_FORMAT==\"elaborated_ndm\")} {"
  puts $fid "  set TCL_FLOORPLAN_FILE [file normalize ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}_write_floorplan/floorplan.tcl]"
  puts $fid "  set DESIGN_LIBRARY [file normalize $DESIGN_LIBRARY]"
  puts $fid "  set INIT_DESIGN_INPUT_BLOCK_NAME $DESIGN_NAME/${READ_RTL_BLOCK_NAME}"
  puts $fid "  if {\[file exists ${DESIGN_LIBRARY}_dp\]} {"
  puts $fid "    file delete -force ${DESIGN_LIBRARY}_dp"
  puts $fid "  }"
  puts $fid "  file rename -force $DESIGN_LIBRARY ${DESIGN_LIBRARY}_dp"
  puts $fid "}"
  puts $fid ""
  close $fid 
} 

########################################################################
## Post-write_data customizations
########################################################################
rm_source -optional -file $TCL_USER_WRITE_DATA_POST_SCRIPT -print TCL_USER_WRITE_DATA_POST_SCRIPT

if { [ info exists rm_dp_flow ] } {
  echo [date] > write_data_dp
} elseif {[info exists INCREMENTAL_INIT_DESIGN]} {
  echo [date] > write_data_for_init_design
} else {
  echo [date] > write_data
}

exit

