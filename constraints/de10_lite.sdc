# The Intel IP defines the JTAG clock and its internal CDC exceptions.
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
# KEY(0) asserts reset asynchronously; KEY(1) is unused. Internal release stays timed.
set_false_path -from [get_ports {KEY[*]}]

# Dedicated JTAG pins are inserted by Intel IP, outside the VHDL top level.
# Use the 3 ns I/O budget from Intel's JTAG reference example:
# https://www.intel.com/content/www/us/en/developer/articles/technical/intel-cyclone-10-lp-fpga-kit-build-a-custom-hardware-system.html
# TDI/TMS launch on falling TCK; the host samples TDO on rising TCK.
# Explicit -min values extend the example to cover 3 ns of input skew and
# output hold. These are board timing assumptions, not measured delays.
# The IP's existing 10 MHz TCK target is retained for the on-board USB-Blaster.
set_input_delay -clock altera_reserved_tck -clock_fall -max 3.000 \
    [get_ports {altera_reserved_tdi altera_reserved_tms}]
set_input_delay -clock altera_reserved_tck -clock_fall -min -3.000 \
    [get_ports {altera_reserved_tdi altera_reserved_tms}]
set_output_delay -clock altera_reserved_tck -max 3.000 \
    [get_ports {altera_reserved_tdo}]
set_output_delay -clock altera_reserved_tck -min -3.000 \
    [get_ports {altera_reserved_tdo}]

derive_clock_uncertainty
