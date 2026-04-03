# parasitic_setup.tcl

# 1. Define Paths
set map_file  "/home1/usuario21/sky130/tech/star_rcxt/skywater130.mw2itf.map"
set tlu_file  "/home1/usuario21/sky130/tech/star_rcxt/skywater130.nominal.tluplus"

# setup de corners
read_parasitic_tech -tlup ${tlu_file} -layermap ${map_file} -name typTLU

create_corner typical

set_temperature 25 -corner typical
set_voltage 1.8 -corner typical

set_voltage 1.8 -object_list [get_supply_nets VDD] -corner typical
set_voltage 0.0 -object_list [get_supply_nets VSS] -corner typical

create_mode func
create_scenario -mode func -corner typical -name func_typical

set_parasitic_parameters -corner typical -early_spec typTLU -late_spec typTLU

set_scenario_status -all -setup true -hold true -dynamic_power true -leakage_power true -max_capacitance true -max_transition true -cell_em false -signal_em false -ir_drop true {func_typical}
current_mode func
