library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_memory_bus is
end entity;

architecture test of tb_memory_bus is
  signal clk, reset : std_logic := '0';
  signal i_req, i_fault : std_logic := '0';
  signal i_addr, i_rdata : word_t := (others => '0');
  signal d_req, d_write, d_fault : std_logic := '0';
  signal d_addr, d_wdata, d_rdata, status : word_t := (others => '0');
  signal d_be : byte_enable_t := (others => '0');
  signal switches, leds : std_logic_vector(15 downto 0) := (others => '0');
begin
  clk <= not clk after 5 ns;

  dut : entity work.memory_bus
    port map (
      clk_i      => clk,
      reset_i    => reset,
      i_req_i    => i_req,
      i_addr_i   => i_addr,
      i_rdata_o  => i_rdata,
      i_fault_o  => i_fault,
      d_req_i    => d_req,
      d_write_i  => d_write,
      d_addr_i   => d_addr,
      d_wdata_i  => d_wdata,
      d_be_i     => d_be,
      d_rdata_o  => d_rdata,
      d_fault_o  => d_fault,
      switches_i => switches,
      status_i   => status,
      leds_o     => leds
    );

  process
  begin
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    d_addr <= x"DEADBEEF";
    d_be <= "1111";
    d_req <= '1';
    wait until rising_edge(clk);
    d_req <= '0';
    wait for 1 ns;
    assert d_fault = '1' report "unmapped access did not fault" severity failure;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert d_fault = '0' report "fault response lasted more than one cycle" severity failure;

    report "tb_memory_bus passed" severity note;
    stop;
    wait;
  end process;
end architecture;
