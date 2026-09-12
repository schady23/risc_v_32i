library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_de10_lite_top is
end entity;

architecture test of tb_de10_lite_top is
  constant CLOCK_PERIOD : time := 20 ns;
  signal clk : std_logic := '0';
  signal keys : std_logic_vector(1 downto 0) := "11";
  signal switches : std_logic_vector(9 downto 0) := (others => '0');
  signal leds : std_logic_vector(9 downto 0);
begin
  clk <= not clk after CLOCK_PERIOD / 2;

  dut : entity work.de10_lite_top
    generic map (HEARTBEAT_BIT => 2)
    port map (
      MAX10_CLK1_50 => clk,
      KEY          => keys,
      SW           => switches,
      LEDR         => leds
    );

  process
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;
  begin
    -- Power-up reset must be asserted even with the button released.
    wait for 1 ns;
    assert leds = "0000000000" report "power-up reset failed" severity failure;
    keys(0) <= '0';
    switches <= "0101010101";
    tick;
    tick;
    assert leds = "0000000000" report "held reset did not clear LEDs" severity failure;

    -- Release away from a clock edge; two rising edges are required.
    wait for 3 ns;
    keys(0) <= '1';
    wait for 1 ns;
    assert leds = "0000000000" report "reset released asynchronously" severity failure;
    tick;
    assert leds = "0000000000" report "reset released after only one edge" severity failure;
    tick;
    assert leds = "0101010101" report "reset release or switch mapping failed" severity failure;

    -- Counter starts on the next edge. Bit 2 rises after four active edges.
    for cycle in 1 to 3 loop
      tick;
      assert leds(9) = '0' report "heartbeat rose too early" severity failure;
    end loop;
    tick;
    assert leds(9) = '1' report "heartbeat did not rise" severity failure;
    for cycle in 1 to 3 loop
      tick;
      assert leds(9) = '1' report "heartbeat fell too early" severity failure;
    end loop;
    tick;
    assert leds(9) = '0' report "heartbeat did not complete a full period" severity failure;

    switches(8 downto 0) <= "001100110";
    wait for 1 ns;
    assert leds(8 downto 0) = "101010101"
      report "asynchronous switch input reached LEDs" severity failure;
    tick;
    assert leds(8 downto 0) = "101010101"
      report "switch path has only one synchronization stage" severity failure;
    tick;
    assert leds(8 downto 0) = "001100110"
      report "synchronized switch update failed" severity failure;

    -- The spare switch and button must not affect the smoke output.
    switches(9) <= '1';
    keys(1) <= '0';
    tick;
    assert leds(8 downto 0) = "001100110"
      report "unused controls changed the LED data or asserted reset" severity failure;
    tick;
    assert leds(9) = '1' report "unused controls disturbed the heartbeat" severity failure;

    -- Assert reset while the clock is low, with the heartbeat high.
    wait until falling_edge(clk);
    wait for 2 ns;
    keys(0) <= '0';
    wait for 1 ns;
    assert leds = "0000000000" report "reset assertion was not asynchronous" severity failure;
    tick;
    tick;
    keys(0) <= '1';
    tick;
    assert leds = "0000000000" report "second reset released too early" severity failure;
    tick;
    assert leds = "0001100110" report "reset did not restart the smoke design" severity failure;
    for cycle in 1 to 3 loop
      tick;
      assert leds(9) = '0' report "reset did not clear heartbeat counter" severity failure;
    end loop;
    tick;
    assert leds(9) = '1' report "heartbeat did not restart after reset" severity failure;

    report "tb_de10_lite_top passed" severity note;
    stop;
    wait;
  end process;

  process
  begin
    wait for 5 us;
    assert false report "tb_de10_lite_top timed out" severity failure;
  end process;
end architecture;
