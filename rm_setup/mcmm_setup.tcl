# mcmm_setup.tcl

# 1. Define the timing scenario (Mode + Corner)
create_mode func
create_corner typical
create_scenario -mode func -corner typical -name func_typical

# 2. Load Constraints (SDC)
# Since we are simple, we will write SDC commands directly here instead of a separate file.

current_scenario func_typical

# Define the clock 'clk' with a period of 10ns (100 MHz)
create_clock -name clk -period 10.0 [get_ports clk]

# Add some input/output delays (good practice)
set_input_delay  1.0 -clock clk [get_ports A]
set_output_delay 1.0 -clock clk [get_ports Z]

# 3. Link Parasitics (TLU+)
# Note: We are skipping read_parasitic_tech for now as we saw no TLU+ in your file list.
# Fusion Compiler will use a default virtual estimator.
