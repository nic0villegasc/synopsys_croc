##########################################################################################
# Tool: Fusion Compiler 
# Script: block_create_frame.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
source -echo ./rm_setup/design_setup.tcl
source -echo ./rm_setup/fc_dp_setup.tcl
source -echo ./rm_setup/header_fc_dp.tcl

#Send jobID back to parent for tracking purposes
if {[info exist env(JOB_ID)]} {
   puts "Block: $block_refname JobID: $env(JOB_ID) - START"
}

open_block -read $block_libfilename:$block_refname

# The tool creates a zero-spacing routing blockage only on the specified layer and the layers below it
# By default all layers below $MIN_ROUTING_LAYER are blocked
create_frame -block_all $MIN_ROUTING_LAYER

close_lib
puts "Block: $block_refname - FINISHED"
