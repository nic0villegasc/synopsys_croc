# floorplan.tcl
# Initialize a rectangular chip with 50% utilization (plenty of space for an inverter)
# and 5 micron margins on all sides.

initialize_floorplan \
    -control_type core \
    -boundary {{0 0} {40 40}} \
    -core_offset {5.0 5.0 5.0 5.0}

# Create Power and Ground inputs (Ports)
create_port {VDD VSS} -direction inout

# Connect them logically
connect_pg_net -automatic
