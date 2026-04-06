# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

source [file dirname [info script]]/common/open_lib.tcl

open_block cts

# We need to add these in here
connect_pg_net -net VDD [get_pins -hierarchical  "*/VNW"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/VPW"]
connect_pg_net

route_auto

route_detail -incremental true

save_block -as route
