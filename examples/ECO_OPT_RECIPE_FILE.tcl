
##########################################################################################
# Script: ECO_OPT_RECIPE_FILE.tcl (example)
# Version: T-2022.03
# Copyright (C) 2014-2022 Synopsys, Inc. All rights reserved.
##########################################################################################
# This is an example for executing multiple eco_opt loops and is intended
# for advanced usage of eco_opt.  The variable ECO_OPT_RECIPE_FILE is used 
# to point to this file, which is used in the timing_eco.tcl script.  The actual 
# order (or "recipe") is design dependent.  There is flexibility to run a single
# eco_opt targeting specific eco types, in addition to multiple rounds of eco_opt. 
# All of this is run in a single tool invocation.  If you are unsure of what to 
# run, you should run the eco_opt tool default.  To do this, set the following
# variables to NULL in fc_seup.tcl: ECO_OPT_RECIPE_FILE & ECO_OPT_TYPE.
#
# Example usage:
# set eco_opt(1) "drc total_power"
# set eco_opt(2) "setup"
# set eco_opt(3) "hold"
#
# The above will run three rounds of eco_opt.  The first round will target "drc"
# and "total_power".  The second round will target "setup".  The third round will
# target "hold".

