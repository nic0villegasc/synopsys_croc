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

create_stdcell_fillers -lib_cell $DCAP_CELLS -type_utilization {{$DCAP_CELLS} 15}
create_stdcell_fillers -lib_cell $FILL_CELLS

# We need to add these in here
connect_pg_net -net VDD [get_pins -hierarchical  "*/VNW"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/VPW"]
connect_pg_net

route_detail -incremental true


change_names -rules verilog
#write_verilog top.v
write_verilog -include all -exclude_cells  [get_cells -of_references [get_lib_cells {*fill_* *filltie* *endcap*}] ] top.v
#write_verilog -include all top.v


set GDS_FILE_LIST [list \
{*}[exec find $GF180MCU_PDK/libs.ref/${GF180MCU_TRACK}/gds/ -name "*.gds"] \
{*}[exec find $GF180MCU_PDK/libs.ref/gf180mcu_fd_io/gds/ -name "*.gds"] \
]
write_gds -merge_files $GDS_FILE_LIST -merge_gds_top_cell top -layer_map ${ICC2GDS_LAYERMAP} -long_names  top.gds

save_block -as finish
