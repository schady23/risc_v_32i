library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;

-- Combinational RV32I decoding, with no architectural state or bus activity.
-- Encoding references:
--   https://docs.riscv.org/reference/isa/unpriv/rv32.html
--   https://docs.riscv.org/reference/isa/unpriv/rv-32-64g.html
-- See docs/architecture.md for the contract with the future execution FSM.
entity rv32i_decoder is
  port (
    instr_i : in  word_t;
    legal_o : out std_logic;
    rs1_o   : out reg_index_t;
    rs2_o   : out reg_index_t;
    rd_o    : out reg_index_t;
    imm_o   : out word_t;
    ctrl_o  : out decode_control_t
  );
end entity;

architecture rtl of rv32i_decoder is
begin
  -- Register fields occupy the same positions in every 32-bit base format.
  -- Expose the raw bits even for formats that repurpose them as immediate bits;
  -- the instruction kind tells the core which register values are meaningful.
  rs1_o <= instr_i(19 downto 15);
  rs2_o <= instr_i(24 downto 20);
  rd_o  <= instr_i(11 downto 7);

  process (all)
    variable control : decode_control_t;
    variable immediate : word_t;
    variable valid : boolean;
    variable funct3 : std_logic_vector(2 downto 0);
    variable funct7 : std_logic_vector(6 downto 0);
  begin
    control := DECODE_CONTROL_ILLEGAL;
    immediate := (others => '0');
    valid := false;
    funct3 := instr_i(14 downto 12);
    funct7 := instr_i(31 downto 25);

    -- Unknown instruction bits indicate an uninitialized/faulty simulation
    -- source. Do not turn an incompletely known instruction into a memory or
    -- register operation. This simulation-only guard is omitted in synthesis:
    -- binary hardware cannot detect std_logic's X/U/Z/W/'-' meta-values.
    -- synthesis translate_off
    if not is_x(instr_i) then
    -- synthesis translate_on
      case instr_i(6 downto 0) is
        when "0110111" =>                        -- LUI, U format
          valid := true;
          control.kind := INSTR_LUI;
          control.lhs_sel := LHS_ZERO;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          -- U immediates are already in their final bit positions. Appending
          -- twelve zeros produces the full 32-bit value, including bit 31.
          immediate := instr_i(31 downto 12) & x"000";

        when "0010111" =>                        -- AUIPC, U format
          valid := true;
          control.kind := INSTR_AUIPC;
          control.lhs_sel := LHS_PC;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          immediate := instr_i(31 downto 12) & x"000";

        when "1101111" =>                        -- JAL, J format
          valid := true;
          control.kind := INSTR_JAL;
          control.lhs_sel := LHS_PC;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          control.wb_sel := WB_PC_PLUS_4;
          -- J immediate: imm[20|10:1|11|19:12] is stored in instruction
          -- bits [31|30:21|20|19:12]. Restore byte-offset bit 0 as zero,
          -- then sign-extend all 21 bits. The ALU computes the jump target;
          -- writeback must select the return address PC+4 instead.
          immediate := std_logic_vector(resize(signed(
            instr_i(31) & instr_i(19 downto 12) & instr_i(20) &
            instr_i(30 downto 21) & '0'), 32));

        when "1100111" =>                        -- JALR, I format
          valid := funct3 = "000";
          control.kind := INSTR_JALR;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          control.wb_sel := WB_PC_PLUS_4;
          immediate := std_logic_vector(resize(signed(instr_i(31 downto 20)), 32));
          -- Execution clears bit 0 of rs1+imm, then checks word alignment.
          -- Do not mask the immediate here: carries depend on rs1 as well.

        when "1100011" =>                        -- Conditional branches, B format
          valid := true;
          control.kind := INSTR_BRANCH;
          control.lhs_sel := LHS_PC;
          control.rhs_sel := RHS_IMM;
          -- B immediate: imm[12|10:5|4:1|11] lives in instruction
          -- bits [31|30:25|11:8|7]. Branch offsets are signed byte offsets.
          immediate := std_logic_vector(resize(signed(
            instr_i(31) & instr_i(7) & instr_i(30 downto 25) &
            instr_i(11 downto 8) & '0'), 32));
          case funct3 is
            when "000" => control.branch := BR_EQ;  -- BEQ
            when "001" => control.branch := BR_NE;  -- BNE
            when "100" => control.branch := BR_LT;  -- BLT, signed
            when "101" => control.branch := BR_GE;  -- BGE, signed
            when "110" => control.branch := BR_LTU; -- BLTU, unsigned
            when "111" => control.branch := BR_GEU; -- BGEU, unsigned
            when others => valid := false;          -- 010 and 011 are reserved
          end case;
          -- Equality/order is evaluated on rs1/rs2 separately from the ALU's
          -- PC+offset calculation. Check target alignment only if taken.

        when "0000011" =>                        -- Loads, I format
          valid := true;
          control.kind := INSTR_LOAD;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          control.wb_sel := WB_MEMORY;
          immediate := std_logic_vector(resize(signed(instr_i(31 downto 20)), 32));
          case funct3 is
            when "000" => control.mem_size := MEM_BYTE; -- LB
            when "001" => control.mem_size := MEM_HALF; -- LH
            when "010" => control.mem_size := MEM_WORD; -- LW
            when "100" =>                              -- LBU
              control.mem_size := MEM_BYTE;
              control.load_unsigned := '1';
            when "101" =>                              -- LHU
              control.mem_size := MEM_HALF;
              control.load_unsigned := '1';
            when others => valid := false; -- No LD/LWU in RV32I.
          end case;
          -- Width/sign control applies to the returned data, not the address
          -- immediate: even LBU/LHU use a SIGNED offset from rs1.

        when "0100011" =>                        -- Stores, S format
          valid := true;
          control.kind := INSTR_STORE;
          control.rhs_sel := RHS_IMM;
          -- S immediates split their low five bits into the nominal rd field.
          -- Store data still comes from rs2; the ALU computes rs1+offset.
          immediate := std_logic_vector(resize(signed(
            instr_i(31 downto 25) & instr_i(11 downto 7)), 32));
          case funct3 is
            when "000" => control.mem_size := MEM_BYTE; -- SB
            when "001" => control.mem_size := MEM_HALF; -- SH
            when "010" => control.mem_size := MEM_WORD; -- SW
            when others => valid := false;
          end case;

        when "0010011" =>                        -- Immediate ALU, I format
          valid := true;
          control.kind := INSTR_ALU;
          control.rhs_sel := RHS_IMM;
          control.rd_write := '1';
          immediate := std_logic_vector(resize(signed(instr_i(31 downto 20)), 32));
          case funct3 is
            when "000" => control.alu_op := ALU_ADD;  -- ADDI, including NOP
            when "010" => control.alu_op := ALU_SLT;  -- SLTI
            when "011" => control.alu_op := ALU_SLTU; -- SLTIU
            when "100" => control.alu_op := ALU_XOR;  -- XORI
            when "110" => control.alu_op := ALU_OR;   -- ORI
            when "111" => control.alu_op := ALU_AND;  -- ANDI
            when "001" =>                           -- SLLI
              valid := funct7 = "0000000";
              control.alu_op := ALU_SLL;
              immediate := (others => '0');
              immediate(4 downto 0) := instr_i(24 downto 20);
            when "101" =>                           -- SRLI / SRAI
              valid := funct7 = "0000000" or funct7 = "0100000";
              if instr_i(30) = '1' then
                control.alu_op := ALU_SRA;
              else
                control.alu_op := ALU_SRL;
              end if;
              immediate := (others => '0');
              immediate(4 downto 0) := instr_i(24 downto 20);
            when others => valid := false;
          end case;
          -- All seven upper shift bits must match: bit 25 is not an extra
          -- shamt bit in RV32. Strip the funct7 encoding from imm_o for shifts.
          -- SLTIU still sign-extends its immediate before UNSIGNED comparison.

        when "0110011" =>                        -- Register ALU, R format
          -- Only ADD/SUB and SRL/SRA admit funct7=0100000. Checking bit 30
          -- alone would silently accept M-extension or other reserved words.
          valid := funct7 = "0000000" or
            (funct7 = "0100000" and (funct3 = "000" or funct3 = "101"));
          control.kind := INSTR_ALU;
          control.rd_write := '1';
          case funct3 is
            when "000" =>
              if instr_i(30) = '1' then control.alu_op := ALU_SUB;
              else control.alu_op := ALU_ADD; end if;
            when "001" => control.alu_op := ALU_SLL;
            when "010" => control.alu_op := ALU_SLT;
            when "011" => control.alu_op := ALU_SLTU;
            when "100" => control.alu_op := ALU_XOR;
            when "101" =>
              if instr_i(30) = '1' then control.alu_op := ALU_SRA;
              else control.alu_op := ALU_SRL; end if;
            when "110" => control.alu_op := ALU_OR;
            when "111" => control.alu_op := ALU_AND;
            when others => valid := false;
          end case;

        when "0001111" =>                        -- MISC-MEM
          valid := funct3 = "000";
          control.kind := INSTR_FENCE;
          -- Our ordered, non-pipelined memory system has no outstanding
          -- accesses when FENCE executes. Ignore fm/pred/succ/rs1/rd and retire
          -- as a no-op. FENCE.I (funct3=001) requires absent Zifencei support.

        when "1110011" =>                        -- SYSTEM
          -- Exact comparisons reject nonzero reserved register fields, CSRs,
          -- returns from traps, WFI, and other privileged/extension operations.
          -- ECALL/EBREAK are legal encodings; the core raises their specified
          -- trap causes in EXECUTE instead of treating them as illegal words.
          if instr_i = x"00000073" then
            valid := true;
            control.kind := INSTR_ECALL;
          elsif instr_i = x"00100073" then
            valid := true;
            control.kind := INSTR_EBREAK;
          end if;

        when others =>
          -- Also rejects compressed encodings (low two bits /= 11), RV64 word
          -- operations, atomics, floating point, custom, and long encodings.
          null;
      end case;
    -- synthesis translate_off
    end if;
    -- synthesis translate_on

    -- Publish a complete result only after validation. A failed funct check
    -- must not leak controls populated earlier in the corresponding case.
    if valid then
      legal_o <= '1';
      imm_o <= immediate;
      ctrl_o <= control;
    else
      legal_o <= '0';
      imm_o <= (others => '0');
      ctrl_o <= DECODE_CONTROL_ILLEGAL;
    end if;
  end process;
end architecture;
