##########################################################################################
# Tool: IC Compiler II
# Script: init_design_dp.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_dp_setup.tcl
rm_source -file ./rm_setup/header_fc_dp.tcl
rm_source -file sidefile_setup.tcl -after_file technology_override.tcl

set REPORT_PREFIX ${INIT_DESIGN_DP_BLOCK_NAME}
file mkdir ${REPORTS_DIR}/${REPORT_PREFIX}

rm_source -file $TCL_USER_INIT_DESIGN_DP_PRE_SCRIPT -optional -print "TCL_USER_INIT_DESIGN_DP_PRE_SCRIPT"

########################################################################
## Design library creation/import
########################################################################
if {$INIT_DESIGN_INPUT == "RTL"} {
	if {$RTL_SOURCE_FORMAT != "elaborated_ndm"} {
		if {[file exists $DESIGN_LIBRARY]} {
			file delete -force $DESIGN_LIBRARY
		}
		set create_lib_cmd "create_lib $DESIGN_LIBRARY"
		if {[file exists [which $TECH_FILE]]} {
			lappend create_lib_cmd -tech $TECH_FILE ;# recommended
		} elseif {$TECH_LIB != ""} {
			lappend create_lib_cmd -use_technology_lib $TECH_LIB ;# optional
		}
		if {$DESIGN_LIBRARY_SCALE_FACTOR != ""} {lappend create_lib_cmd -scale_factor $DESIGN_LIBRARY_SCALE_FACTOR}

		## Library configuration flow: calls library manager under the hood to generate .nlibs, store, and link them
		#  - To enable it, in design_setup.tcl, set LIBRARY_CONFIGURATION_FLOW to true,
		#    specify LINK_LIBRARY with .db files, and specify REFERENCE_LIBRARY with physical source files. 
		if {$LIBRARY_CONFIGURATION_FLOW} {set link_library $LINK_LIBRARY}

		lappend create_lib_cmd -ref_libs "$REFERENCE_LIBRARY $SUB_BLOCK_LIBRARIES"
		puts "RM-info: $create_lib_cmd"
		eval ${create_lib_cmd}
		redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_ref_libs {report_ref_libs}
	}

	#################################################################################
	## Read in the RTL design
	#################################################################################
	set_svf ${OUTPUTS_DIR}/${INIT_DESIGN_DP_BLOCK_NAME}.svf

	# Controls HDLC naming style settings to make it easier to apply; the same UPF file across multiple tools at the RTL level
	set_app_options -name hdlin.naming.upf_compatible -value true
		
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
			if {[file exists $DESIGN_LIBRARY] && $INIT_DESIGN_INPUT_BLOCK_NAME != ""} {
				open_lib ${DESIGN_LIBRARY}
				copy_block -from ${INIT_DESIGN_INPUT_BLOCK_NAME} -to ${DESIGN_NAME}/${INIT_DESIGN_DP_BLOCK_NAME}
				current_block ${DESIGN_NAME}/${INIT_DESIGN_DP_BLOCK_NAME}
			} else {
				puts "RM-error: RTL_SOURCE_FORMAT is set to elaborated_ndm but either DESIGN_LIBRARY or INIT_DESIGN_INPUT_BLOCK_NAME is invalid. Please fix it before you continue."
				exit
			}
        	}
        	default {
        	        puts "RM-error: Unknown RTL_READ_FORMAT(${RTL_READ_FORMAT})"
        	        exit 
        	}
	} ;# switch

	## Design check manager
	if {$EARLY_DATA_CHECK_POLICY != "none"} {set_early_data_check_policy -policy $EARLY_DATA_CHECK_POLICY -if_not_exist}
	
	save_block -as ${DESIGN_NAME}/${READ_RTL_BLOCK_NAME}

        ## Assure unique module names including hierarchical integration. Must run before physical constraints applied for MV designs
        puts "RM-info: Uniquifying the Design"
        set_app_option -name design.uniquify_naming_style -value ${DESIGN_NAME}_%s_%d
        uniquify -force

	## Design mismatch reports
	redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/check_design.design_mismatch {check_design -ems_database check_design.design_mismatch.ems -checks design_mismatch}
	redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_design_mismatch {report_design_mismatch -verbose}
	redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_unbound {report_unbound}

	## DFT Ports
	rm_source -file $DFT_PORTS_FILE -optional -print "DFT_PORTS_FILE"
	rm_source -file $TCL_USER_CREATE_DFT_PORTS_POST_SCRIPT -optional -print "TCL_USER_CREATE_DFT_PORTS_POST_SCRIPT"
	
	################################################################
	## Read and commit the UPF file(s)  
	################################################################
	if {$UPF_MODE == "golden"} {set_app_options -name mv.upf.enable_golden_upf -value true}
	if {$UPF_MODE != "none"} {
		if {[file exists [which $UPF_FILE]]} {
	      		load_upf $UPF_FILE
			## Read the supply set file
			if {[file exists [which $UPF_UPDATE_SUPPLY_SET_FILE]]} {
			      load_upf $UPF_UPDATE_SUPPLY_SET_FILE
			} elseif {$UPF_UPDATE_SUPPLY_SET_FILE != ""} {
			      puts "RM-error: UPF_UPDATE_SUPPLY_SET_FILE($UPF_UPDATE_SUPPLY_SET_FILE) is invalid. Please correct it."
			}
			puts "RM-info: Running commit_upf"
	      		commit_upf
		} elseif {$UPF_FILE != ""} {
	      		puts "RM-error : UPF file($UPF_FILE) is invalid. Please correct it."
		}
	}

	if {$TECHNOLOGY_NODE != "" && !$SET_TECHNOLOGY_AFTER_FLOORPLAN} {
		set_technology -node $TECHNOLOGY_NODE
	}

	####################################
	## Floorplan : from DEF 
	####################################
	## Floorplanning by reading $DEF_FLOORPLAN_FILES_DP (supports multiple DEF files)
	#  Script first checks if all the specified DEF files are valid, if not, read_def is skipped
	if {$DEF_FLOORPLAN_FILES_DP != ""} {
		set RM_DEF_FLOORPLAN_FILE_is_not_found FALSE
		foreach def_file $DEF_FLOORPLAN_FILES_DP {
	      		if {![file exists [which $def_file]]} {
	      			puts "RM-error : DEF floorplan file ($def_file) is invalid."
	      			set RM_DEF_FLOORPLAN_FILE_is_not_found TRUE
	      		}
		}
	      	if {!$RM_DEF_FLOORPLAN_FILE_is_not_found} {
			set read_def_cmd "read_def $DEF_READ_OPTIONS [list $DEF_FLOORPLAN_FILES_DP]"
	      		#set read_def_cmd "read_def -add_def_only_objects $DEF_OBJECTS_TO_ADD [list $DEF_FLOORPLAN_FILES_DP]" 
	      		#if {$DEF_SITE_NAME_PAIRS != ""} {lappend read_def_cmd -convert $DEF_SITE_NAME_PAIRS}
	      		puts "RM-info: Creating floorplan from DEF file DEF_FLOORPLAN_FILES_DP ($DEF_FLOORPLAN_FILES_DP)"
			puts "RM-info: $read_def_cmd"
			eval ${read_def_cmd}

			redirect -var x {catch {resolve_pg_nets}} ;# workaround in case resolve_pg_nets returns warning that causes conditional to exit unexpectedly 
			puts $x
			if {[regexp ".*NDMUI-096.*" $x]} {
				puts "RM-error: UPF may have an issue. Please review and correct it."
			}
	      	} else {
	      		puts "RM-error : At least one of the DEF_FLOORPLAN_FILES_DP specified is invalid. Please correct it."
	      		puts "RM-info: Skipped reading of DEF_FLOORPLAN_FILES_DP"
	      	}
	} elseif {$TCL_FLOORPLAN_FILE_DP != ""} {
		rm_source -file $TCL_FLOORPLAN_FILE_DP
	}
} ;# INIT_DESIGN_INPUT == RTL

