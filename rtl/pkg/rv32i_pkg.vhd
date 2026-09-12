library ieee;
use ieee.std_logic_1164.all;

package rv32i_pkg is
  subtype word_t is std_logic_vector(31 downto 0);
  subtype reg_index_t is std_logic_vector(4 downto 0);
  subtype byte_enable_t is std_logic_vector(3 downto 0);
  subtype trap_cause_t is std_logic_vector(3 downto 0);

  constant TRAP_INSTR_ADDR_MISALIGNED : trap_cause_t := x"0";
  constant TRAP_INSTR_ACCESS_FAULT    : trap_cause_t := x"1";
  constant TRAP_ILLEGAL_INSTRUCTION   : trap_cause_t := x"2";
  constant TRAP_BREAKPOINT            : trap_cause_t := x"3";
  constant TRAP_LOAD_ADDR_MISALIGNED  : trap_cause_t := x"4";
  constant TRAP_LOAD_ACCESS_FAULT     : trap_cause_t := x"5";
  constant TRAP_STORE_ADDR_MISALIGNED : trap_cause_t := x"6";
  constant TRAP_STORE_ACCESS_FAULT    : trap_cause_t := x"7";
  constant TRAP_ENVIRONMENT_CALL      : trap_cause_t := x"B";

  type alu_op_t is (
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND
  );

  -- The decoder describes *what* an instruction does; the core FSM decides
  -- *when* to request memory, trap, and retire. Keep the control fields typed
  -- so an instruction cannot accidentally select an unrelated numeric code.
  type instr_kind_t is (
    INSTR_ILLEGAL, INSTR_ALU, INSTR_LUI, INSTR_AUIPC,
    INSTR_JAL, INSTR_JALR, INSTR_BRANCH, INSTR_LOAD, INSTR_STORE,
    INSTR_FENCE, INSTR_ECALL, INSTR_EBREAK
  );
  type alu_lhs_sel_t is (LHS_RS1, LHS_PC, LHS_ZERO);
  type alu_rhs_sel_t is (RHS_RS2, RHS_IMM);
  type writeback_sel_t is (WB_ALU, WB_MEMORY, WB_PC_PLUS_4);
  type branch_op_t is (BR_NONE, BR_EQ, BR_NE, BR_LT, BR_GE, BR_LTU, BR_GEU);
  type mem_size_t is (MEM_BYTE, MEM_HALF, MEM_WORD);

  type decode_control_t is record
    kind          : instr_kind_t;
    alu_op        : alu_op_t;
    lhs_sel       : alu_lhs_sel_t;
    rhs_sel       : alu_rhs_sel_t;
    -- This is instruction intent, not a register-file write enable. The core
    -- gates it with successful WRITEBACK and rd /= x0. Loads to x0 still run.
    rd_write      : std_logic;
    wb_sel        : writeback_sel_t;
    -- Branch compares rs1/rs2 separately while the ALU computes PC + offset.
    branch        : branch_op_t;
    -- Size refers to bytes accessed, not to the always-32-bit bus data word.
    -- The core constructs lane masks and extends load data after its response.
    mem_size      : mem_size_t;
    load_unsigned : std_logic;
  end record;

  -- Assign every output on every combinational evaluation. This default both
  -- avoids inferred latches and prevents a rejected instruction from retaining
  -- a preceding instruction's store, branch, or destination-write controls.
  constant DECODE_CONTROL_ILLEGAL : decode_control_t := (
    kind          => INSTR_ILLEGAL,
    alu_op        => ALU_ADD,
    lhs_sel       => LHS_RS1,
    rhs_sel       => RHS_RS2,
    rd_write      => '0',
    wb_sel        => WB_ALU,
    branch        => BR_NONE,
    mem_size      => MEM_WORD,
    load_unsigned => '0'
  );

  type core_state_t is (
    RESET_STATE,
    FETCH_REQ,
    FETCH_WAIT,
    DECODE,
    EXECUTE,
    MEM_READ_REQ,
    MEM_READ_WAIT,
    MEM_WRITE_REQ,
    MEM_WRITE_WAIT,
    WRITEBACK,
    HALT
  );
end package;
