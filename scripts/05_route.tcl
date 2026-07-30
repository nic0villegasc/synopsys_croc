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

route_auto

route_opt

route_detail -incremental true

set ACTIVE_STEP "05_route"
source [file dirname [info script]]/common/reporting.tcl

save_block -as route
