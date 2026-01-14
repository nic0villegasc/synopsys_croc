##########################################################################################
# Tool: Formality Verification for Fusion Compiler
# Script: fm_r2g.tcl
# Purpose: run formal verification on the netlist before and after implementation
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

source ./rm_utilities/procs_global.tcl 
source ./rm_utilities/procs_fc.tcl 
rm_source -file ./rm_setup/design_setup.tcl
rm_source -file ./rm_setup/fc_setup.tcl
rm_source -file ./rm_setup/header_fc.tcl

#################################################################################
## Synopsys Auto Setup Mode
#################################################################################

# Synopsys Auto Setup mode
set_app_var synopsys_auto_setup true

# Note: The Synopsys Auto Setup mode is less conservative than the Formality default 
# mode, and is more likely to result in a successful verification out-of-the-box.
#
# Using the Setting this variable will change the default values of the variables 
# listed here below. You may change any of these variables back to their default 
# settings to be more conservative. Uncomment the appropriate lines below to revert 
# back to their default settings:

# set_app_var hdlin_ignore_parallel_case true
# set_app_var hdlin_ignore_full_case true
# set_app_var verification_verify_directly_undriven_output true
# set_app_var hdlin_ignore_embedded_configuration false
# set_app_var svf_ignore_unqualified_fsm_information true
# set_app_var signature_analysis_allow_subset_match true

# Other variables with changed default values are described in the next few sections.

#################################################################################
# Setup for handling undriven signals in the design
#################################################################################

# The Synopsys Auto Setup mode sets undriven signals in the reference design to
# "0" or "BINARY" (as done by DC), and the undriven signals in the impl design are
# forced to "BINARY".  This is done with the following setting:

# set_app_var verification_set_undriven_signals synthesis

# Uncomment the next line to revert back to the more conservative default setting:

# set_app_var verification_set_undriven_signals BINARY:X

#################################################################################
# Setup for simulation/synthesis mismatch messaging
#################################################################################

# The Synopsys Auto Setup mode will produce warning messages, not error messages,
# when Formality encounters potential differences between simulation and synthesis.
# Uncomment the next line to revert back to the more conservative default setting:

# remove_mismatch_message_filter -all

#################################################################################
# Setup for Clock-gating
#################################################################################

# The Synopsys Auto Setup mode, along with the SVF file, will appropriately set 
# the clock-gating variable. Otherwise, the user will need to notify Formality 
# of clock-gating by uncommenting the next line:

# set_app_var verification_clock_gate_edge_analysis true

#################################################################################
# Setup for instantiated DesignWare or function-inferred DesignWare components
#################################################################################

# The Synopsys Auto Setup mode, along with the SVF file, will automatically set 
# the hdlin_dwroot variable to the top-level of the Descartes tree used for 
# synthesis.  Otherwise, the user will need to set this variable if the design 
# contains instantiated DW or function-inferred DW.

# set_app_var hdlin_dwroot "" ;# Enter the pathname to the top-level of the DC tree

#################################################################################
# Setup for handling missing design modules
#################################################################################

# If the design has missing blocks or missing components in both the reference and 
# implementation designs, uncomment the following variable so that Formality can 
# complete linking each design:

# set_app_var hdlin_unresolved_modules black_box

#################################################################################
# Read in the SVF file(s)
#################################################################################

# Set this variable to point to individual SVF file(s) or to a directory containing SVF files.

set svf_files {}
lappend svf_files ${OUTPUTS_DIR}/${INIT_DESIGN_BLOCK_NAME}.svf
lappend svf_files ${OUTPUTS_DIR}/${COMPILE_BLOCK_NAME}.svf
if {($WRITE_DATA_FROM_BLOCK_NAME != $COMPILE_BLOCK_NAME) && !$UNIFIED_FLOW} {
    lappend svf_files ${OUTPUTS_DIR}/${PLACE_OPT_BLOCK_NAME}.svf
}
set_svf ${svf_files}

#################################################################################
# Read in the libraries
#################################################################################

foreach tech_lib "${LINK_LIBRARY}" {
        read_db -technology_library ${tech_lib}
}

#################################################################################
# Read in the Reference Design as verilog/vhdl source code
#################################################################################

switch ${RTL_SOURCE_FORMAT} {
        sverilog {
                read_sverilog -r ${RTL_SOURCE_FILES} -work_library WORK
        }
        verilog {
                read_verilog -r ${RTL_SOURCE_FILES} -work_library WORK
        }
        vhdl {
                read_vhdl -r ${RTL_SOURCE_FILES} -work_library WORK
        }
        script {
                # The following setting allows the read script to be found in the search path
                set_app_var sh_source_uses_search_path true
                puts "RM-info: Sourcing [which ${FM_RTL_READ_SCRIPT}]"
                rm_source -file ${FM_RTL_READ_SCRIPT}
        }
        default {
                puts "RM-error: Unknown RTL_SOURCE_FORMAT(${RTL_SOURCE_FORMAT})"
                exit
        }
}

# Note: If retention registers are instantiated in the RTL then replace the
#       technology retention register models here.  See the implementation read
#       section below for details.  This should be done before set_top.
#       Most designs do not have retention registers until after mapping so
#       this is not needed.

