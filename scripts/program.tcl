set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set bitstream [file join $root_dir build vivado risc_v_32i risc_v_32i.runs impl_1 basys3_top.bit]

if {![file exists $bitstream]} {
  error "Bitstream not found: $bitstream"
}

open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices xc7a35t_0] 0]
if {$device eq ""} {
  error "Basys 3 FPGA xc7a35t_0 was not found"
}

current_hw_device $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
puts "Programmed $device with $bitstream"
