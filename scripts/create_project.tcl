# Run with: quartus_sh -t scripts/create_project.tcl
package require ::quartus::project

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $root_dir build quartus]
set project_name risc_v_32i

if {[is_project_open]} {
    error "Close the current project before generating the DE10-Lite project"
}
file mkdir $project_dir
# This is a generated project. Tracked sources/constraints are authoritative.
project_new [file join $project_dir $project_name] -overwrite
set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_top
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS 4
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name OPTIMIZE_FOR_METASTABILITY ON

foreach source {
    rtl/pkg/rv32i_pkg.vhd
    rtl/pkg/memory_map_pkg.vhd
    rtl/memory/program_image_pkg.vhd
    rtl/core/rv32i_alu.vhd
    rtl/core/rv32i_regfile.vhd
    rtl/core/rv32i_decoder.vhd
    rtl/core/rv32i_core.vhd
    rtl/memory/instruction_rom.vhd
    rtl/memory/data_ram.vhd
    rtl/peripheral/gpio.vhd
    rtl/interconnect/memory_bus.vhd
    rtl/board/reset_synchronizer.vhd
    rtl/board/de10_lite_top.vhd
} {
    set_global_assignment -name VHDL_FILE [file join $root_dir $source]
}
set_global_assignment -name SDC_FILE [file join $root_dir constraints de10_lite.sdc]
source [file join $root_dir constraints de10_lite_pins.tcl]
export_assignments
project_close
puts "Created [file join $project_dir $project_name.qpf]"