# The following setting is needed to exclude instantiated ICG cells from being
# retained inside retention domains
set_app_var upf_use_additional_db_attributes true

set_top r:/WORK/${DESIGN_NAME}

#################################################################################
# For a UPF MV flow, read in the UPF file for the Reference Design
#################################################################################

if { ${UPF_MODE} != "none" } {
        if { ![file exists [which ${UPF_FILE}]] } {
                puts "RM-error: UPF_FILE(${UPF_FILE}) is not found or not defined."
                puts "RM-info: For UPF designs, fm.tcl requires one UPF file. Exiting"
                exit
        }
        set upf_files ${UPF_FILE}
        if { [file exists [which ${UPF_UPDATE_SUPPLY_SET_FILE}]] } { lappend upf_files "${UPF_UPDATE_SUPPLY_SET_FILE}" }                        
        load_upf -r "${upf_files}"
}

#################################################################################
# Read in the Implementation Design from FC-RM results
#
# Choose the format that is used in your flow.
#################################################################################

read_verilog -i ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.fm.v.gz

#################################################################################
# Read in Retention Register Simulation Models
#################################################################################

# If you are mapping to retention registers in your design, you need to replace the
# technology library models of those cells with Verilog simulation models for
# Formality verification.  Please see the following SolvNet article for details:

# https://solvnet.synopsys.com/retrieve/024106.html

# set_top should be run only after the retention register models have been replaced. 

set_top i:/WORK/${DESIGN_NAME}

#################################################################################
# For a UPF MV flow, read in the UPF file for the Implementation Design
#################################################################################

if { ${UPF_MODE} != "none" && ($WRITE_DATA_FROM_BLOCK_NAME == $COMPILE_BLOCK_NAME) && !${UNIFIED_FLOW} } {
    switch ${UPF_MODE} {
        prime {
            if { ![file exists [which ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.upf]] } {
                puts "RM-error: ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.upf is not found or not defined."
                puts "RM-info: For UPF designs, fm.tcl requires one UPF file. Exiting"
                exit
            }
            load_upf -i ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.upf
        }
        golden {
            set upf_file_not_found false
            if { ![file exists [which ${UPF_FILE}]] } {
                puts "RM-error: UPF_FILE(${UPF_FILE}) is not found or not defined."
                set upf_file_not_found true
            }
            if { ![file exists [which ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.supplemental.upf]] } {
                puts "RM-error: ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.supplemental.upf is not found or not defined."
                set upf_file_not_found true
            }
            if { ${upf_file_not_found} } {
                puts "RM-info: For golden UPF designs, fm.tcl requires one UPF file and one supplemental UPF file. Exiting"
                exit
            }
            set upf_files ${UPF_FILE}
            if { [file exists [which ${UPF_UPDATE_SUPPLY_SET_FILE}]] } { lappend upf_files "${UPF_UPDATE_SUPPLY_SET_FILE}" }                        
            load_upf -i -strict_check false -target dc_netlist "${upf_files}" \
                -supplemental ${OUTPUTS_DIR}/${WRITE_DATA_BLOCK_NAME}.supplemental.upf
        }
        default {
            puts "RM-error: Unknown UPF_MODE(${UPF_MODE})"
            exit 
        }
    }
}

#################################################################################
# Configure constant ports
#
# When using the Synopsys Auto Setup mode, the SVF file will convey information
# automatically to Formality about how to disable scan.
#
# Otherwise, manually define those ports whose inputs should be assumed constant
# during verification.
#
# Example command format:
#
#   set_constant -type port i:/WORK/${DESIGN_NAME}/<port_name> <constant_value> 
#
#################################################################################

#################################################################################
# Report design statistics, design read warning messages, and user specified setup
#################################################################################

# report_setup_status will create a report showing all design statistics,
# design read warning messages, and all user specified setup.  This will allow
# the user to check all setup before proceeding to run the more time consuming
# commands "match" and "verify".

# report_setup_status

#################################################################################
# Note in using the UPF MV flow with Formality:
#
# By default Formality verifies low power designs with all UPF supplies 
# constrained to their ON state.  For FC-RM,
# is it recommended to set this variable to false instead.

set_app_var verification_force_upf_supplies_on false

#################################################################################

#################################################################################
# Match compare points and report unmatched points 
#################################################################################

match

report_unmatched_points > ${REPORTS_DIR}/${DESIGN_NAME}.fmv_unmatched_points.rpt

#################################################################################
# Verify and Report
#
# If the verification is not successful, the session will be saved and reports
# will be generated to help debug the failed or inconclusive verification.
#################################################################################

if { ![verify] }  {  
        save_session -replace ${REPORTS_DIR}/${DESIGN_NAME}
        report_failing_points > ${REPORTS_DIR}/${DESIGN_NAME}.fmv_failing_points.rpt
        report_aborted > ${REPORTS_DIR}/${DESIGN_NAME}.fmv_aborted_points.rpt
        # Use analyze_points to help determine the next step in resolving verification
        # issues. It runs heuristic analysis to determine if there are potential causes
        # other than logical differences for failing or hard verification points. 
        analyze_points -all > ${REPORTS_DIR}/${DESIGN_NAME}.fmv_analyze_points.rpt
        set fm_passed FALSE
} else {
        set fm_passed TRUE
}

echo [date] > fm

exit 
