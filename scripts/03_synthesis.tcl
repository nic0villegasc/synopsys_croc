# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

source [file dirname [info script]]/common/open_lib.tcl
open_block floorplan

###########################################################
# QOR settings
###########################################################


set_app_options -name ccd.max_prepone -value 2.4
set_app_options -name ccd.max_postpone -value 0.8

# configure initial subset of cells for synthesis
set_lib_cell_purpose -include none [get_lib_cells $SYN_IGNORE_CELLS]


###############################################################################
# Synthesis MEGA COMMAND
###############################################################################
compile_fusion

set ACTIVE_STEP "03_synthesis"
source [file dirname [info script]]/common/reporting.tcl

save_block -as synthesis