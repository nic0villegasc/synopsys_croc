##########################################################################################
# Tool: Fusion Compiler
# Script: top_compile.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
# Descriptions:
#  This stage is to perform top-level logic_opto stage. It's only needed when user didn't 
#  provided a floorplan. Otherwise, top-level logic_opto had been done in initial_compile
##########################################################################################


source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_dp_setup.tcl
rm_source -file ./rm_setup/header_fc_dp.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

set REPORT_PREFIX ${TOP_COMPILE_BLOCK_NAME}
file mkdir ${REPORTS_DIR}/${REPORT_PREFIX}

################################################################################
# Create and read the design	
################################################################################
set PREVIOUS_STEP $PLACE_PINS_BLOCK_NAME ;
set CURRENT_STEP  $TOP_COMPILE_BLOCK_NAME ;

rm_open_design -from_lib      ${WORK_DIR}/${DESIGN_LIBRARY} \
               -block_name    $DESIGN_NAME \
               -from_label    $PREVIOUS_STEP \
               -to_label      $CURRENT_STEP \
	       -dp_block_refs $DP_BLOCK_REFS

## Setup distributed processing options
set HOST_OPTIONS ""
if {$DISTRIBUTED} {
   ## Set host options for all blocks.
   set_host_options -name block_script -submit_command $BLOCK_DIST_JOB_COMMAND
   set HOST_OPTIONS "-host_options block_script"

   ## This is an advanced capability which enables custom resourcing for specific blocks.
   ## It is not needed if all blocks have the same resource requirements.  See the
   ## comments embedded for the BLOCK_DIST_JOB_FILE variable definition to setup.
   rm_source -file $BLOCK_DIST_JOB_FILE -optional -print "BLOCK_DIST_JOB_FILE"

   report_host_options
}

## Get block names for references defined by DP_BLOCK_REFS.  This list is used in some hier DP commands.
set child_blocks [ list ]
foreach block $DP_BLOCK_REFS {lappend child_blocks [get_object_name [get_blocks -hier -filter block_name==$block]]}
set all_blocks "$child_blocks [get_object_name [current_block]]"

## Non-persistent settings to be applied in each step (optional)
rm_source -file $TCL_USER_NON_PERSISTENT_SCRIPT -optional -print "TCL_USER_NON_PERSISTENT_SCRIPT"

####################################
## Pre-Top Compile User Customizations
####################################
rm_source -file $TCL_USER_TOP_COMPILE_PRE_SCRIPT -optional -print "TCL_USER_TOP_COMPILE_PRE_SCRIPT"

## When user provided floorplan, continue on top level logic_opto

   
##########################################################################################
## Top logic_opto compile 
##########################################################################################
if {[get_attribute [current_block] compile_fusion_step] == "initial_map"} {

   # create abstract and load the block constraints for bottom level blocks
   eval create_abstract -blocks [get_blocks $child_blocks] -read_only $HOST_OPTIONS
   
   save_lib -all

   # run compile logic optimization for mid level blocks
   set compile_block_script ./rm_fc_dp_hier_scripts/compile_block.tcl 
   if {$DP_INTERMEDIATE_LEVEL_BLOCK_REFS != ""} {
      eval run_block_script -script ${compile_block_script} \
         -blocks [list "${DP_INTERMEDIATE_LEVEL_BLOCK_REFS}"] \
         -work_dir ./work_dir/top_compile ${HOST_OPTIONS}
   }

   if {$FLOORPLAN_STYLE == "abutted"} {
      puts "RM-info : Skip top level compile in $FLOORPLAN_STYLE design"
   } else {
      # run compile logic optimization for top level
      set_app_options -name compile.auto_floorplan.enable -value false
   
      puts "RM-info :Start top level compile_fusion to logic_opto ..."
      set_editability -value false -blocks [get_blocks $child_blocks]
      compile_fusion -from logic_opto -to logic_opto
      set_attribute [current_block] compile_fusion_step logic_opto
      ## Ensure any cells added in top and intermediate blocks are placed.
      set_editability -value false -blocks [get_blocks $child_blocks]

      if { [sizeof_collection [get_cells -quiet -hierarchical -filter "is_placed==false"]]} {
         foreach blk $DP_INTERMEDIATE_LEVEL_BLOCK_REFS {
            set_editability -value true -blocks [get_blocks -hier -filter block_name==$blk]
         }
         eval create_placement -floorplan -use_seed_locs $HOST_OPTIONS
      }
      set_editability -value true -blocks [get_blocks $child_blocks]
   }
}

####################################
## Post-Top Compile User Customizations
####################################
rm_source -file $TCL_USER_TOP_COMPILE_POST_SCRIPT -optional -print "TCL_USER_TOP_COMPILE_POST_SCRIPT"

save_lib -all

print_message_info -ids * -summary
echo [date] > top_compile

exit 
