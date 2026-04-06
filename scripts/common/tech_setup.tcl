# -----------------------------------------------------------------------------
# This file was created at the Institute of Microelectronic Systems,
# Leibniz University Hannover. It is provided "as is" without
# warranty of any kind, express or implied, including but not
# limited to correctness or fitness for a particular purpose.
#
# Author: Viktor Schneider
# -----------------------------------------------------------------------------

# This file is loaded after elaboration to setup technology dependent parameters
read_parasitic_tech -layermap ${LPE_LAYERMAP} -tlup ${LPE_NXTGRD} -name ${LPE_SPEC}

# Set routing directions for each metal layer
set_attribute [get_layers {Metal1 Metal3 Metal5 }] routing_direction horizontal
set_attribute [get_layers {Metal2 Metal4        }] routing_direction vertical

# This is require for to align the routing tracks with the pins of the 7T cells
set_attribute [get_layers -filter "mask_name =~ metal*"] track_offset 0.28

# Since no information about the diode protection capability is give, we assume unlimited protection capabilities
# Use diode_mode=2, due to the DRC tool checking also the top layer for antenna violations
define_antenna_rule -mode 4 -diode_mode 2 -metal_ratio 400 -cut_ratio 20

# to perform antenna analysis on port nets
set_app_options -name route.detail.default_port_external_gate_size -value 0.0
