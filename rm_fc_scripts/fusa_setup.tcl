##########################################################################################
# Script: fusa_setup.tcl
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################

## Load the SSF File
load_ssf $FUSA_SSF_FILE 

## Load physical updates for the SSF File
if { $FUSA_SSF_UPDATE_FILE != "" } {
	load_ssf $FUSA_SSF_UPDATE_FILE 
}

## Load the Auxilliary SSF from Spyglass FuSa
if { $FUSA_SSF_AUX_FILE != "" } {
	load_ssf $FUSA_SSF_AUX_FILE
}

## Turning on Advanced Legalizer
if {![get_app_option -name place.legalize.enable_advanced_legalizer]} { 
  puts "RM-info: Turning on Advanced Legalizer for FuSa"
  set_app_options -name place.legalize.enable_advanced_legalizer -value true
}

##########################################################################################
## Safety Register Setup
##########################################################################################
## Required app options for Safety Registers and DCLS
if {[sizeof_collection [get_safety_register_rules -quiet]]} {
        
        puts "RM-info: Enable split pin marking during tree spltting"
        set_app_options -name report.safety.enable_split_pin_marking -value true

  
	## Ensure TAP cells are placed abutted either side of safety registers, default is shared
  	set_app_options -name place.legalize.enable_safety_register_groups_dual_taps -value true

}
# ----------------------------------------------------------
#
# DCLS Setup
#
# ----------------------------------------------------------
if {[sizeof_collection [get_safety_core_groups -quiet]]} {

  puts "RM-info: Safety Cores are defined"

  # ----------------------------------------------------------
  # Required placement app options for DCLS FuSa flow
  # ----------------------------------------------------------
  # Improve DCLS core placement separation
  set_app_options -name place.coarse.grp_rep_gbs_use_slow_snaps -value true 
  set_app_options -name place.coarse.grp_rep_gbs_start_stronger -value true
  
  # fix issue where cells of cores were being placed over macros   
  set_app_options -name place.coarse.grp_rep_gbs_aware_blockage_shove  -value true
  
  # new auto bounds feature
  set_app_options -name place.coarse.grp_rep_gbs_add_move_bounds -value true

  # Stop the cores from being ungrouped
  set_app_options -name cstrmgr.support_freeze_ports_addon -value true

  # ----------------------------------------------------------
  # Stop DFT port punching through cores
  # ----------------------------------------------------------
  # create separate partion for Safety Cores
  if { $FUSA_ENABLE_DCLS_SCAN_PROTECTION } {
    puts "RM-info: Enabling DCLS Scan Protection"
    set cores [get_attribute -objects [get_safety_core_groups] -name safety_cores]
    set i 0
    foreach_in_collection core $cores {
      set coreName [get_object_name $core]
      set_scan_skew_group safetycore_${i} -include_elements $coreName  
      incr i
    }
    redirect -tee -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_scan_skew_group {report_scan_skew_group}
  }

  # ----------------------------------------------------------
  # Split the DCLS clock nets
  #   also performs freeze ports on core clocks
  # ----------------------------------------------------------
  if { ($FUSA_CLOCK_SPLIT_BUF != "") && ($FUSA_CLOCK_SPLIT_INV != "") } {
    puts "RM-info: Performing DCLS clock Splitting"
    set splitPins [get_attribute -objects [get_safety_core_groups] -name split_pins]
    insert_redundant_trees \
    -safety_core_groups [get_safety_core_groups] \
    -buffer_lib_cell $FUSA_CLOCK_SPLIT_BUF \
    -inverter_lib_cell $FUSA_CLOCK_SPLIT_INV \
    -pins $splitPins
  }


  redirect -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_safety_core_groups {report_safety_core_groups}
}


redirect -tee -file ${REPORTS_DIR}/${REPORT_PREFIX}/report_safety_status.check_setup {report_safety_status -check_setup}