################################################################
## Technology & settings  
################################################################
## Load SIDEFILE_INIT_DESIGN if set_technology was previously set.  If your node requires set_technology after the floorplan
## is created, set_technology and the sourcing of this file are done in the create_floorplan.tcl script.
if {!$SET_TECHNOLOGY_AFTER_FLOORPLAN} {
	rm_source -file $SIDEFILE_INIT_DESIGN -optional -print "SIDEFILE_INIT_DESIGN"
}

## Technology setup includes routing layer direction, offset, site default, and site symmetry
#  - If TECH_FILE is used, technology setup is required 
#  - If TECH_LIB is used while it does not contain the technology setup, then it is required
#  Specify your technology setup script through TCL_TECH_SETUP_FILE. RM default is init_design.tech_setup.tcl.
if {$TECH_FILE != "" || ($TECH_LIB != "" && !$TECH_LIB_INCLUDES_TECH_SETUP_INFO)} {
	rm_source -file $TCL_TECH_SETUP_FILE -optional -print "TCL_TECH_SETUP_FILE"
}



########################################################################
## Timer and design constraints	
########################################################################
## Parasitics
## Specify a Tcl script to read in your TLU+ files by using the read_parasitic_tech command;
## Refer to examples/TCL_PARASITIC_SETUP_FILE.tcl for sample commands
rm_source -file $TCL_PARASITIC_SETUP_FILE -optional -print "TCL_PARASITIC_SETUP_FILE"

