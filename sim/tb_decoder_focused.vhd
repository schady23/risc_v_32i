library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
use work.rv32i_pkg.all;

-- Report 4 Goal 2: a short, readable companion to the exhaustive decoder bench.
entity tb_decoder_focused is
end entity;

architecture test of tb_decoder_focused is
  signal instruction, immediate : word_t := (others => '0');
  signal legal : std_logic;
  signal rs1, rs2, rd : reg_index_t;
  signal control : decode_control_t;
  signal case_index : natural := 0;
  -- VCD cannot store VHDL records/enumerations. GHW retains the originals;
  -- these aliases expose their enum positions in the portable VCD as well.
  signal kind_code, alu_code, lhs_code, rhs_code, wb_code, branch_code,
         size_code : natural;
  signal rd_write, load_unsigned : std_logic;

  function expected(kind : instr_kind_t; lhs : alu_lhs_sel_t := LHS_RS1;
                    writes : std_logic := '0'; wb : writeback_sel_t := WB_ALU;
                    branch_op : branch_op_t := BR_NONE) return decode_control_t is
  begin
    return (kind, ALU_ADD, lhs, RHS_IMM, writes, wb, branch_op, MEM_WORD, '0');
  end function;
begin
  dut : entity work.rv32i_decoder
    port map (instr_i => instruction, legal_o => legal, rs1_o => rs1,
              rs2_o => rs2, rd_o => rd, imm_o => immediate, ctrl_o => control);
  kind_code <= instr_kind_t'pos(control.kind);
  alu_code <= alu_op_t'pos(control.alu_op);
  lhs_code <= alu_lhs_sel_t'pos(control.lhs_sel);
  rhs_code <= alu_rhs_sel_t'pos(control.rhs_sel);
  wb_code <= writeback_sel_t'pos(control.wb_sel);
  branch_code <= branch_op_t'pos(control.branch);
  size_code <= mem_size_t'pos(control.mem_size);
  rd_write <= control.rd_write;
  load_unsigned <= control.load_unsigned;

  process
    variable checks : natural := 0;
    procedure check(code, imm : word_t; ctrl : decode_control_t;
                    source1, source2, dest : reg_index_t;
                    valid : std_logic; label_text : string) is
    begin
      case_index <= checks + 1;
      instruction <= code;
      wait for 1 ns;
      assert legal = valid and immediate = imm and control = ctrl
        report label_text & " immediate/control mismatch" severity failure;
      assert rs1 = source1 and rs2 = source2 and rd = dest
        report label_text & " raw register fields mismatch" severity failure;
      checks := checks + 1;
      report label_text & " instr=" & to_hstring(instruction) &
        " imm=" & to_hstring(immediate) & " kind=" & instr_kind_t'image(control.kind) &
        " rd_write=" & std_logic'image(rd_write) & " size=" & mem_size_t'image(control.mem_size);
      wait for 9 ns;
    end procedure;
  begin
    -- Expected values and literal instruction words are fixed independently
    -- of the DUT. Raw rs2/rd bits are checked even in formats that do not use them.
    check(x"FFF00093", x"FFFFFFFF", expected(INSTR_ALU, writes => '1'),
          "00000", "11111", "00001", '1', "ADDI x1,x0,-1");
    check(x"00C0A103", x"0000000C", expected(INSTR_LOAD, writes => '1', wb => WB_MEMORY),
          "00001", "01100", "00010", '1', "LW x2,12(x1)");
    check(x"FE20AE23", x"FFFFFFFC", expected(INSTR_STORE),
          "00001", "00010", "11100", '1', "SW x2,-4(x1)");
    check(x"00208463", x"00000008", expected(INSTR_BRANCH, lhs => LHS_PC, branch_op => BR_EQ),
          "00001", "00010", "01000", '1', "BEQ x1,x2,8");
    check(x"010001EF", x"00000010", expected(INSTR_JAL, lhs => LHS_PC, writes => '1', wb => WB_PC_PLUS_4),
          "00000", "10000", "00011", '1', "JAL x3,16");
    check(x"FFFFFFFF", x"00000000",
          (INSTR_ILLEGAL, ALU_ADD, LHS_RS1, RHS_RS2, '0', WB_ALU, BR_NONE, MEM_WORD, '0'),
          "11111", "11111", "11111", '0', "Illegal encoding");
    check(x"00000013", x"00000000", expected(INSTR_ALU, writes => '1'),
          "00000", "00000", "00000", '1', "NOP recovery");
    report "tb_decoder_focused passed: " & natural'image(checks) & " cases";
    stop;
    wait;
  end process;
end architecture;
