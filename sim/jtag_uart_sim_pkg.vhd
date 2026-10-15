library ieee;
use ieee.std_logic_1164.all;
package jtag_uart_sim_pkg is
  -- Testbench-only host end of the Intel IP FIFO model. Not in FPGA sources.
  signal host_rx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal host_rx_valid : std_logic := '0';
  signal host_rx_ready : std_logic;
  signal host_tx_data : std_logic_vector(7 downto 0);
  signal host_tx_valid : std_logic;
  signal host_tx_ready : std_logic := '1';
  signal host_stall : std_logic := '0';
end package;
