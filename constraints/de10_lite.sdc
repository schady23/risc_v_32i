# The JTAG IP's generated constraints define its TCK/CDC paths.
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty
# KEY(0) asserts reset asynchronously; KEY(1) is unused. Internal release stays timed.
set_false_path -from [get_ports {KEY[*]}]
