##########################################################################################
# Script: compile_dp.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_dp_setup.tcl
rm_source -file ./rm_setup/header_fc_dp.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

set_svf ${OUTPUTS_DIR}/${COMPILE_DP_BLOCK_NAME}.svf

####################################
# Open design
####################################
open_lib $DESIGN_LIBRARY
copy_block -from ${DESIGN_NAME}/${INIT_DESIGN_DP_BLOCK_NAME} -to ${DESIGN_NAME}/${COMPILE_DP_BLOCK_NAME}
current_block ${DESIGN_NAME}/${COMPILE_DP_BLOCK_NAME}

##########################################################################################
## Settings
##########################################################################################
## set_qor_strategy : a commmand which folds various settings of placement, optimization, timing, CTS, and routing, etc.
## - To query the target metric being set, use the "get_attribute [current_design] metric_target" command
##
## - Note: For DP flow we are setting to reduced effort with timing metric.  This mega command is needed as it
## - set options used by the flow.
set set_qor_strategy_cmd "set_qor_strategy -stage synthesis -metric timing -reduced_effort"
puts "RM-info: Running $set_qor_strategy_cmd" 
eval ${set_qor_strategy_cmd}

set rm_lib_type [get_attribute -quiet [current_design] rm_lib_type]
if {$rm_lib_type != ""} {puts "RM-info: rm_lib_type = $rm_lib_type"}

## set_stage : a command to apply stage-based application options; intended to be used after set_qor_strategy within RM scripts.
set set_stage_cmd "set_stage -step synthesis"
puts "RM-info: Running ${set_stage_cmd}"
eval ${set_stage_cmd}

## Set active scenarios for compile
if {$COMPILE_DP_ACTIVE_SCENARIO_LIST != ""} {
  set_scenario_status -active false [get_scenarios -filter active]
  set_scenario_status -active true $COMPILE_DP_ACTIVE_SCENARIO_LIST
}

if { [regexp {h$} $rm_lib_type] } {
   ## Note: Recommend setting EARLY_COMPILE_STAGE to "logic_opto" for this library.
   set_app_options -name place.coarse.congestion_driven_max_util -value 0.85
   ## Define boundary via INITIALIZE_FLOORPLAN_WIDTH and INITIALIZE_FLOORPLAN_HEIGHT or INITIALIZE_FLOORPLAN_BOUNDARY.
   rm_source -file init_design.tcl.${rm_lib_type}.floorplanning ;# node/foundry specific
   eval ${set_qor_strategy_cmd}
}

####################################
## Pre-compile_dp customizations
####################################
rm_source -file $TCL_USER_COMPILE_DP_PRE_SCRIPT -optional -print "TCL_USER_COMPILE_DP_PRE_SCRIPT"

####################################
## Perform compile to establish stdcell area for floorplan initialization.
## - Use EARLY_COMPILE_STAGE to determine compile stage.
#################################### 
if {$EARLY_COMPILE_STAGE == "logic_opto"} {
   puts "RM-info : Running compile_fusion through logic_opto stage."
   compile_fusion -to logic_opto
} else {
   puts "RM-info : Running compile_fusion through initial_map stage."
   compile_fusion -to initial_map
}

####################################
## Post-compile_dp customizations
####################################
rm_source -file $TCL_USER_COMPILE_DP_POST_SCRIPT -optional -print "TCL_USER_COMPILE_DP_POST_SCRIPT"

if {![rm_source -file $TCL_USER_CONNECT_PG_NET_SCRIPT -optional -print "TCL_USER_CONNECT_PG_NET_SCRIPT"]} {
   ## Note : the following executes if TCL_USER_CONNECT_PG_NET_SCRIPT is not sourced
   ## For non-MV designs with more than one PG, you should use connect_pg_net in manual mode.
   connect_pg_net
}

change_names -rules verilog -hierarchy -skip_physical_only_cells

save_block

set_svf -off

print_message_info -ids * -summary
echo [date] > compile_dp

exit 
