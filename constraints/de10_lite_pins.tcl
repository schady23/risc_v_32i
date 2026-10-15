# Terasic DE10-Lite User Manual, clock and push-button pin assignments.
# https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021&PartNo=4
set_location_assignment PIN_P11 -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50

foreach {port pin} {
    {KEY[0]} B8  {KEY[1]} A7
} {
    set_location_assignment PIN_$pin -to $port
    set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to $port
}
