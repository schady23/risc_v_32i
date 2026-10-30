# Run by qsys-script. Let the installed Quartus choose its matching IP version.
package require qsys
# qsys-script uses a limited Tcl interpreter without `file normalize`.
# Resolve relative script paths against qsys-script's working directory.
set root [file join [pwd] [file dirname [file dirname [info script]]]]
file mkdir [file join $root build ip]
create_system jtag_uart_system
set_project_property DEVICE_FAMILY "MAX 10"
set_project_property DEVICE 10M50DAF484C7G
# A direct clock bridge records the board frequency for IP validation.
# It passes through the external clock without a PLL or clock divider.
add_instance clock altera_clock_bridge
set_instance_parameter_value clock EXPLICIT_CLOCK_RATE 50000000
add_instance jtag_uart altera_avalon_jtag_uart
set_instance_parameter_value jtag_uart allowMultipleConnections 0
set_instance_parameter_value jtag_uart readBufferDepth 64
set_instance_parameter_value jtag_uart writeBufferDepth 64
set_instance_parameter_value jtag_uart simInteractiveOptions NO_INTERACTIVE_WINDOWS
add_connection clock.out_clk jtag_uart.clk
add_interface clk clock sink
set_interface_property clk EXPORT_OF clock.in_clk
add_interface reset reset sink
set_interface_property reset EXPORT_OF jtag_uart.reset
add_interface av avalon slave
set_interface_property av EXPORT_OF jtag_uart.avalon_jtag_slave
save_system [file join $root build ip jtag_uart_system.qsys]
