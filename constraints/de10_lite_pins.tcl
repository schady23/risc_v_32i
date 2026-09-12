# Terasic DE10-Lite User Manual, tables 3-2 through 3-5.
# https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021&PartNo=4
set_location_assignment PIN_P11 -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50

foreach {port pin} {
    {KEY[0]} B8  {KEY[1]} A7
} {
    set_location_assignment PIN_$pin -to $port
    set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to $port
}

foreach {port pin} {
    {SW[0]} C10  {SW[1]} C11  {SW[2]} D12  {SW[3]} C12  {SW[4]} A12
    {SW[5]} B12  {SW[6]} A13  {SW[7]} A14  {SW[8]} B14  {SW[9]} F15
    {LEDR[0]} A8  {LEDR[1]} A9  {LEDR[2]} A10  {LEDR[3]} B10  {LEDR[4]} D13
    {LEDR[5]} C13  {LEDR[6]} E14  {LEDR[7]} D14  {LEDR[8]} A11  {LEDR[9]} B11
} {
    set_location_assignment PIN_$pin -to $port
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $port
}

# Explicit moderate LED drive strength (the board includes series resistors).
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to {LEDR[*]}
