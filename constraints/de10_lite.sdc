# Single 50 MHz board clock; no PLL or fabric-generated clocks.
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty

# Human-operated inputs have no synchronous external timing relationship.
# SW only feeds the first synchronizer stage. KEY[0] only asserts the reset
# synchronizer asynchronously; KEY[1] is unused. These exceptions start at
# the pins and do not cut timing between internal synchronization stages.
set_false_path -from [get_ports {SW[*] KEY[*]}]

# LEDs are human-observed outputs, with no external capture clock.
set_false_path -to [get_ports {LEDR[*]}]
