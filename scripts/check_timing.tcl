# Run after compilation: quartus_sta -t scripts/check_timing.tcl
package require ::quartus::project
package require ::quartus::report
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $root_dir build quartus]
set report_dir [file join $root_dir build reports]
file mkdir $report_dir
cd $project_dir
project_open risc_v_32i
load_report
create_timing_netlist
read_sdc
update_timing_netlist

set summary [open [file join $report_dir timing_summary.rpt] w]
set failed 0
set setup_count 0
foreach_in_collection op [get_available_operating_conditions] {
    set_operating_conditions $op
    update_timing_netlist
    set corner [get_operating_conditions_info $op -display_name]
    regsub -all {[^A-Za-z0-9_-]} $corner _ tag
    puts $summary "Operating conditions: $corner"
    foreach analysis {setup hold recovery removal} {
        set paths [get_timing_paths -$analysis -npaths 1]
        set count 0
        foreach_in_collection path $paths {
            incr count
            if {$analysis eq "setup"} {incr setup_count}
            set slack [get_path_info $path -slack]
            puts $summary "  $analysis worst slack: $slack ns"
            puts "$corner / $analysis: $slack ns"
            if {$slack < 0.0} {set failed 1}
        }
        if {$count == 0} {puts $summary "  $analysis: no applicable paths"}
        report_timing -$analysis -npaths 10 -detail full_path \
            -file [file join $report_dir ${tag}_${analysis}.rpt]
    }
}
check_timing -include {no_clock multiple_clock loops latches uncertainty} \
    -panel_name {RV32I Constraint Checks} -file [file join $report_dir constraint_checks.rpt]
report_ucp -panel_name {RV32I Unconstrained Paths} \
    -file [file join $report_dir unconstrained_paths.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
report_metastability -file [file join $report_dir metastability.rpt]

# Inspect the freshly generated panels, not cached compilation results.
foreach {suffix expected_rows} {
    {RV32I Constraint Checks||Summary} 5
    {RV32I Unconstrained Paths||Unconstrained Paths Summary} 6
} {
    set id -1
    foreach panel [get_report_panel_names] {
        if {[string match "*||$suffix" $panel]} {set id [get_report_panel_id $panel]}
    }
    if {$id < 0 || [get_number_of_rows -id $id] != $expected_rows + 1} {
        error "Missing or unexpected timing-check report: $suffix"
    }
    for {set row 1} {$row <= $expected_rows} {incr row} {
        set values [get_report_panel_row -id $id -row $row]
        foreach count [lrange $values 1 end] {
            if {![string is integer -strict $count] || $count != 0} {
                puts $summary "Constraint failure: $values"
                set failed 1
            }
        }
    }
}
close $summary
delete_timing_netlist
unload_report
project_close

if {$setup_count == 0} {error "No constrained setup paths were found"}
if {$failed} {error "Timing violations found; see $report_dir"}
puts "Timing checks passed; reports: $report_dir"
