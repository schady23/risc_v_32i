library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_core_execution is
end entity;

architecture test of tb_core_execution is
  signal clk, reset : std_logic := '0';
  signal scenario : natural range 0 to 11 := 0;
  signal i_req, i_fault : std_logic := '0';
  signal i_addr, i_rdata : word_t := (others => '0');
  signal d_req, d_write, d_fault : std_logic := '0';
  signal d_addr, d_wdata, d_rdata : word_t := (others => '0');
  signal d_be : byte_enable_t := (others => '0');
  signal halted, trap_valid, retire_valid, retire_rd_we : std_logic;
  signal trap_cause : trap_cause_t;
  signal trap_pc, trap_tval, retire_pc, retire_instr, retire_rd_data : word_t;
  signal retire_rd : reg_index_t;
  signal memory_word : word_t := (others => '0');
begin
  clk <= not clk after 5 ns;

  dut : entity work.rv32i_core
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

  process (clk)
  begin
    if rising_edge(clk) then
      i_fault <= '0';
      if i_req = '1' then
        if scenario = 0 then
          case i_addr is
            when x"00000000" => i_rdata <= x"00500093"; -- addi x1,x0,5
            when x"00000004" => i_rdata <= x"FFF08113"; -- addi x2,x1,-1
            when x"00000008" => i_rdata <= x"00208463"; -- beq x1,x2,+8, untaken
            when x"0000000C" => i_rdata <= x"002081B3"; -- add x3,x1,x2
            when x"00000010" => i_rdata <= x"0080026F"; -- jal x4,+8
            when x"00000014" => i_rdata <= x"06300193"; -- skipped
            when x"00000018" => i_rdata <= x"00302023"; -- sw x3,0(x0)
            when x"0000001C" => i_rdata <= x"00002283"; -- lw x5,0(x0)
            when x"00000020" => i_rdata <= x"00100073"; -- ebreak
            when others => i_fault <= '1'; i_rdata <= (others => '0');
          end case;
        else
          case scenario is
            when 1 => i_rdata <= x"FFFFFFFF"; -- illegal
            when 2 => i_rdata <= x"0020006F"; -- jal x0,+2, misaligned
            when 3 => i_rdata <= x"00102083"; -- lw x1,1(x0), misaligned
            when 4 => i_rdata <= x"00002083"; -- lw x1,0(x0), fault
            when 5 => i_rdata <= x"00102023"; -- sw x1,0(x0), fault
            when 6 => i_fault <= '1'; i_rdata <= (others => '0');
            when 7 => i_rdata <= x"00300067"; -- jalr x0,3(x0), masked target 2
            when 8 => i_rdata <= x"001010A3"; -- sh x1,1(x0), misaligned
            when 9 => i_rdata <= x"001020A3"; -- sw x1,1(x0), misaligned
            when 10 => i_rdata <= x"00000073"; -- ecall
            when 11 => i_rdata <= x"00000163"; -- beq x0,x0,+2, taken
            when others => null;
          end case;
        end if;
      end if;
      d_fault <= '0';
      if d_req = '1' then
        if scenario = 4 or scenario = 5 then
          d_fault <= '1';
        elsif d_addr = x"00000000" then
          d_rdata <= memory_word;
          if d_write = '1' then
            for lane in 0 to 3 loop
              if d_be(lane) = '1' then
                memory_word(lane * 8 + 7 downto lane * 8) <=
                  d_wdata(lane * 8 + 7 downto lane * 8);
              end if;
            end loop;
          end if;
        else
          d_fault <= '1';
        end if;
      end if;
    end if;
  end process;

  process
    procedure start_case(constant selected : natural) is
    begin
      reset <= '1';
      scenario <= selected;
      wait until rising_edge(clk);
      wait for 1 ns;
      reset <= '0';
    end procedure;
    procedure expect_retire(constant address : word_t;
                            constant writes : std_logic;
                            constant destination : reg_index_t;
                            constant value : word_t) is
    begin
      for cycle in 1 to 12 loop
        wait until rising_edge(clk);
        if retire_valid = '1' then
          assert retire_pc = address and retire_rd_we = writes
            report "wrong retirement PC or write flag" severity failure;
          if writes = '1' then
            assert retire_rd = destination and retire_rd_data = value
              report "wrong retired register value" severity failure;
          end if;
          return;
        end if;
      end loop;
      assert false report "retirement timeout" severity failure;
    end procedure;
    procedure expect_trap(constant cause : trap_cause_t;
                          constant address : word_t;
                          constant value : word_t) is
    begin
      for cycle in 1 to 12 loop
        wait until rising_edge(clk);
        wait for 1 ns;
        if trap_valid = '1' then
          assert halted = '1' and trap_cause = cause and
                 trap_pc = address and trap_tval = value
            report "wrong trap state" severity failure;
          assert retire_valid = '0' and i_req = '0' and d_req = '0'
            report "trapping instruction retired or requested memory" severity failure;
          return;
        end if;
      end loop;
      assert false report "trap timeout" severity failure;
    end procedure;
  begin
    start_case(0);
    expect_retire(x"00000000", '1', "00001", x"00000005");
    expect_retire(x"00000004", '1', "00010", x"00000004");
    expect_retire(x"00000008", '0', "00000", (others => '0'));
    expect_retire(x"0000000C", '1', "00011", x"00000009");
    expect_retire(x"00000010", '1', "00100", x"00000014");
    expect_retire(x"00000018", '0', "00000", (others => '0'));
    assert memory_word = x"00000009" report "store value wrong" severity failure;
    expect_retire(x"0000001C", '1', "00101", x"00000009");
    expect_trap(TRAP_BREAKPOINT, x"00000020", x"00000000");

    start_case(1);
    expect_trap(TRAP_ILLEGAL_INSTRUCTION, x"00000000", x"FFFFFFFF");
    start_case(2);
    expect_trap(TRAP_INSTR_ADDR_MISALIGNED, x"00000000", x"00000002");
    start_case(3);
    expect_trap(TRAP_LOAD_ADDR_MISALIGNED, x"00000000", x"00000001");
    start_case(4);
    expect_trap(TRAP_LOAD_ACCESS_FAULT, x"00000000", x"00000000");
    start_case(5);
    expect_trap(TRAP_STORE_ACCESS_FAULT, x"00000000", x"00000000");
    start_case(6);
    expect_trap(TRAP_INSTR_ACCESS_FAULT, x"00000000", x"00000000");
    start_case(7);
    expect_trap(TRAP_INSTR_ADDR_MISALIGNED, x"00000000", x"00000002");
    start_case(8);
    expect_trap(TRAP_STORE_ADDR_MISALIGNED, x"00000000", x"00000001");
    start_case(9);
    expect_trap(TRAP_STORE_ADDR_MISALIGNED, x"00000000", x"00000001");
    start_case(10);
    expect_trap(TRAP_ENVIRONMENT_CALL, x"00000000", x"00000000");
    start_case(11);
    expect_trap(TRAP_INSTR_ADDR_MISALIGNED, x"00000000", x"00000002");
    report "tb_core_execution passed" severity note;
    stop;
    wait;
  end process;
end architecture;
