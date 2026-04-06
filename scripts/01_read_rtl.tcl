# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

# This command loads the common/setup.tcl file
source [file dirname [info script]]/common/setup.tcl

###########################################################
# Library setup
###########################################################
if {[file exists $DESIGN_LIBRARY]} {
  file delete -force $DESIGN_LIBRARY
}

create_lib -technology $TECH_FILE -ref_libs $REFERENCE_LIBRARY $DESIGN_LIBRARY

###########################################################
# Read design
###########################################################
analyze -format sverilog -vcs "-F $SCRIPT_DIR/../file.lst"

elaborate $TOP_MODULE
set_top_module

###########################################################
# Technology setup
###########################################################
source -e $SCRIPT_DIR/common/tech_setup.tcl

###########################################################
# MCMM configuration
###########################################################
source -e $SCRIPT_DIR/common/mcmm.tcl


# add some report_utilization configs
create_utilization_configuration overall  -exclude io_cells
create_utilization_configuration stdcells -exclude { hard_macros macro_keepouts soft_macros io_cells hard_blockages soft_blockages }

save_block -as read_rtl
