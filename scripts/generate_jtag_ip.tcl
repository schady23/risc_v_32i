# Sourced by quartus_sh before project creation. No generated IP is committed.
proc jtag_find_tool {root name} {
    foreach dir [list [file join $root sopc_builder bin] [file join $root bin64] [file join $root bin]] {
        foreach ext {.exe .bat {}} {
            set candidate [file join $dir $name$ext]
            if {[file exists $candidate]} {return $candidate}
        }
    }
    error "Missing $name under $root; install Quartus Platform Designer support"
}
proc jtag_run {tool args} {
    if {[string equal -nocase [file extension $tool] .bat]} {
        exec cmd.exe /c $tool {*}$args >@stdout 2>@stderr
    } else {exec $tool {*}$args >@stdout 2>@stderr}
}
set jtag_root [file dirname [file normalize $quartus(binpath)]]
set jtag_qsys_script [jtag_find_tool $jtag_root qsys-script]
set jtag_qsys_generate [jtag_find_tool $jtag_root qsys-generate]
jtag_run $jtag_qsys_script --script=[file join $root_dir scripts create_jtag_uart.tcl]
jtag_run $jtag_qsys_generate [file join $root_dir build ip jtag_uart_system.qsys] \
    --synthesis=VHDL --output-directory=[file join $root_dir build ip jtag_uart_system]
set jtag_qip [file join $root_dir build ip jtag_uart_system synthesis jtag_uart_system.qip]
if {![file exists $jtag_qip]} {error "JTAG UART generation did not produce $jtag_qip"}
