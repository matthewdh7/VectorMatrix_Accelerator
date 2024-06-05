# constraints.tcl
#
# This file is where design timing constraints are defined for Genus and Innovus.
# Many constraints can be written directly into the Hammer config files. However, 
# you may manually define constraints here as well.
#

# TODO: add constraints here!
create_clock -name clk -period 10 [get_ports clk_i]
set_clock_uncertainty 0.100 [get_clocks clk_i]

# Always set the input/output delay as half periods for clock setup checks
set_input_delay  5 -max -clock [get_clocks clk_i] [all_inputs]
set_output_delay 5 -max -clock [get_clocks clk_i] [all_outputs] 
#[remove_from_collection [all_outputs] [get_ports clk_o]]

# Always set the input/output delay as 0 for clock hold checks
set_input_delay  0.0 -min -clock [get_clocks clk_i] [all_inputs]
set_output_delay 0.0 -min -clock [get_clocks clk_i] [all_outputs]
#[remove_from_collection [all_outputs] [get_ports clk_o]]
