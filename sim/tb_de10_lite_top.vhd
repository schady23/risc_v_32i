library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_de10_lite_top is
end entity;

architecture test of tb_de10_lite_top is
  signal clk : std_logic := '0';
  signal keys : std_logic_vector(1 downto 0) := "11";
  signal switches : std_logic_vector(9 downto 0) := (others => '0');
  signal leds : std_logic_vector(9 downto 0);
begin
  clk <= not clk after 10 ns;

  dut : entity work.de10_lite_top
    port map (MAX10_CLK1_50 => clk, KEY => keys, SW => switches, LEDR => leds);

  process
    procedure wait_for_demo is
    begin
      for cycle in 1 to 40 loop
        wait until rising_edge(clk);
        wait for 1 ns;
        if leds = "0101010101" then return; end if;
      end loop;
      assert false report "CPU program did not write LED pattern" severity failure;
    end procedure;
  begin
    keys(0) <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert leds = "0000000000" report "reset did not clear GPIO" severity failure;
    keys(0) <= '1';
    wait_for_demo;

    wait until falling_edge(clk);
    keys(0) <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert leds = "0000000000" report "button reset did not clear LEDs" severity failure;
    keys(0) <= '1';
    wait_for_demo;
    report "tb_de10_lite_top passed" severity note;
    stop;
    wait;
  end process;
end architecture;
