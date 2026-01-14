##########################################################################################
# Tool: Fusion Compiler
# Script: read_rtl.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

# Controls HDLC naming style settings to make it easier to apply
# the same UPF file across multiple tools at the RTL level
set_app_options -name hdlin.naming.upf_compatible -value true

# set_app_options -name hdlin.elaborate.ff_infer_async_set_reset -value true
# set_app_options -name hdlin.elaborate.ff_infer_sync_set_reset  -value false

####################################
## Pre read RTL customizations
####################################
rm_source -file $TCL_USER_READ_RTL_PRE_SCRIPT -optional -print "TCL_USER_READ_RTL_PRE_SCRIPT"

########################################################################
## Analyze / Elaborate
########################################################################
switch ${RTL_SOURCE_FORMAT} {
        sverilog {
                analyze -format sverilog ${RTL_SOURCE_FILES}
                elaborate ${DESIGN_NAME}

                # Following is applicable for designs wtih physical hierarchy; for intermediate and top-levels
                # Specify the label of the sub-block to which sub-block instances are to be linked
                if {$DESIGN_STYLE == "hier" && $PHYSICAL_HIERARCHY_LEVEL != "bottom" && $BLOCK_ABSTRACT_FOR_COMPILE != ""} {
                    set_label_switch_list  "$BLOCK_ABSTRACT_FOR_COMPILE"
                }
                set_top_module ${DESIGN_NAME}
        }
        verilog {
                analyze -format verilog ${RTL_SOURCE_FILES}
                elaborate ${DESIGN_NAME}

                # Following is applicable for designs wtih physical hierarchy; for intermediate and top-levels
                # Specify the label of the sub-block to which sub-block instances are to be linked
                if {$DESIGN_STYLE == "hier" && $PHYSICAL_HIERARCHY_LEVEL != "bottom" && $BLOCK_ABSTRACT_FOR_COMPILE != ""} {
                    set_label_switch_list  "$BLOCK_ABSTRACT_FOR_COMPILE"
                }
                set_top_module ${DESIGN_NAME}
        }
        vhdl {
                analyze -format vhdl ${RTL_SOURCE_FILES}
                elaborate ${DESIGN_NAME}

                # Following is applicable for designs wtih physical hierarchy; for intermediate and top-levels
                # Specify the label of the sub-block to which sub-block instances are to be linked
                if {$DESIGN_STYLE == "hier" && $PHYSICAL_HIERARCHY_LEVEL != "bottom" && $BLOCK_ABSTRACT_FOR_COMPILE != ""} {
                    set_label_switch_list  "$BLOCK_ABSTRACT_FOR_COMPILE"
                }
                set_top_module ${DESIGN_NAME}
        }
        script {
		if {![rm_source -file $FC_RTL_READ_SCRIPT]} {
		## Note : The following executes only if FC_RTL_READ_SCRIPT is not sourced
			exit
		}
        }
        elaborated_ndm {
		if {[file exists $DESIGN_LIBRARY]} {
			open_lib ${DESIGN_LIBRARY}
			open_block ${DESIGN_NAME}
		}
        }
        default {
                puts "RM-error: Unknown RTL_READ_FORMAT(${RTL_READ_FORMAT})"
                exit 
        }
}

####################################
## Post read RTL customizations
####################################
rm_source -file $TCL_USER_READ_RTL_POST_SCRIPT -optional -print "TCL_USER_READ_RTL_POST_SCRIPT"

