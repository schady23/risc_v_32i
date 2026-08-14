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
