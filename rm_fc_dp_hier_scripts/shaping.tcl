##########################################################################################
# Tool: Fusion Compiler 
# Script: shaping.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_dp_setup.tcl
rm_source -file ./rm_setup/header_fc_dp.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

set REPORT_PREFIX ${SHAPING_BLOCK_NAME}
file mkdir ${REPORTS_DIR}/${REPORT_PREFIX}

################################################################################
# Create and read the design	
################################################################################
set PREVIOUS_STEP $CREATE_FLOORPLAN_BLOCK_NAME 
set CURRENT_STEP  $SHAPING_BLOCK_NAME

rm_open_design -from_lib      ${WORK_DIR}/${DESIGN_LIBRARY} \
               -block_name    $DESIGN_NAME \
               -from_label    $PREVIOUS_STEP \
               -to_label      $CURRENT_STEP \
	       -dp_block_refs $DP_BLOCK_REFS

## Non-persistent settings to be applied in each step (optional)
rm_source -file $TCL_USER_NON_PERSISTENT_SCRIPT -optional -print "TCL_USER_NON_PERSISTENT_SCRIPT"

####################################
## Pre-shaping customizations
####################################
rm_source -file $TCL_USER_SHAPING_PRE_SCRIPT -optional -print "TCL_USER_SHAPING_PRE_SCRIPT"

# Load PNS Strategy
rm_source -file $TCL_SHAPING_PNS_STRATEGY_FILE -optional -print "TCL_SHAPING_PNS_STRATEGY_FILE"

if [file exists [which $TCL_MANUAL_SHAPING_FILE]] {
   puts "RM-info : Skipping shaping, loading floorplan information from TCL_MANUAL_SHAPING_FILE ($TCL_MANUAL_SHAPING_FILE) "
   rm_source -file $TCL_MANUAL_SHAPING_FILE
} else {
   rm_source -file $TCL_SHAPING_CONSTRAINTS_FILE -optional -print "TCL_SHAPING_CONSTRAINTS_FILE"

   if {$FLOORPLAN_STYLE == "channel"} {
     set SHAPING_CMD_OPTIONS "-channels true"
   } else {
     set SHAPING_CMD_OPTIONS "-channels false"
   }

   if [file exists [which $SHAPING_CONSTRAINTS_FILE]] {
      append SHAPING_CMD_OPTIONS " -constraint_file [which $SHAPING_CONSTRAINTS_FILE]"
   }

   ####################################
   # Check Design: Pre-Block Shaping
   ####################################
   if {$CHECK_DESIGN} { 
      redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_design.pre_block_shaping \
       {check_design -ems_database check_design.pre_block_shaping.ems -checks dp_pre_block_shaping}
   }

   ###############################################
   # Shape the blocks and place top level macros
   ###############################################
   report_shaping_options > ${REPORTS_DIR}/${REPORT_PREFIX}/report_shaping_option.rpt

   puts "RM-info : Running block shaping (shape_blocks $SHAPING_CMD_OPTIONS)"
   eval shape_blocks $SHAPING_CMD_OPTIONS

   redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_block_shaping.rpt {report_block_shaping -core_area_violations -overlap -flyline_crossing}
}

###############################################
## Floorplan checking and fixing
## - Floorplan rules must be pre-defined in the library. 
## - This can be done via TCL_FLOORPLAN_RULE_SCRIPT, sidefiles, etc.
###############################################
redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_floorplan_rules.shaping \
  {check_floorplan_rules -error_view floorplan_rules_shaping}

if {$FIX_FLOORPLAN_RULES} {
  redirect -var x {catch {report_floorplan_rules}}
  if {[regexp "^.*No floorplan rules exist" $x]} {
    puts "RM-error: FIX_FLOORPLAN_RULES is set true but no floorplan rules exist.  Fixing is being skipped..."
  } else {
    ## Enable the ability to reshape the block boundaries per provided floorplan rules.
    set_app_option -name plan.floorplan_rule.reshape_soft_macros -value true
    if {![rm_source -file $TCL_FIX_FLOORPLAN_RULES_CUSTOM_SCRIPT  -optional -print "TCL_FIX_FLOORPLAN_RULES_CUSTOM_SCRIPT"]} {
      ## Resize the blocks to be rule compliant.
      fix_floorplan_rules -include soft_macro
    }
    reset_app_option plan.floorplan_rule.reshape_soft_macros
    redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_floorplan_rules.shaping.post_fix \
      {check_floorplan_rules -error_view floorplan_rules_shaping_post_fix}
  }
}

####################################
## Post-shaping customizations
####################################
rm_source -file $TCL_USER_SHAPING_POST_SCRIPT -optional -print "TCL_USER_SHAPING_POST_SCRIPT"

save_lib -all

print_message_info -ids * -summary
echo [date] > shaping

exit 
