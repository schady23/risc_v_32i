# Run with: quartus_sh -t scripts/build.tcl
package require ::quartus::flow
source [file join [file dirname [file normalize [info script]]] create_project.tcl]

# Keep compilation databases and reports under the ignored build directory.
cd $project_dir
project_open $project_name
if {[catch {execute_flow -compile} result]} {
    project_close
    error "Quartus compilation failed: $result"
}
project_close

set report_dir [file join $root_dir build reports]
file mkdir $report_dir
file copy -force [file join $project_dir output_files $project_name.fit.summary] \
    [file join $report_dir utilization.rpt]

# Quartus compilation alone does not turn every timing violation into an error.
# Explicitly check timing before declaring the programming file ready.
set sta [file join $quartus(binpath) quartus_sta]
if {[catch {exec $sta -t [file join $script_dir check_timing.tcl] >@stdout 2>@stderr} result]} {
    error "Timing validation failed: $result"
}
set sof [file join $project_dir output_files $project_name.sof]
if {![file exists $sof]} {
    error "Quartus did not generate the expected programming file: $sof"
}
puts "Programming file: $sof"
