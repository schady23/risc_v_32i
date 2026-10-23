library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
use work.rv32i_pkg.all;

-- Reset around instruction-fetch and load acceptance/response boundaries.
-- Uses the real core, register file, bus and RAM with an independent ROM.
entity tb_core_reset_extended is end entity;

architecture test of tb_core_reset_extended is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal iq, ifault, dq, dw, dfault, halted, tv, rv, rw : std_logic := '0';
  signal ia, idata, da, wd, data, tp, tt, rp, ri, rddata : word_t := (others => '0');
  signal be : byte_enable_t;
  signal cause : trap_cause_t;
  signal rd : reg_index_t;
  signal phase, retire_count, load_commits : natural := 0;
begin
  clk <= not clk after 5 ns;
  cpu : entity work.rv32i_core port map (
    clk, reset, iq, ia, idata, ifault, dq, dw, da, wd, be, data, dfault,
    halted, tv, cause, tp, tt, rv, rp, ri, rw, rd, rddata);
  memory : entity work.memory_bus port map (
    clk_i => clk, reset_i => reset, i_req_i => '0', i_addr_i => x"00000000",
    i_rdata_o => open, i_fault_o => open, d_req_i => dq, d_write_i => dw,
    d_addr_i => da, d_wdata_i => wd, d_be_i => be, d_rdata_o => data,
    d_fault_o => dfault, av_address_o => open, av_read_o => open,
    av_write_o => open, av_writedata_o => open,
    av_readdata_i => x"00400000", av_waitrequest_i => '0');

  process(clk)
  begin
    if rising_edge(clk) then
      ifault <= '0';
      if iq = '1' then
        case ia is
          when x"00000000" => idata <= x"00140493"; -- ADDI x9,x8,1
          when x"00000004" => idata <= x"000102B7"; -- LUI x5,0x10
          when x"00000008" => idata <= x"05500313"; -- ADDI x6,x0,0x55
          when x"0000000C" => idata <= x"0062A023"; -- SW x6,0(x5)
          when x"00000010" => idata <= x"0002A403"; -- LW x8,0(x5)
          when x"00000014" => idata <= x"FEDFF06F"; -- JAL x0,-20
          when others => ifault <= '1';
        end case;
      end if;
      if reset = '1' then
        assert iq = '0' and dq = '0' and dw = '0' and rv = '0' and rw = '0'
          report "reset allowed a request or commit" severity failure;
      end if;
      if rv = '1' then
        retire_count <= retire_count + 1;
        if rp = x"00000010" then
          assert rw = '1' and rd = "01000" and rddata = x"00000055"
            report "load result mismatch" severity failure;
          load_commits <= load_commits + 1;
        end if;
      end if;
      assert halted = '0' and tv = '0'
        report "reset test unexpectedly trapped" severity failure;
    end if;
  end process;

  process
    procedure retire(pc : word_t; dest : reg_index_t; value : word_t;
                     writes : std_logic := '1') is
    begin
      loop
        wait until rising_edge(clk);
        exit when rv = '1';
      end loop;
      assert rp = pc and rw = writes
        report "unexpected retirement after reset" severity failure;
      if writes = '1' then
        assert rd = dest and rddata = value
          report "unexpected register result after reset" severity failure;
      end if;
    end procedure;
    procedure restart is
      variable previous_retirements, previous_loads : natural;
    begin
      -- Called at a falling edge, before the next acceptance/commit edge.
      previous_retirements := retire_count;
      previous_loads := load_commits;
      reset <= '1';
      wait for 1 ns;
      assert iq = '0' and dq = '0' and dw = '0' and rv = '0' and rw = '0'
        report "reset gating failed before the next edge" severity failure;
      for cycle in 1 to 2 loop
        wait until rising_edge(clk);
        wait for 1 ns;
        assert ia = x"00000000" and retire_count = previous_retirements and
               load_commits = previous_loads
          report "canceled instruction committed during reset" severity failure;
      end loop;
      wait until falling_edge(clk);
      reset <= '0';
      wait for 1 ns;
      assert iq = '1' and ia = x"00000000"
        report "restart fetch was not PC zero" severity failure;
      -- x8 held 0x55 before injection. This read after reset proves it is zero.
      retire(x"00000000", "01001", x"00000001");
      retire(x"00000004", "00101", x"00010000");
      retire(x"00000008", "00110", x"00000055");
      retire(x"0000000C", "00000", x"00000000", '0');
    end procedure;
  begin
    wait until falling_edge(clk);
    restart;
    -- Seed x8 with a nonzero value before every injection.
    retire(x"00000010", "01000", x"00000055");
    wait until iq = '1' and ia = x"00000014";
    wait until falling_edge(clk);
    phase <= 1;
    restart;
    report "fetch request reset passed: request canceled, PC zero, x8 cleared";

    retire(x"00000010", "01000", x"00000055");
    wait until iq = '1' and ia = x"00000014";
    wait until rising_edge(clk); -- Accepted fetch, now FETCH_WAIT.
    wait until falling_edge(clk);
    phase <= 2;
    restart;
    report "fetch response reset passed: stale instruction discarded";

    retire(x"00000010", "01000", x"00000055");
    wait until dq = '1' and dw = '0'; -- Next loop's load.
    wait until falling_edge(clk);
    phase <= 3;
    restart;
    report "load request reset passed: no canceled load writeback";

    retire(x"00000010", "01000", x"00000055");
    wait until dq = '1' and dw = '0';
    wait until rising_edge(clk); -- Accepted load, now MEM_READ_WAIT.
    wait until falling_edge(clk);
    assert data = x"00000055" report "load response not reached" severity failure;
    phase <= 4;
    restart;
    report "load response reset passed: pending data discarded, no writeback";
    retire(x"00000010", "01000", x"00000055");
    phase <= 5;
    report "tb_core_reset_extended passed: 4 injected resets at fetch/load boundaries";
    stop;
    wait;
  end process;
  process
  begin
    wait for 10 us;
    assert false report "tb_core_reset_extended timed out" severity failure;
  end process;
end architecture;
