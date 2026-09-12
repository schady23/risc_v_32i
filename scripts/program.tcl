# Run with: quartus_sh -t scripts/program.tcl [cable-name]
# Programs volatile configuration RAM only; does not modify configuration flash.
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set sof [file join $root_dir build quartus output_files risc_v_32i.sof]

if {[llength $quartus(args)] > 1} {
    error "Usage: quartus_sh -t scripts/program.tcl \"USB-Blaster cable name\""
}
set cable "USB-Blaster"
if {[llength $quartus(args)] == 1} {set cable [lindex $quartus(args) 0]}
if {![file exists $sof]} {
    error "Programming file not found: $sof. Run make build first."
}
set programmer [file join $quartus(binpath) quartus_pgm]
if {[catch {exec $programmer -c $cable -m JTAG -o "p;$sof@1" >@stdout 2>@stderr} result]} {
    error "DE10-Lite configuration failed: $result"
}
puts "Configured DE10-Lite with $sof"