## MCMM
#  Two examples are provided: 
#  - examples/TCL_MCMM_SETUP_FILE.explicit.tcl: provide mode, corner, and scenario constraints; create modes, corners, 
#    and scenarios; source mode, corner, and scenario constraints, respectively 
#  - examples/TCL_MCMM_SETUP_FILE.auto_expanded.tcl: provide constraints for the scenarios; create modes, corners, 
#    and scenarios; source scenario constraints which are then expanded to associated modes and corners
rm_source -file $TCL_MCMM_SETUP_FILE -optional -print "TCL_MCMM_SETUP_FILE"

## Design constrains (such as dont_touch, size_only, clock-gating settings)
rm_source -file $TCL_CONSTRAINTS_SETUP_FILE -optional -print "TCL_CONSTRAINTS_SETUP_FILE"

########################################################################
## Additional constraints
########################################################################
## Placement spacing labels, spacing rules, and abutment rules 
if {$TCL_PLACEMENT_CONSTRAINT_FILE_LIST != ""} {
  foreach file $TCL_PLACEMENT_CONSTRAINT_FILE_LIST {
    rm_source -file $file
  }
}

## Set min/max routing layers.
if {$MAX_ROUTING_LAYER != ""} {set_ignored_layers -max_routing_layer $MAX_ROUTING_LAYER}
if {$MIN_ROUTING_LAYER != ""} {set_ignored_layers -min_routing_layer $MIN_ROUTING_LAYER}

if {$INIT_DESIGN_INPUT != "RTL"} {
	## Remove all propagated clocks
	set cur_mode [current_mode]
	foreach_in_collection mode [all_modes] {
		current_mode $mode
	        remove_propagated_clocks [all_clocks]
		remove_propagated_clocks [get_ports]
		remove_propagated_clocks [get_pins -hierarchical]
	}
	current_mode $cur_mode
}

## Clock NDR
## Specify TCL_CTS_NDR_RULE_FILE with your script to create and associate your clock NDR rules.
## RM default is ./examples/cts_ndr.tcl which is an RM provided example. Refer to the script for setup and details.
## You need to also specify CTS_NDR_RULE_NAME, CTS_INTERNAL_NDR_RULE_NAME, or CTS_LEAF_NDR_RULE_NAME for it to take effect.
rm_source -file $TCL_CTS_NDR_RULE_FILE -optional -print "TCL_CTS_NDR_RULE_FILE"
redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_routing_rules {report_routing_rules -verbose}
redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_clock_routing_rules {report_clock_routing_rules}
redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_clock_settings {report_clock_settings}

## Lib cell usage restrictions (set_lib_cell_purpose)
## By default, RM sources set_lib_cell_purpose.tcl for dont use, tie cell, hold fixing, CTS and CTS-exclusive cell restrictions. 
## For advanced nodes, set_lib_cell_purpose.tcl sources node specific dont use sidefile for the corresponding node.
## You can replace it with your own script by specifying the TCL_LIB_CELL_PURPOSE_FILE variable.  
rm_source -file $TCL_LIB_CELL_PURPOSE_FILE -optional -print "TCL_LIB_CELL_PURPOSE_FILE"

## Refer to examples/init_design.additional_setup.tcl for additional examples on group_path, set_clock_gating_check, and set_power_derate

####################################
## Post-init_design customizations
####################################
rm_source -file $TCL_USER_INIT_DESIGN_DP_POST_SCRIPT -optional -print "TCL_USER_INIT_DESIGN_DP_POST_SCRIPT"

if {$UPF_MODE == "golden"} {
	save_upf ${OUTPUTS_DIR}/${INIT_DESIGN_DP_BLOCK_NAME}.supplemental.upf
} else {
	save_upf ${OUTPUTS_DIR}/${INIT_DESIGN_DP_BLOCK_NAME}.save_upf
}

save_block
save_block -as ${DESIGN_NAME}/${INIT_DESIGN_DP_BLOCK_NAME}

print_message_info -ids * -summary
echo [date] > init_design_dp
exit
