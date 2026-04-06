# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

##############################################################
# Power Grid (GF180MCU)
##############################################################

##############################################################
# Reset grid
##############################################################
remove_pg_strategies -all
remove_pg_patterns -all
remove_pg_regions -all
remove_pg_via_master_rules -all
remove_pg_strategy_via_rules -all
remove_routes -net_types {power ground} -ring -stripe -macro_pin_connect -lib_cell_pin_connect


##############################################################
# Connect nets
##############################################################
create_net -power VDD
create_net -ground VSS

connect_pg_net -net VDD [get_pins -hierarchical  "*/VDD"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/VSS"]

## ADDED THIS TO scripts/05_route.tcl. It errors out here
## Maybe it should be put somewhere else. But for now this is what we have.
#connect_pg_net -net VDD [get_pins -hierarchical  "*/VNW"]
#connect_pg_net -net VSS [get_pins -hierarchical  "*/VPW"]

connect_pg_net -net VDD [get_pins -hierarchical  "*/DVDD"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/DVSS"]

##############################################################
# Power Ring around Design Boundary
##############################################################
set_pg_via_master_rule via_master_mesh_top -contact_code Via4_VV
create_pg_ring_pattern main_ring_pattern -nets {VDD VSS} \
    -horizontal_layer Metal5 -horizontal_width 10 -horizontal_spacing 2 \
    -vertical_layer Metal4   -vertical_width 10   -vertical_spacing 2 \
    -via_rule {{intersection: adjacent} {via_master: via_master_mesh_top}}

set_pg_strategy main_ring_strategy -core -pattern {{pattern: main_ring_pattern} {nets: {VDD VSS}} {offset: {2 2}}}
compile_pg -strategies main_ring_strategy

##############################################################
# IO Ring Connection
##############################################################
create_pg_macro_conn_pattern io_to_ring -pin_conn_type scattered_pin \
    -pin_layers {Metal2} -layers {Metal2 Metal2} -width 9.5

set_pg_strategy s_io_to_ring -macros [get_cells *added_power_driver*] \
    -pattern {{name: io_to_ring}{nets: {VDD VSS}}}

##############################################################
# Std rail and global power mesh
##############################################################

create_pg_std_cell_conn_pattern M1_rail -layers {Metal1}
set_pg_strategy M1_rail_strategy -core -pattern {{name: M1_rail} {nets: VDD VSS}} \
  -blockage {{nets:VDD VSS} {macros: all}}

create_pg_mesh_pattern mesh_pattern_top -via_rule {{intersection: adjacent} {via_master: via_master_mesh_top}} \
    -layers { \
        {{horizontal_layer: Metal5 } {width: 3} {pitch: 90} {spacing: interleaving} } \
        {{vertical_layer:   Metal4 } {width: 3} {pitch: 90} {spacing: interleaving} } \
}

set_pg_strategy mesh_strategy_top -core -pattern {{pattern: mesh_pattern_top} {nets: {VDD VSS}}} -extension {stop: outermost_ring}

set_pg_via_master_rule via_to_stdcells -via_array_dimension {3 1}

set_pg_strategy_via_rule mesh_to_stdrail -via_rule { \
    { \
      {{strategies: s_io_to_ring} {layers: {Metal2 Metal5 Metal4}}} \
      {{existing: ring} {layers: {Metal5 Metal4}}} \
      {via_master: {Via3_VV Via4_VV}} \
    } \
    { \
      {{strategies: mesh_strategy_top} {layers: Metal4}} \
      {{strategies: M1_rail_strategy} {layers: Metal1}} \
      {via_master: via_to_stdcells} \
    } \
    { \
      {{strategies: mesh_strategy_top}} \
      {{existing: ring} {layers: { Metal5 Metal4 }} } \
      {via_master:  via_master_mesh_top} \
    } \
    {{intersection: undefined} {via_master: NIL}} \
}

compile_pg -strategies {M1_rail_strategy s_io_to_ring mesh_strategy_top} -via_rule mesh_to_stdrail
