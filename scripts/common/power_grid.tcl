###############################################################################
# Croc SoC Physical Design Flow
# Author: Nicolás Villegas - Universidad de los Andes, Chile
# Description: Power Grid Creation and Connection (INCREMENTAL)
###############################################################################

##############################################################
# Reset grid & Connect Nets (Unchanged)
##############################################################
remove_pg_strategies -all
remove_pg_patterns -all
remove_pg_regions -all
remove_pg_via_master_rules -all
remove_pg_strategy_via_rules -all
remove_routes -net_types {power ground} -ring -stripe -macro_pin_connect -lib_cell_pin_connect

create_net -power VDD
create_net -ground VSS

connect_pg_net -net VDD [get_pins -hierarchical  "*/VDD"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/VSS"]
connect_pg_net -net VDD [get_pins -hierarchical  "*/VNW"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/VPW"]
connect_pg_net -net VDD [get_pins -hierarchical  "*/DVDD"]
connect_pg_net -net VSS [get_pins -hierarchical  "*/DVSS"]

set_pg_via_master_rule via_master_mesh_top -contact_code Via4_VV

##############################################################
# 1. Power Ring around Design Boundary
##############################################################
create_pg_ring_pattern main_ring_pattern -nets {VDD VSS} \
    -horizontal_layer Metal5 -horizontal_width 10 -horizontal_spacing 2 \
    -vertical_layer Metal4   -vertical_width 10   -vertical_spacing 2 \
    -via_rule {{intersection: adjacent} {via_master: via_master_mesh_top}}

set_pg_strategy main_ring_strategy -core -pattern {{pattern: main_ring_pattern} {nets: {VDD VSS}} {offset: {2 2}}}

# ---> COMPILE STEP 1
compile_pg -strategies main_ring_strategy


##############################################################
# 2. IO Ring Connection
##############################################################
create_pg_macro_conn_pattern io_to_ring -pin_conn_type scattered_pin \
    -pin_layers {Metal2} -layers {Metal2 Metal2} -width 9.5

set_pg_strategy s_io_to_ring \
    -macros [get_cells -hierarchical -filter "ref_name =~ gf180mcu_fd_io*"] \
    -pattern {{name: io_to_ring}{nets: {VDD VSS}}}

# Connect the IO to the ring we just built in Step 1
set_pg_strategy_via_rule via_io_to_ring -via_rule { \
    {{{strategies: s_io_to_ring} {layers: {Metal2 Metal5 Metal4}}} \
     {{existing: ring} {layers: {Metal5 Metal4}}} \
     {via_master: {Via3_VV Via4_VV}}} \
}

# ---> COMPILE STEP 2
compile_pg -strategies s_io_to_ring -via_rule via_io_to_ring


##############################################################
# 3. Macro Power Rings (COMPILE FIRST)
##############################################################
# Define the macro variable early so we can use it for both rings and meshes
set all_macros [get_cells -hierarchical -filter "is_hard_macro && !is_physical_only"]

create_pg_ring_pattern macro_ring_pattern -nets {VDD VSS} \
    -horizontal_layer Metal5 -horizontal_width 2 -horizontal_spacing 1 \
    -vertical_layer Metal4   -vertical_width 2   -vertical_spacing 1 \
    -corner_bridge false

set_pg_strategy strategy_macro_ring -macros $all_macros \
    -pattern {{pattern: macro_ring_pattern} {nets: {VDD VSS}} {offset: {1.5 1.5}}}

# ---> COMPILE STEP 3
# We compile the macro rings FIRST so the macro meshes have a physical ring to stop at.
compile_pg -strategies strategy_macro_ring


##############################################################
# 4. Global Power Mesh
##############################################################
create_pg_mesh_pattern mesh_pattern_top -via_rule {{intersection: adjacent} {via_master: via_master_mesh_top}} \
    -layers { \
        {{horizontal_layer: Metal5 } {width: 3} {pitch: 90} {spacing: interleaving} } \
        {{vertical_layer:   Metal4 } {width: 3} {pitch: 90} {spacing: interleaving} } \
}

# Apply global mesh, block macros, and connect to the macro rings
set_pg_strategy mesh_strategy_top -core \
    -pattern {{pattern: mesh_pattern_top} {nets: {VDD VSS}}} \
    -extension {stop: innermost_ring} \
    -blockage {{macros: all}}

set_pg_strategy_via_rule via_mesh_to_ring -via_rule { \
    {{{strategies: mesh_strategy_top}} \
     {{existing: ring} {layers: { Metal5 Metal4 }} } \
     {via_master: via_master_mesh_top}} \
}

# ---> COMPILE STEP 2
compile_pg -strategies mesh_strategy_top -via_rule via_mesh_to_ring


##############################################################
# 5. Macro Scattered Pins Connection
##############################################################
# Added -pin_layers to tell the tool where to look for the SRAM pins
create_pg_macro_conn_pattern macro_pad_conn \
    -pin_conn_type scattered_pin \
    -pin_layers {Metal2 Metal3} \
    -layers {Metal4 Metal5} \
    -width {0.5 0.5}

set_pg_strategy strategy_macro_conn -macros $all_macros \
    -pattern {{name: macro_pad_conn} {nets: {VDD VSS}}}

# Added Via2_VV to the via_master list so it can complete the stack down to M2
set_pg_strategy_via_rule via_pads_to_ring -via_rule { \
    {{{strategies: strategy_macro_conn}} \
     {{existing: ring}} \
     {via_master: {Via2_VV Via3_VV Via4_VV}}} \
}

# ---> COMPILE STEP 5
compile_pg -strategies {strategy_macro_conn} -via_rule via_pads_to_ring

##############################################################
# 6. Std rail
##############################################################
create_pg_std_cell_conn_pattern M1_rail -layers {Metal1}

set_pg_strategy M1_rail_strategy -core -pattern {{name: M1_rail} {nets: VDD VSS}} \
  -blockage {{nets:VDD VSS} {macros_with_keepout: $all_macros}}

set_pg_via_master_rule via_to_stdcells -via_array_dimension {3 1}

# Connect the M1 rails to the M4 mesh straps we built in Step 3
set_pg_strategy_via_rule via_rail_to_mesh -via_rule { \
    {{{strategies: M1_rail_strategy} {layers: Metal1}} \
     {{existing: strap} {layers: Metal4}} \
     {via_master: via_to_stdcells}} \
}

# ---> COMPILE STEP 5
compile_pg -strategies M1_rail_strategy -via_rule via_rail_to_mesh


##############################################################
# Verification
##############################################################
check_pg_missing_vias
check_pg_drc -ignore_std_cells
check_pg_connectivity -check_std_cell_pins none