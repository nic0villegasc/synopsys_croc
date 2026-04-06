# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

source [file dirname [info script]]/common/open_lib.tcl
open_block synthesis

# lower clock uncertainty
foreach s [get_attribute [get_scenarios] -name name] {
  current_scenario $s
  set_clock_uncertainty -setup 0.7 [get_clocks clock]
}

# remove early synthesis constraints
set_lib_cell_purpose -include {hold optimization} [get_lib_cells $SYN_IGNORE_CELLS]

# set cells for CTS
set_lib_cell_purpose -exclude cts [get_lib_cells]
set_lib_cell_purpose -include cts [get_lib_cells $CTS_CELLS]

clock_opt

save_block -as cts