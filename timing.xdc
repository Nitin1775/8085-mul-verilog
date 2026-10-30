# timing.xdc - 10 ns clock constraint for top_8085
# Used for the paper's Fmax estimate: Fmax = 1000 / (10 - WNS) MHz
# Add this file to constrs_1 in Vivado (not to sources_1).
create_clock -period 10.000 -name sys_clk [get_ports clk]
