##########################################################################################
# Tool: Fusion Compiler 
# Script: place_pins.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_dp_setup.tcl
rm_source -file ./rm_setup/header_fc_dp.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

set REPORT_PREFIX ${PLACE_PINS_FLAT_BLOCK_NAME}
file mkdir ${REPORTS_DIR}/${REPORT_PREFIX}

####################################
## Error check operation setup
####################################
set valid_operations {PLACE_PINS}
set operations [list ]
if { $PLACE_PINS_OPERATIONS == "ALL" } {
  set operations $valid_operations
} else {
  foreach operation $PLACE_PINS_OPERATIONS {
    if { [lsearch $operations $operation] >=0} {
      puts "RM-warning: Skipping duplicate \"$operation\" specification in PLACE_PINS_OPERATIONS."
    } elseif { [lsearch $valid_operations $operation] >=0} {
      lappend operations $operation
    } else {
      puts "RM-error: Skipping operation \"$operation\" as it is not valid.  See PLACE_PINS_OPERATIONS comments for valid values."
    }
  }
}
if {[llength $operations] > 0} {
  puts "RM-info: Performing the following operations: \"$operations\""
} else {
  puts "RM-warning: No valid operations were specified: PLACE_PINS_OPERATIONS == $PLACE_PINS_OPERATIONS.  This task is effectively being skipped."
}

####################################
# Open design
####################################
open_lib $DESIGN_LIBRARY
copy_block -from ${DESIGN_NAME}/${CREATE_POWER_FLAT_BLOCK_NAME} -to ${DESIGN_NAME}/${PLACE_PINS_FLAT_BLOCK_NAME}
current_block ${DESIGN_NAME}/${PLACE_PINS_FLAT_BLOCK_NAME}

####################################
## Pre-place_pins User Customizations
####################################
rm_source -file $TCL_USER_PLACE_PINS_FLAT_PRE_SCRIPT -optional -print "TCL_USER_PLACE_PINS_FLAT_PRE_SCRIPT"

if { [lsearch $operations "PLACE_PINS"] >=0 } {

  ################################################################################
  ## Place design pins
  ################################################################################
  
  ## This file contains the pin constraints in TCL format (i.e. set_*_pin_constraints)
  rm_source -file $TCL_PIN_CONSTRAINT_FILE -optional -print "TCL_PIN_CONSTRAINT_FILE"

  ## This file contains the pin constraints in pin constraint format.
  if {[file exists [which $CUSTOM_PIN_CONSTRAINT_FILE]]} {
    read_pin_constraints -file_name $CUSTOM_PIN_CONSTRAINT_FILE
  }

  ## Check Design: Pre-Pin Placement
  if {$CHECK_DESIGN} { 
    redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_design.pre_pin_placement \
    {check_design -ems_database check_design.pre_pin_placement.ems -checks dp_pre_pin_placement}
  }

  ## Detect if pin placement was performed in the create_floorplan task (i.e. port_placement_export_file exists).
  ## - If so, restore and legalize the pins where were reset during the create_power task.
  ## - Otherwise, run full pin placement.
  if {[get_attribute -quiet [current_block] port_placement_export_file] != ""} {
    rm_source -file [get_attribute [current_block] port_placement_export_file]
    place_pins -self -legalize
  } else {
    ## Place pins
    place_pins -self
  }
  
  ## Write top-level port constraint file based on actual port locations in the design for reuse during incremental run.
  write_pin_constraints -self \
    -file_name $OUTPUTS_DIR/preferred_port_locations.tcl \
    -physical_pin_constraint {side | offset | layer} \
    -from_existing_pins

  ## Verify Top-level Port Placement Results
  redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_pin_placement {check_pin_placement -self -pre_route true -pin_spacing true -sides true -layers true -stacking true}

  ## Generate Top-level Port Placement Report
  redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_pin_placement {report_pin_placement -self}
}

####################################
## Post-place_pins customizations
####################################
rm_source -file $TCL_USER_PLACE_PINS_FLAT_POST_SCRIPT -optional -print "TCL_USER_PLACE_PINS_FLAT_POST_SCRIPT"

save_block

print_message_info -ids * -summary
echo [date] > place_pins

exit 
