library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_decoder is
end entity;

architecture test of tb_decoder is
  signal instruction : word_t := (others => '0');
  signal legal : std_logic;
  signal rs1, rs2, rd : reg_index_t;
  signal immediate : word_t;
  signal control : decode_control_t;

  -- Expected records are built independently of DECODE_CONTROL_ILLEGAL.
  -- Checking every field also catches stale controls after a legal instruction
  -- is followed by an illegal one, and unintended changes to package defaults.
  function controls(
    kind : instr_kind_t;
    alu : alu_op_t := ALU_ADD;
    lhs : alu_lhs_sel_t := LHS_RS1;
    rhs : alu_rhs_sel_t := RHS_RS2;
    writes : std_logic := '0';
    wb : writeback_sel_t := WB_ALU;
    branch_op : branch_op_t := BR_NONE;
    size : mem_size_t := MEM_WORD;
    unsigned_load : std_logic := '0'
  ) return decode_control_t is
  begin
    return (kind, alu, lhs, rhs, writes, wb, branch_op, size, unsigned_load);
  end function;

  constant ILLEGAL_EXPECTED : decode_control_t := controls(INSTR_ILLEGAL);
  type alu_table_t is array (0 to 7) of alu_op_t;
  constant BASE_ALU : alu_table_t :=
    (ALU_ADD, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_SRL, ALU_OR, ALU_AND);
  type branch_table_t is array (0 to 7) of branch_op_t;
  constant BRANCHES : branch_table_t :=
    (BR_EQ, BR_NE, BR_NONE, BR_NONE, BR_LT, BR_GE, BR_LTU, BR_GEU);
  type size_table_t is array (0 to 2) of mem_size_t;
  constant SIZES : size_table_t := (MEM_BYTE, MEM_HALF, MEM_WORD);

  function signed_word(value : integer) return word_t is
  begin
    return std_logic_vector(to_signed(value, 32));
  end function;

  -- A full record comparison catches every control-field mismatch. Include
  -- the complete record in failure messages so width/mux/writeback mistakes
  -- can be diagnosed without first opening a waveform viewer.
  function describe(value : decode_control_t) return string is
  begin
    return instr_kind_t'image(value.kind) & " " & alu_op_t'image(value.alu_op) &
      " lhs=" & alu_lhs_sel_t'image(value.lhs_sel) &
      " rhs=" & alu_rhs_sel_t'image(value.rhs_sel) &
      " rd_write=" & std_logic'image(value.rd_write) &
      " wb=" & writeback_sel_t'image(value.wb_sel) &
      " branch=" & branch_op_t'image(value.branch) &
      " size=" & mem_size_t'image(value.mem_size) &
      " unsigned=" & std_logic'image(value.load_unsigned);
  end function;

  -- Builders encode semantic values into instruction formats for exhaustive
  -- sweeps. Expected immediates always come from the ORIGINAL integer value,
  -- never by extracting and rearranging bits from the encoded instruction.
  -- Forty assembler-generated literals below independently check the layout.
  function encode_r(f7, f3, dest, source1, source2 : natural) return word_t is
  begin
    return std_logic_vector(shift_left(to_unsigned(f7, 32), 25) or
      shift_left(to_unsigned(source2, 32), 20) or
      shift_left(to_unsigned(source1, 32), 15) or
      shift_left(to_unsigned(f3, 32), 12) or
      shift_left(to_unsigned(dest, 32), 7) or to_unsigned(16#33#, 32));
  end function;

  function encode_i(opcode, f3, dest, source1 : natural; value : integer)
    return word_t is
    variable result : word_t := (others => '0');
  begin
    result(31 downto 20) := std_logic_vector(to_signed(value, 12));
    result(19 downto 15) := std_logic_vector(to_unsigned(source1, 5));
    result(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
    result(11 downto 7) := std_logic_vector(to_unsigned(dest, 5));
    result(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
    return result;
  end function;

  function encode_s(f3 : natural; value : integer) return word_t is
    variable result : word_t := encode_r(0, f3, 0, 5, 13);
    variable offset : std_logic_vector(11 downto 0);
  begin
    offset := std_logic_vector(to_signed(value, 12));
    result(31 downto 25) := offset(11 downto 5);
    result(11 downto 7) := offset(4 downto 0);
    result(6 downto 0) := "0100011";
    return result;
  end function;

  function encode_b(f3 : natural; value : integer) return word_t is
    variable result : word_t := encode_r(0, f3, 0, 5, 13);
    variable offset : std_logic_vector(12 downto 0);
  begin
    assert value mod 2 = 0 report "test tried to encode an odd B offset" severity failure;
    offset := std_logic_vector(to_signed(value, 13));
    result(31) := offset(12);
    result(30 downto 25) := offset(10 downto 5);
    result(11 downto 8) := offset(4 downto 1);
    result(7) := offset(11);
    result(6 downto 0) := "1100011";
    return result;
  end function;

  function encode_j(value : integer) return word_t is
    variable result : word_t := x"000003EF"; -- JAL x7, immediate to be inserted
    variable offset : std_logic_vector(20 downto 0);
  begin
    assert value mod 2 = 0 report "test tried to encode an odd J offset" severity failure;
    offset := std_logic_vector(to_signed(value, 21));
    result(31) := offset(20);
    result(30 downto 21) := offset(10 downto 1);
    result(20) := offset(11);
    result(19 downto 12) := offset(19 downto 12);
    return result;
  end function;

  function encode_u(opcode : natural; value : word_t) return word_t is
    variable result : word_t := value;
  begin
    result(11 downto 7) := "00111";
    result(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
    return result;
  end function;
begin
  dut : entity work.rv32i_decoder
    port map (
      instr_i => instruction, legal_o => legal,
      rs1_o => rs1, rs2_o => rs2, rd_o => rd,
      imm_o => immediate, ctrl_o => control
    );

  process
    variable checks : natural := 0;
    variable expected : decode_control_t;
    variable value, signed12 : integer;
    variable word, expected_imm : word_t;
    variable random_bits : unsigned(31 downto 0) := x"1BADB002";

    procedure expect(code : word_t; wanted : decode_control_t;
                     wanted_imm : word_t := x"00000000"; label_text : string := "sweep") is
      variable wanted_legal : std_logic := '1';
    begin
      if wanted.kind = INSTR_ILLEGAL then wanted_legal := '0'; end if;
      instruction <= code;
      wait for 1 ns; -- Settle the combinational process and concurrent field outputs.
      checks := checks + 1;
      assert legal = wanted_legal
        report label_text & " legality, instruction=" & to_hstring(code) severity failure;
      assert immediate = wanted_imm
        report label_text & " immediate, instruction=" & to_hstring(code) &
          " expected=" & to_hstring(wanted_imm) & " actual=" & to_hstring(immediate) severity failure;
      assert rs1 = code(19 downto 15) and rs2 = code(24 downto 20) and rd = code(11 downto 7)
        report label_text & " register fields, instruction=" & to_hstring(code) severity failure;
      assert control = wanted
        report label_text & " controls, instruction=" & to_hstring(code) &
          " expected={" & describe(wanted) & "} actual={" & describe(control) & "}"
        severity failure;
    end procedure;
  begin
    -- One fixed encoding for EVERY RV32I mnemonic, assembled independently
    -- with LLVM llvm-mc -triple=riscv32 -mattr=-c. No assembler is needed to
    -- run this testbench. Negative offsets intentionally include addresses
    -- that could be misaligned at execution: that is not a decoder fault.
    -- lui x7, 0xabcde
    expect(x"ABCDE3B7", controls(INSTR_LUI, lhs => LHS_ZERO, rhs => RHS_IMM, writes => '1'),
      x"ABCDE000", "lui x7, 0xabcde");
    -- auipc x7, 0xabcde
    expect(x"ABCDE397", controls(INSTR_AUIPC, lhs => LHS_PC, rhs => RHS_IMM, writes => '1'),
      x"ABCDE000", "auipc x7, 0xabcde");
    -- jal x7, -2046
    expect(x"803FF3EF", controls(INSTR_JAL, lhs => LHS_PC, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4),
      x"FFFFF802", "jal x7, -2046");
    -- jalr x7, -17(x5)
    expect(x"FEF283E7", controls(INSTR_JALR, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4),
      x"FFFFFFEF", "jalr x7, -17(x5)");
    -- beq x5, x13, -18
    expect(x"FED287E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_EQ),
      x"FFFFFFEE", "beq x5, x13, -18");
    -- bne x5, x13, -18
    expect(x"FED297E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_NE),
      x"FFFFFFEE", "bne x5, x13, -18");
    -- blt x5, x13, -18
    expect(x"FED2C7E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_LT),
      x"FFFFFFEE", "blt x5, x13, -18");
    -- bge x5, x13, -18
    expect(x"FED2D7E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_GE),
      x"FFFFFFEE", "bge x5, x13, -18");
    -- bltu x5, x13, -18
    expect(x"FED2E7E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_LTU),
      x"FFFFFFEE", "bltu x5, x13, -18");
    -- bgeu x5, x13, -18
    expect(x"FED2F7E3", controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BR_GEU),
      x"FFFFFFEE", "bgeu x5, x13, -18");
    -- lb x7, -17(x5)
    expect(x"FEF28383", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY, size => MEM_BYTE, unsigned_load => '0'),
      x"FFFFFFEF", "lb x7, -17(x5)");
    -- lh x7, -17(x5)
    expect(x"FEF29383", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY, size => MEM_HALF, unsigned_load => '0'),
      x"FFFFFFEF", "lh x7, -17(x5)");
    -- lw x7, -17(x5)
    expect(x"FEF2A383", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY, size => MEM_WORD, unsigned_load => '0'),
      x"FFFFFFEF", "lw x7, -17(x5)");
    -- lbu x7, -17(x5)
    expect(x"FEF2C383", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY, size => MEM_BYTE, unsigned_load => '1'),
      x"FFFFFFEF", "lbu x7, -17(x5)");
    -- lhu x7, -17(x5)
    expect(x"FEF2D383", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY, size => MEM_HALF, unsigned_load => '1'),
      x"FFFFFFEF", "lhu x7, -17(x5)");
    -- sb x13, -17(x5)
    expect(x"FED287A3", controls(INSTR_STORE, rhs => RHS_IMM, size => MEM_BYTE),
      x"FFFFFFEF", "sb x13, -17(x5)");
    -- sh x13, -17(x5)
    expect(x"FED297A3", controls(INSTR_STORE, rhs => RHS_IMM, size => MEM_HALF),
      x"FFFFFFEF", "sh x13, -17(x5)");
    -- sw x13, -17(x5)
    expect(x"FED2A7A3", controls(INSTR_STORE, rhs => RHS_IMM, size => MEM_WORD),
      x"FFFFFFEF", "sw x13, -17(x5)");
    -- addi x7, x5, -17
    expect(x"FEF28393", controls(INSTR_ALU, alu => ALU_ADD, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "addi x7, x5, -17");
    -- slti x7, x5, -17
    expect(x"FEF2A393", controls(INSTR_ALU, alu => ALU_SLT, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "slti x7, x5, -17");
    -- sltiu x7, x5, -17
    expect(x"FEF2B393", controls(INSTR_ALU, alu => ALU_SLTU, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "sltiu x7, x5, -17");
    -- xori x7, x5, -17
    expect(x"FEF2C393", controls(INSTR_ALU, alu => ALU_XOR, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "xori x7, x5, -17");
    -- ori x7, x5, -17
    expect(x"FEF2E393", controls(INSTR_ALU, alu => ALU_OR, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "ori x7, x5, -17");
    -- andi x7, x5, -17
    expect(x"FEF2F393", controls(INSTR_ALU, alu => ALU_AND, rhs => RHS_IMM, writes => '1'),
      x"FFFFFFEF", "andi x7, x5, -17");
    -- slli x7, x5, 31
    expect(x"01F29393", controls(INSTR_ALU, alu => ALU_SLL, rhs => RHS_IMM, writes => '1'),
      x"0000001F", "slli x7, x5, 31");
    -- srli x7, x5, 31
    expect(x"01F2D393", controls(INSTR_ALU, alu => ALU_SRL, rhs => RHS_IMM, writes => '1'),
      x"0000001F", "srli x7, x5, 31");
    -- srai x7, x5, 31
    expect(x"41F2D393", controls(INSTR_ALU, alu => ALU_SRA, rhs => RHS_IMM, writes => '1'),
      x"0000001F", "srai x7, x5, 31");
    -- add x7, x5, x13
    expect(x"00D283B3", controls(INSTR_ALU, alu => ALU_ADD, writes => '1'),
      x"00000000", "add x7, x5, x13");
    -- sub x7, x5, x13
    expect(x"40D283B3", controls(INSTR_ALU, alu => ALU_SUB, writes => '1'),
      x"00000000", "sub x7, x5, x13");
    -- sll x7, x5, x13
    expect(x"00D293B3", controls(INSTR_ALU, alu => ALU_SLL, writes => '1'),
      x"00000000", "sll x7, x5, x13");
    -- slt x7, x5, x13
    expect(x"00D2A3B3", controls(INSTR_ALU, alu => ALU_SLT, writes => '1'),
      x"00000000", "slt x7, x5, x13");
    -- sltu x7, x5, x13
    expect(x"00D2B3B3", controls(INSTR_ALU, alu => ALU_SLTU, writes => '1'),
      x"00000000", "sltu x7, x5, x13");
    -- xor x7, x5, x13
    expect(x"00D2C3B3", controls(INSTR_ALU, alu => ALU_XOR, writes => '1'),
      x"00000000", "xor x7, x5, x13");
    -- srl x7, x5, x13
    expect(x"00D2D3B3", controls(INSTR_ALU, alu => ALU_SRL, writes => '1'),
      x"00000000", "srl x7, x5, x13");
    -- sra x7, x5, x13
    expect(x"40D2D3B3", controls(INSTR_ALU, alu => ALU_SRA, writes => '1'),
      x"00000000", "sra x7, x5, x13");
    -- or x7, x5, x13
    expect(x"00D2E3B3", controls(INSTR_ALU, alu => ALU_OR, writes => '1'),
      x"00000000", "or x7, x5, x13");
    -- and x7, x5, x13
    expect(x"00D2F3B3", controls(INSTR_ALU, alu => ALU_AND, writes => '1'),
      x"00000000", "and x7, x5, x13");
    -- fence iorw, iorw
    expect(x"0FF0000F", controls(INSTR_FENCE),
      x"00000000", "fence iorw, iorw");
    -- ecall
    expect(x"00000073", controls(INSTR_ECALL),
      x"00000000", "ecall");
    -- ebreak
    expect(x"00100073", controls(INSTR_EBREAK),
      x"00000000", "ebreak");

    -- Every R-format funct7/funct3 combination, including all M-extension
    -- combinations, must either select the exact base operation or be illegal.
    for f7 in 0 to 127 loop
      for f3 in 0 to 7 loop
        expected := ILLEGAL_EXPECTED;
        if f7 = 0 then
          expected := controls(INSTR_ALU, alu => BASE_ALU(f3), writes => '1');
        elsif f7 = 32 and f3 = 0 then
          expected := controls(INSTR_ALU, alu => ALU_SUB, writes => '1');
        elsif f7 = 32 and f3 = 5 then
          expected := controls(INSTR_ALU, alu => ALU_SRA, writes => '1');
        end if;
        expect(encode_r(f7, f3, 7, 5, 13), expected);
      end loop;
    end loop;

    -- Sweep ALL twelve immediate bits and all funct3 values. For normal I
    -- instructions the expected value is signed12, not a decoded bit slice.
    -- For shifts, the same sweep covers every shamt (0..31) under every
    -- upper-seven-bit pattern, including the forbidden RV64 shamt bit 5.
    for raw12 in 0 to 4095 loop
      signed12 := raw12;
      if raw12 >= 2048 then signed12 := raw12 - 4096; end if;
      for f3 in 0 to 7 loop
        expected := controls(INSTR_ALU, alu => BASE_ALU(f3), rhs => RHS_IMM, writes => '1');
        expected_imm := signed_word(signed12);
        if f3 = 1 or f3 = 5 then
          expected := ILLEGAL_EXPECTED;
          expected_imm := (others => '0');
          if raw12 < 32 then
            expected := controls(INSTR_ALU, alu => BASE_ALU(f3), rhs => RHS_IMM, writes => '1');
            expected_imm := signed_word(raw12);
          elsif f3 = 5 and raw12 >= 1024 and raw12 < 1056 then
            expected := controls(INSTR_ALU, alu => ALU_SRA, rhs => RHS_IMM, writes => '1');
            expected_imm := signed_word(raw12 - 1024);
          end if;
        end if;
        expect(encode_i(16#13#, f3, 7, 5, signed12), expected, expected_imm);

        -- Signed address offsets are independent of load signedness. Include
        -- reserved widths (LD, LWU) so unsupported loads cannot assert writes.
        expected := ILLEGAL_EXPECTED;
        expected_imm := (others => '0');
        if f3 <= 2 then
          expected := controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1',
            wb => WB_MEMORY, size => SIZES(f3));
          expected_imm := signed_word(signed12);
        elsif f3 = 4 or f3 = 5 then
          expected := controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1',
            wb => WB_MEMORY, size => SIZES(f3 - 4), unsigned_load => '1');
          expected_imm := signed_word(signed12);
        end if;
        expect(encode_i(16#03#, f3, 7, 5, signed12), expected, expected_imm);

        expected := ILLEGAL_EXPECTED;
        expected_imm := (others => '0');
        if f3 = 0 then
          expected := controls(INSTR_JALR, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4);
          expected_imm := signed_word(signed12);
        end if;
        expect(encode_i(16#67#, f3, 7, 5, signed12), expected, expected_imm);

        -- All S offsets and every even B offset, including signed endpoints
        -- and offsets with bit 1 set. IALIGN=32 is checked later by execution.
        expected := ILLEGAL_EXPECTED;
        expected_imm := (others => '0');
        if f3 <= 2 then
          expected := controls(INSTR_STORE, rhs => RHS_IMM, size => SIZES(f3));
          expected_imm := signed_word(signed12);
        end if;
        expect(encode_s(f3, signed12), expected, expected_imm);

        expected := ILLEGAL_EXPECTED;
        expected_imm := (others => '0');
        if BRANCHES(f3) /= BR_NONE then
          expected := controls(INSTR_BRANCH, lhs => LHS_PC, rhs => RHS_IMM, branch_op => BRANCHES(f3));
          expected_imm := signed_word(2 * signed12);
        end if;
        expect(encode_b(f3, 2 * signed12), expected, expected_imm);

        -- FENCE ignores its other fields. Sweep every fm/pred/succ pattern,
        -- varying rs1 and rd too. FENCE.I and every other funct3 stay illegal.
        expected := ILLEGAL_EXPECTED;
        if f3 = 0 then expected := controls(INSTR_FENCE); end if;
        expect(encode_i(16#0F#, f3, raw12 mod 32, (raw12 / 32) mod 32, signed12), expected);

        -- SYSTEM: all 4096 function values and all eight funct3 values.
        -- CSR instructions remain illegal even when rs1/rd are both zero.
        expected := ILLEGAL_EXPECTED;
        if f3 = 0 and raw12 = 0 then expected := controls(INSTR_ECALL);
        elsif f3 = 0 and raw12 = 1 then expected := controls(INSTR_EBREAK); end if;
        expect(encode_i(16#73#, f3, 0, 0, signed12), expected);
      end loop;
    end loop;

    -- SYSTEM reserved register fields must be zero for BOTH supported traps.
    -- In contrast, FENCE must ignore every rs1/rd combination.
    for dest in 0 to 31 loop
      for source1 in 0 to 31 loop
        for sys in 0 to 1 loop
          expected := ILLEGAL_EXPECTED;
          if dest = 0 and source1 = 0 then
            if sys = 0 then expected := controls(INSTR_ECALL);
            else expected := controls(INSTR_EBREAK); end if;
          end if;
          expect(encode_i(16#73#, 0, dest, source1, sys), expected);
        end loop;
        expect(encode_i(16#0F#, 0, dest, source1, -1), controls(INSTR_FENCE));
        for source2 in 0 to 31 loop
          expect(encode_r(0, 0, dest, source1, source2),
            controls(INSTR_ALU, writes => '1'));
        end loop;
      end loop;
    end loop;

    -- Reject every unsupported seven-bit opcode under all funct3 values.
    -- This includes all compressed low-bit patterns, RV64 word instructions,
    -- floating point, atomics, custom opcodes, and longer instruction prefixes.
    for opcode in 0 to 127 loop
      if opcode /= 16#37# and opcode /= 16#17# and opcode /= 16#6F# and
         opcode /= 16#67# and opcode /= 16#63# and opcode /= 16#03# and
         opcode /= 16#23# and opcode /= 16#13# and opcode /= 16#33# and
         opcode /= 16#0F# and opcode /= 16#73# then
        for f3 in 0 to 7 loop
          expect(encode_i(opcode, f3, 31, 31, -1), ILLEGAL_EXPECTED);
        end loop;
      end if;
    end loop;

    -- Walking ones/zeros prove each U bit's position and that no sign or
    -- lower-format interpretation leaks into this full-width immediate.
    for bit_index in 12 to 31 loop
      word := (others => '0');
      word(bit_index) := '1';
      expect(encode_u(16#37#, word),
        controls(INSTR_LUI, lhs => LHS_ZERO, rhs => RHS_IMM, writes => '1'), word);
      expect(encode_u(16#17#, word),
        controls(INSTR_AUIPC, lhs => LHS_PC, rhs => RHS_IMM, writes => '1'), word);
      word := not word;
      word(11 downto 0) := (others => '0');
      expect(encode_u(16#37#, word),
        controls(INSTR_LUI, lhs => LHS_ZERO, rhs => RHS_IMM, writes => '1'), word);
      expect(encode_u(16#17#, word),
        controls(INSTR_AUIPC, lhs => LHS_PC, rhs => RHS_IMM, writes => '1'), word);
    end loop;

    expected := controls(INSTR_JAL, lhs => LHS_PC, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4);
    expect(encode_j(0), expected);
    expect(encode_j(-1048576), expected, signed_word(-1048576));
    expect(encode_j(1048574), expected, signed_word(1048574));
    expect(encode_j(-2), expected, signed_word(-2));
    for bit_index in 1 to 19 loop
      expect(encode_j(2 ** bit_index), expected, signed_word(2 ** bit_index));
      expect(encode_j(-(2 ** bit_index)), expected, signed_word(-(2 ** bit_index)));
    end loop;

    -- A deterministic LFSR supplies mixed J/U bit patterns to supplement the
    -- walking-bit cases. The fixed seed makes failures exactly reproducible.
    for sample in 1 to 1024 loop
      random_bits := random_bits(30 downto 0) &
        (random_bits(31) xor random_bits(21) xor random_bits(1) xor random_bits(0));
      value := 2 * (to_integer(random_bits(19 downto 0)) - 524288);
      expect(encode_j(value), expected, signed_word(value));
      word := std_logic_vector(random_bits(31 downto 12)) & x"000";
      expect(encode_u(16#37#, word),
        controls(INSTR_LUI, lhs => LHS_ZERO, rhs => RHS_IMM, writes => '1'), word);
      expect(encode_u(16#17#, word),
        controls(INSTR_AUIPC, lhs => LHS_PC, rhs => RHS_IMM, writes => '1'), word);
    end loop;
    expect(x"000003B7", controls(INSTR_LUI, lhs => LHS_ZERO, rhs => RHS_IMM, writes => '1'));
    expect(x"FFFFF397", controls(INSTR_AUIPC, lhs => LHS_PC, rhs => RHS_IMM, writes => '1'), x"FFFFF000");

    -- rd=x0 is not an illegal encoding and does not turn a faulting load into
    -- a NOP. rd_write remains intent; the future writeback stage masks x0.
    expect(x"00000013", controls(INSTR_ALU, rhs => RHS_IMM, writes => '1'), x"00000000", "NOP");
    expect(x"00002003", controls(INSTR_LOAD, rhs => RHS_IMM, writes => '1', wb => WB_MEMORY),
      x"00000000", "LW x0,0(x0)");
    expect(x"0000006F", controls(INSTR_JAL, lhs => LHS_PC, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4));
    expect(x"00000067", controls(INSTR_JALR, rhs => RHS_IMM, writes => '1', wb => WB_PC_PLUS_4));

    -- Poison each bit of a normally valid instruction with X/U/Z. Even
    -- unknown unused fields must not accidentally yield active controls.
    for bit_index in 0 to 31 loop
      for unknown in 0 to 2 loop
        word := x"00D2A023"; -- SW x13,0(x5): exercise clearing store controls.
        expect(word, controls(INSTR_STORE, rhs => RHS_IMM));
        case unknown is
          when 0 => word(bit_index) := 'X';
          when 1 => word(bit_index) := 'U';
          when others => word(bit_index) := 'Z';
        end case;
        expect(word, ILLEGAL_EXPECTED);
      end loop;
    end loop;
    word := x"0FF0000F"; -- FENCE has ignored immediate fields, unlike SW.
    expect(word, controls(INSTR_FENCE));
    word(24) := 'X';
    expect(word, ILLEGAL_EXPECTED);
    expect(x"FFFFFFFF", ILLEGAL_EXPECTED);
    expect(x"00100073", controls(INSTR_EBREAK)); -- Recovery after illegal data.

    report "tb_decoder passed: " & natural'image(checks) & " decode cases" severity note;
    stop;
    wait;
  end process;

  process
  begin
    wait for 1 ms;
    assert false report "tb_decoder timed out" severity failure;
  end process;
end architecture;
