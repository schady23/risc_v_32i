library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_regfile is
end entity;

architecture test of tb_regfile is
  signal clk, reset, rd_we : std_logic := '0';
  signal rs1_addr, rs2_addr, rd_addr : reg_index_t := (others => '0');
  signal rs1_data, rs2_data, rd_data : word_t := (others => '0');
begin
  clk <= not clk after 5 ns;

  dut : entity work.rv32i_regfile
    port map (
      clk_i      => clk,
      reset_i    => reset,
      rs1_addr_i => rs1_addr,
      rs2_addr_i => rs2_addr,
      rs1_data_o => rs1_data,
      rs2_data_o => rs2_data,
      rd_we_i    => rd_we,
      rd_addr_i  => rd_addr,
      rd_data_i  => rd_data
    );

  process
  begin
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    rd_we <= '1';
    rd_addr <= "00101";
    rd_data <= x"12345678";
    wait until rising_edge(clk);
    rd_we <= '0';
    rs1_addr <= "00101";
    wait for 1 ns;
    assert rs1_data = x"12345678" report "x5 write/read failed" severity failure;

    rd_we <= '1';
    rd_addr <= "00000";
    rd_data <= x"FFFFFFFF";
    wait until rising_edge(clk);
    rd_we <= '0';
    rs1_addr <= "00000";
    wait for 1 ns;
    assert rs1_data = x"00000000" report "x0 accepted a write" severity failure;

    report "tb_regfile passed" severity note;
    stop;
    wait;
  end process;
end architecture;
