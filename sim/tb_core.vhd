library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_core is
end entity;

architecture test of tb_core is
  signal clk, reset : std_logic := '0';
  signal i_req, i_fault : std_logic;
  signal i_addr, i_rdata : word_t;
  signal d_req, d_write, d_fault : std_logic;
  signal d_addr, d_wdata, d_rdata : word_t;
  signal d_be : byte_enable_t;
  signal halted, trap_valid, retire_valid, retire_rd_we : std_logic;
  signal trap_cause : trap_cause_t;
  signal trap_pc, trap_tval, retire_pc, retire_instr, retire_rd_data : word_t;
  signal retire_rd : reg_index_t;
  signal leds : std_logic_vector(15 downto 0);
begin
  clk <= not clk after 5 ns;

  cpu : entity work.rv32i_core
    port map (
      clk_i => clk, reset_i => reset,
      i_req_o => i_req, i_addr_o => i_addr, i_rdata_i => i_rdata, i_fault_i => i_fault,
      d_req_o => d_req, d_write_o => d_write, d_addr_o => d_addr,
      d_wdata_o => d_wdata, d_be_o => d_be, d_rdata_i => d_rdata, d_fault_i => d_fault,
      halted_o => halted, trap_valid_o => trap_valid, trap_cause_o => trap_cause,
      trap_pc_o => trap_pc, trap_tval_o => trap_tval,
      retire_valid_o => retire_valid, retire_pc_o => retire_pc,
      retire_instr_o => retire_instr, retire_rd_we_o => retire_rd_we,
      retire_rd_o => retire_rd, retire_rd_data_o => retire_rd_data
    );

  bus_system : entity work.memory_bus
    port map (
      clk_i => clk, reset_i => reset,
      i_req_i => i_req, i_addr_i => i_addr, i_rdata_o => i_rdata, i_fault_o => i_fault,
      d_req_i => d_req, d_write_i => d_write, d_addr_i => d_addr,
      d_wdata_i => d_wdata, d_be_i => d_be, d_rdata_o => d_rdata, d_fault_o => d_fault,
      switches_i => (others => '0'), status_i => (others => '0'), leds_o => leds
    );

  process
    procedure check_retirement(constant expected_pc : word_t;
                               constant expected_instr : word_t;
                               constant expected_we : std_logic;
                               constant expected_rd : reg_index_t;
                               constant expected_data : word_t) is
    begin
      for cycle in 1 to 12 loop
        wait until rising_edge(clk);
        if retire_valid = '1' then
          assert retire_pc = expected_pc and retire_instr = expected_instr
            report "wrong instruction retired" severity failure;
          assert retire_rd_we = expected_we
            report "wrong destination write enable" severity failure;
          if expected_we = '1' then
            assert retire_rd = expected_rd and retire_rd_data = expected_data
              report "wrong destination or result" severity failure;
          end if;
          return;
        end if;
      end loop;
      assert false report "core did not retire before timeout" severity failure;
    end procedure;
  begin
    reset <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    reset <= '0';
    check_retirement(x"00000000", x"400002B7", '1', "00101", x"40000000");
    check_retirement(x"00000004", x"15500313", '1', "00110", x"00000155");
    check_retirement(x"00000008", x"0062A023", '0', "00000", (others => '0'));
    assert leds(9 downto 0) = "0101010101"
      report "store did not reach LED GPIO" severity failure;
    check_retirement(x"0000000C", x"0000006F", '0', "00000", (others => '0'));
    check_retirement(x"0000000C", x"0000006F", '0', "00000", (others => '0'));
    assert halted = '0' and trap_valid = '0'
      report "demo unexpectedly trapped" severity failure;

    reset <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert leds = x"0000" report "reset did not clear LEDs" severity failure;
    reset <= '0';
    check_retirement(x"00000000", x"400002B7", '1', "00101", x"40000000");
    report "tb_core passed" severity note;
    stop;
    wait;
  end process;
end architecture;
