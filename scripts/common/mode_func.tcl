current_mode func

create_clock -name clock      -period $CLOCK_PERIOD    [get_port $CLOCK_PORT_NAME]

set_input_delay  -mode func -clock clock [expr 0.1*$CLOCK_PERIOD] [all_inputs -exclude_clock_ports]
set_output_delay -mode func -clock clock [expr 0.1*$CLOCK_PERIOD] [all_outputs]

set_clock_uncertainty -mode func -setup 1.0 [get_clocks clock]
set_clock_uncertainty -mode func -hold  0.5 [get_clocks clock]

