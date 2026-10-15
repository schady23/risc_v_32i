library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
use work.rv32i_pkg.all;

-- Report 4 Goal 3. Real core/register file and real RAM/bus; a small independent
-- instruction ROM makes reset timing independent of the loader firmware.
entity tb_core_reset is
end entity;

architecture test of tb_core_reset is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal i_req, i_fault : std_logic := '0';
  signal i_addr, i_rdata : word_t := (others => '0');
  signal d_req, d_write, d_fault : std_logic;
  signal d_addr, d_wdata, d_rdata : word_t;
  signal d_be : byte_enable_t;
  signal halted, trap_valid, retire_valid, retire_rd_we : std_logic;
  signal trap_cause : trap_cause_t;
  signal trap_pc, trap_tval, retire_pc, retire_instr, retire_rd_data : word_t;
  signal retire_rd : reg_index_t;
  signal phase : natural := 0;
  signal accepted_stores, retire_count : natural := 0;
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
      retire_rd_o => retire_rd, retire_rd_data_o => retire_rd_data);
  bus_system : entity work.memory_bus
    port map (
      clk_i => clk, reset_i => reset,
      i_req_i => '0', i_addr_i => (others => '0'), i_rdata_o => open, i_fault_o => open,
      d_req_i => d_req, d_write_i => d_write, d_addr_i => d_addr,
      d_wdata_i => d_wdata, d_be_i => d_be, d_rdata_o => d_rdata, d_fault_o => d_fault,
      av_address_o => open, av_read_o => open, av_write_o => open,
      av_writedata_o => open, av_readdata_i => x"00400000", av_waitrequest_i => '0');

  process(clk)
  begin
    if rising_edge(clk) then
      i_fault <= '0';
      if i_req = '1' then
        case i_addr is
          when x"00000000" => i_rdata <= x"000102B7"; -- LUI x5,0x10
          when x"00000004" => i_rdata <= x"0002A403"; -- LW x8,0(x5)
          when x"00000008" => i_rdata <= x"00130393"; -- ADDI x7,x6,1
          when x"0000000C" => i_rdata <= x"05500313"; -- ADDI x6,x0,0x55
          when x"00000010" => i_rdata <= x"0062A023"; -- SW x6,0(x5)
          when x"00000014" => i_rdata <= x"07700493"; -- ADDI x9,x0,0x77
          when x"00000018" => i_rdata <= x"0000006F"; -- JAL x0,0
          when others => i_fault <= '1';
        end case;
      end if;
      if reset = '1' then
        assert i_req = '0' and d_req = '0' and d_write = '0' and
               retire_valid = '0' and retire_rd_we = '0'
          report "reset allowed a request, writeback, or retirement" severity failure;
      end if;
      if d_req = '1' and d_write = '1' then
        assert reset = '0' and d_addr = x"00010000" and
               d_wdata = x"00000055" and d_be = "1111"
          report "unexpected accepted store" severity failure;
        accepted_stores <= accepted_stores + 1;
      end if;
      if retire_valid = '1' then retire_count <= retire_count + 1; end if;
      assert halted = '0' and trap_valid = '0'
        report "reset program unexpectedly trapped" severity failure;
    end if;
  end process;

  process
    procedure retirement(pc : word_t; writes : std_logic; dest : reg_index_t;
                         value : word_t := x"00000000") is
    begin
      loop
        wait until rising_edge(clk);
        exit when retire_valid = '1';
      end loop;
      assert retire_pc = pc and retire_rd_we = writes
        report "unexpected retirement PC/write enable" severity failure;
      if writes = '1' then
        assert retire_rd = dest and retire_rd_data = value
          report "wrong register result after reset" severity failure;
      end if;
    end procedure;
    procedure restart(expected_stores : natural) is
      variable count_before : natural;
    begin
      -- Called on a falling edge, away from acceptance/commit edges.
      count_before := retire_count;
      reset <= '1';
      wait for 1 ns;
      assert i_req = '0' and d_req = '0' and d_write = '0' and
             retire_valid = '0' and retire_rd_we = '0'
        report "reset gating failed before next clock edge" severity failure;
      for cycle in 1 to 2 loop
        wait until rising_edge(clk);
        wait for 1 ns;
        assert i_addr = x"00000000" and accepted_stores = expected_stores and
               retire_count = count_before
          report "reset PC/side-effect check failed" severity failure;
      end loop;
      wait until falling_edge(clk);
      reset <= '0';
      wait for 1 ns;
      assert i_req = '1' and i_addr = x"00000000"
        report "first fetch after reset was not address zero" severity failure;
      retirement(x"00000000", '1', "00101", x"00010000");
      if expected_stores = 0 then
        retirement(x"00000004", '1', "01000", x"00000000");
      else
        retirement(x"00000004", '1', "01000", x"00000055");
      end if;
      -- x6 was 0x55 before each injected reset. A result of 1 proves that
      -- reset cleared the register file, rather than merely hiding rd_we.
      retirement(x"00000008", '1', "00111", x"00000001");
      retirement(x"0000000C", '1', "00110", x"00000055");
    end procedure;
  begin
    wait until falling_edge(clk);
    phase <= 1;
    restart(0);
    wait until d_req = '1' and d_write = '1';
    wait until falling_edge(clk);
    assert accepted_stores = 0 report "store already accepted before cancellation" severity failure;
    phase <= 2;
    restart(0);
    report "pre-acceptance store canceled; RAM unchanged; register file cleared";

    wait until d_req = '1' and d_write = '1';
    wait until rising_edge(clk); -- The real RAM commits here.
    wait for 1 ns;
    assert accepted_stores = 1 report "store acceptance missing" severity failure;
    wait until falling_edge(clk); -- MEM_WRITE_WAIT, before retirement.
    phase <= 3;
    restart(1);
    report "accepted store preserved across reset; restart load returned 0x55";

    retirement(x"00000010", '0', "00000");
    wait until retire_valid = '1' and retire_pc = x"00000014";
    wait until falling_edge(clk); -- Pending ADDI write, before its commit edge.
    assert retire_rd_we = '1' report "pending register write was not reached" severity failure;
    phase <= 4;
    restart(2);
    report "pending register write/retirement suppressed; restart verified";
    phase <= 5;
    report "tb_core_reset passed: 3 injected resets, request gating, RAM persistence, register reset, PC zero";
    stop;
    wait;
  end process;
  process
  begin
    wait for 5 us;
    assert false report "tb_core_reset timed out" severity failure;
  end process;
end architecture;
