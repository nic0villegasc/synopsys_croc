# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

source [file dirname [info script]]/common/open_lib.tcl
open_block route

###################################
# FILLER Cell Insertion
###################################

set DCAP_CELLS [get_object_name [sort_collection -descending [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__fillcap*] area]]
set FILL_CELLS [get_object_name [sort_collection -descending [get_lib_cells *mcu${STDCELL_TRACK_SIZE}t5v0__fill_*] area]]

create_stdcell_fillers -lib_cells $DCAP_CELLS -type_utilization [list $DCAP_CELLS 20]
connect_pg_net -automatic
remove_stdcell_fillers_with_violation
create_stdcell_fillers -lib_cells $FILL_CELLS
connect_pg_net -automatic

route_detail -incremental true


change_names -rules verilog
#write_verilog top.v
write_verilog -include all -exclude_cells  [get_cells -of_references [get_lib_cells {*fill_* *filltie* *endcap*}] ] top.v
#write_verilog -include all top.v

set GDS_FILE_LIST [glob ${PDK_DIR}/gds/*.gds]

write_gds -merge_files $GDS_FILE_LIST -merge_gds_top_cell $TOP_MODULE -layer_map ${ICC2GDS_LAYERMAP} -long_names top.gds

set ACTIVE_STEP "06_finish"
source [file dirname [info script]]/common/reporting.tcl

save_block -as finish