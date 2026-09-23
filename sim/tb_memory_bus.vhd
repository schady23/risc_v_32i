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
      clk_i => clk, reset_i => reset,
      i_req_i => i_req, i_addr_i => i_addr, i_rdata_o => i_rdata, i_fault_o => i_fault,
      d_req_i => d_req, d_write_i => d_write, d_addr_i => d_addr,
      d_wdata_i => d_wdata, d_be_i => d_be, d_rdata_o => d_rdata, d_fault_o => d_fault,
      switches_i => switches, status_i => status, leds_o => leds
    );

  process
    procedure access_bus(constant address : word_t;
                         constant write_enable : std_logic;
                         constant write_data : word_t;
                         constant lanes : byte_enable_t;
                         constant expected_fault : std_logic;
                         constant expected_data : word_t;
                         constant check_data : boolean := true) is
    begin
      d_addr <= address;
      d_write <= write_enable;
      d_wdata <= write_data;
      d_be <= lanes;
      d_req <= '1';
      wait until rising_edge(clk);
      d_req <= '0';
      wait for 1 ns;
      assert d_fault = expected_fault report "wrong data fault response" severity failure;
      if check_data and expected_fault = '0' then
        assert d_rdata = expected_data report "wrong data response" severity failure;
      end if;
      wait until rising_edge(clk);
      wait for 1 ns;
      assert d_fault = '0' report "data response lasted too long" severity failure;
    end procedure;
  begin
    reset <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    reset <= '0';

    i_addr <= x"00000000";
    i_req <= '1';
    wait until rising_edge(clk);
    i_req <= '0';
    wait for 1 ns;
    assert i_fault = '0' and i_rdata = x"400002B7"
      report "ROM instruction fetch failed" severity failure;
    i_addr <= x"00004000";
    i_req <= '1';
    wait until rising_edge(clk);
    i_req <= '0';
    wait for 1 ns;
    assert i_fault = '1' report "out-of-ROM fetch did not fault" severity failure;

    access_bus(x"00000004", '0', (others => '0'), "1111", '0', x"15500313");
    access_bus(x"00000004", '1', x"FFFFFFFF", "1111", '1', (others => '0'));
    access_bus(x"00000004", '0', (others => '0'), "1111", '0', x"15500313");

    access_bus(x"00010000", '1', x"11223344", "1111", '0', (others => '0'), false);
    access_bus(x"00010000", '0', (others => '0'), "1111", '0', x"11223344");
    access_bus(x"00010001", '1', x"0000AA00", "0010", '0', (others => '0'), false);
    access_bus(x"00010000", '0', (others => '0'), "1111", '0', x"1122AA44");
    access_bus(x"00013FFC", '1', x"55667788", "1111", '0', (others => '0'), false);
    access_bus(x"00013FFC", '0', (others => '0'), "1111", '0', x"55667788");

    access_bus(x"40000000", '1', x"00000155", "1111", '0', (others => '0'), false);
    assert leds = x"0155" report "GPIO LED write failed" severity failure;
    access_bus(x"40000000", '1', x"FFFFFFFF", "0001", '1', (others => '0'));
    assert leds = x"0155" report "rejected GPIO write changed LEDs" severity failure;
    access_bus(x"40000000", '0', (others => '0'), "1111", '0', x"00000155");
    switches <= x"02A5";
    status <= x"12345678";
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    access_bus(x"40000004", '0', (others => '0'), "1111", '0', x"000002A5");
    access_bus(x"40000008", '0', (others => '0'), "1111", '0', x"12345678");
    access_bus(x"40000004", '1', x"FFFFFFFF", "1111", '1', (others => '0'));
    access_bus(x"40000008", '1', x"FFFFFFFF", "1111", '1', (others => '0'));
    access_bus(x"DEADBEEF", '0', (others => '0'), "1111", '1', (others => '0'));

    report "tb_memory_bus passed" severity note;
    stop;
    wait;
  end process;
end architecture;
