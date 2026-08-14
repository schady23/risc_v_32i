set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]

if {[llength [get_projects -quiet]] == 0} {
  source [file join $script_dir create_project.tcl]
}

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Synthesis did not complete successfully"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Implementation did not complete successfully"
}

open_run impl_1
set report_dir [file join $root_dir build reports]
file mkdir $report_dir
report_utilization -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]

set worst_path [get_timing_paths -setup -max_paths 1 -nworst 1]
if {[llength $worst_path] == 0} {
  error "No setup timing path was available"
}
set worst_slack [get_property SLACK $worst_path]
if {$worst_slack < 0.0} {
  error "Timing failed: worst setup slack is $worst_slack ns"
}

puts "Bitstream: [file join [get_property DIRECTORY [get_runs impl_1]] basys3_top.bit]"
puts "Timing passed with worst setup slack $worst_slack ns"
