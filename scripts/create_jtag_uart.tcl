# Run by qsys-script. Let the installed Quartus choose its matching IP version.
package require qsys
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $root build ip]
create_system jtag_uart_system
set_project_property DEVICE_FAMILY "MAX 10"
set_project_property DEVICE 10M50DAF484C7G
add_instance jtag_uart altera_avalon_jtag_uart
set_instance_parameter_value jtag_uart allowMultipleConnections 0
set_instance_parameter_value jtag_uart readBufferDepth 64
set_instance_parameter_value jtag_uart writeBufferDepth 64
set_instance_parameter_value jtag_uart simInteractiveOptions NO_INTERACTIVE_WINDOWS
add_interface clk clock sink
set_interface_property clk EXPORT_OF jtag_uart.clk
add_interface reset reset sink
set_interface_property reset EXPORT_OF jtag_uart.reset
add_interface av avalon slave
set_interface_property av EXPORT_OF jtag_uart.avalon_jtag_slave
save_system [file join $root build ip jtag_uart_system.qsys]
