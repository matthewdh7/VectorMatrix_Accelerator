# constraints.tcl
#
# This file is where design timing constraints are defined for Genus and Innovus.
# Many constraints can be written directly into the Hammer config files. However, 
# you may manually define constraints here as well.
#

create_clock -name clk -period 10.0 [get_ports clk_i]
set_clock_uncertainty 0.100 [get_clocks clk]
