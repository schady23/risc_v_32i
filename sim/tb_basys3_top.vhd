library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_basys3_top is
end entity;

architecture test of tb_basys3_top is
  signal clk  : std_logic := '0';
  signal btnC : std_logic := '1';
  signal sw   : std_logic_vector(15 downto 0) := (others => '0');
  signal led  : std_logic_vector(15 downto 0);
begin
  clk <= not clk after 5 ns;

  dut : entity work.basys3_top
    port map (
      clk  => clk,
      btnC => btnC,
      sw   => sw,
      led  => led
    );

  process
  begin
    wait for 20 ns;
    assert led = x"0000" report "reset did not clear LEDs" severity failure;

    btnC <= '0';
    sw <= x"1234";
    wait for 30 ns;
    assert led(14 downto 0) = sw(14 downto 0)
      report "switch-to-LED smoke path failed" severity failure;

    report "tb_basys3_top passed" severity note;
    stop;
    wait;
  end process;
end architecture;
