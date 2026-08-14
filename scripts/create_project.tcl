set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $root_dir build vivado]

file mkdir $project_dir
create_project -force risc_v_32i [file join $project_dir risc_v_32i] -part xc7a35tcpg236-1
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]

set rtl_sources [list \
  [file join $root_dir rtl pkg rv32i_pkg.vhd] \
  [file join $root_dir rtl pkg memory_map_pkg.vhd] \
  [file join $root_dir rtl memory program_image_pkg.vhd] \
  [file join $root_dir rtl core rv32i_alu.vhd] \
  [file join $root_dir rtl core rv32i_regfile.vhd] \
  [file join $root_dir rtl core rv32i_decoder.vhd] \
  [file join $root_dir rtl core rv32i_core.vhd] \
  [file join $root_dir rtl memory instruction_rom.vhd] \
  [file join $root_dir rtl memory data_ram.vhd] \
  [file join $root_dir rtl peripheral gpio.vhd] \
  [file join $root_dir rtl interconnect memory_bus.vhd] \
  [file join $root_dir rtl board reset_synchronizer.vhd] \
  [file join $root_dir rtl board basys3_top.vhd] \
]

set simulation_sources [list \
  [file join $root_dir sim tb_alu.vhd] \
  [file join $root_dir sim tb_regfile.vhd] \
  [file join $root_dir sim tb_memory_bus.vhd] \
  [file join $root_dir sim tb_core.vhd] \
  [file join $root_dir sim tb_basys3_top.vhd] \
]

add_files -norecurse $rtl_sources
set_property file_type {VHDL 2008} [get_files $rtl_sources]
add_files -fileset sim_1 -norecurse $simulation_sources
set_property file_type {VHDL 2008} [get_files $simulation_sources]
add_files -fileset constrs_1 -norecurse [file join $root_dir constraints basys3.xdc]

set_property top basys3_top [get_filesets sources_1]
set_property top tb_alu [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created project at [file join $project_dir risc_v_32i]"
