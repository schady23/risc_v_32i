library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;

entity rv32i_core is
  port (
    clk_i   : in std_logic;
    reset_i : in std_logic;

    i_req_o   : out std_logic;
    i_addr_o  : out word_t;
    i_rdata_i : in  word_t;
    i_fault_i : in  std_logic;

    d_req_o   : out std_logic;
    d_write_o : out std_logic;
    d_addr_o  : out word_t;
    d_wdata_o : out word_t;
    d_be_o    : out byte_enable_t;
    d_rdata_i : in  word_t;
    d_fault_i : in  std_logic;

    halted_o     : out std_logic;
    trap_valid_o : out std_logic;
    trap_cause_o : out trap_cause_t;
    trap_pc_o    : out word_t;
    trap_tval_o  : out word_t;

    retire_valid_o   : out std_logic;
    retire_pc_o      : out word_t;
    retire_instr_o   : out word_t;
    retire_rd_we_o   : out std_logic;
    retire_rd_o      : out reg_index_t;
    retire_rd_data_o : out word_t
  );
end entity;

architecture rtl of rv32i_core is
  signal state : core_state_t := RESET_STATE;
  signal pc, instr, next_pc, result, mem_addr : word_t := (others => '0');
  signal rs1_value, rs2_value : word_t := (others => '0');
  signal store_data : word_t := (others => '0');
  signal mem_be : byte_enable_t := (others => '0');
  signal trap_valid : std_logic := '0';
  signal trap_cause : trap_cause_t := (others => '0');
  signal trap_pc, trap_tval : word_t := (others => '0');

  signal legal : std_logic := '0';
  signal rs1, rs2, rd : reg_index_t := (others => '0');
  signal immediate : word_t := (others => '0');
  signal control : decode_control_t := DECODE_CONTROL_ILLEGAL;
  signal reg_rs1, reg_rs2 : word_t := (others => '0');
  signal alu_lhs, alu_rhs, alu_result : word_t := (others => '0');
  signal reg_write : std_logic;

  function lane_mask(size : mem_size_t; offset : natural) return byte_enable_t is
    variable mask : byte_enable_t := (others => '0');
  begin
    case size is
      when MEM_BYTE => mask(offset) := '1';
      when MEM_HALF => mask(offset) := '1'; mask(offset + 1) := '1';
      when MEM_WORD => mask := (others => '1');
    end case;
    return mask;
  end function;
begin
  decoder : entity work.rv32i_decoder
    port map (instr_i => instr, legal_o => legal, rs1_o => rs1,
              rs2_o => rs2, rd_o => rd, imm_o => immediate, ctrl_o => control);

  registers : entity work.rv32i_regfile
    port map (clk_i => clk_i, reset_i => reset_i, rs1_addr_i => rs1,
              rs2_addr_i => rs2, rs1_data_o => reg_rs1, rs2_data_o => reg_rs2,
              rd_we_i => reg_write, rd_addr_i => rd, rd_data_i => result);

  with control.lhs_sel select alu_lhs <=
    rs1_value when LHS_RS1, pc when LHS_PC, (others => '0') when LHS_ZERO;
  with control.rhs_sel select alu_rhs <=
    rs2_value when RHS_RS2, immediate when RHS_IMM;

  alu : entity work.rv32i_alu
    port map (lhs_i => alu_lhs, rhs_i => alu_rhs,
              op_i => control.alu_op, result_o => alu_result);

  i_req_o <= '1' when state = FETCH_REQ and reset_i = '0' else '0';
  i_addr_o <= pc;
  d_req_o <= '1' when (state = MEM_READ_REQ or state = MEM_WRITE_REQ) and
                       reset_i = '0' else '0';
  d_write_o <= '1' when state = MEM_WRITE_REQ and reset_i = '0' else '0';
  d_addr_o <= mem_addr;
  d_wdata_o <= store_data;
  d_be_o <= mem_be;

  halted_o <= '1' when state = HALT else '0';
  trap_valid_o <= trap_valid;
  trap_cause_o <= trap_cause;
  trap_pc_o <= trap_pc;
  trap_tval_o <= trap_tval;

  retire_valid_o <= '1' when state = WRITEBACK and reset_i = '0' else '0';
  retire_pc_o <= pc;
  retire_instr_o <= instr;
  reg_write <= '1' when state = WRITEBACK and control.rd_write = '1' and
                        rd /= "00000" and reset_i = '0' else '0';
  retire_rd_we_o <= reg_write;
  retire_rd_o <= rd;
  retire_rd_data_o <= result;

  process (clk_i)
    variable address : word_t;
    variable target : word_t;
    variable taken : boolean;
    variable offset : natural range 0 to 3;
    variable loaded : word_t;
  begin
    if rising_edge(clk_i) then
      if reset_i = '1' then
        state <= FETCH_REQ;
        pc <= (others => '0');
        instr <= (others => '0');
        next_pc <= (others => '0');
        result <= (others => '0');
        mem_addr <= (others => '0');
        mem_be <= (others => '0');
        store_data <= (others => '0');
        rs1_value <= (others => '0');
        rs2_value <= (others => '0');
        trap_valid <= '0';
        trap_cause <= (others => '0');
        trap_pc <= (others => '0');
        trap_tval <= (others => '0');
      else
        case state is
          when RESET_STATE => state <= FETCH_REQ;
          when FETCH_REQ => state <= FETCH_WAIT;
          when FETCH_WAIT =>
            if i_fault_i = '1' then
              trap_valid <= '1';
              trap_cause <= TRAP_INSTR_ACCESS_FAULT;
              trap_pc <= pc;
              trap_tval <= pc;
              state <= HALT;
            else
              instr <= i_rdata_i;
              state <= DECODE;
            end if;
          when DECODE =>
            rs1_value <= reg_rs1;
            rs2_value <= reg_rs2;
            state <= EXECUTE;
          when EXECUTE =>
            next_pc <= std_logic_vector(unsigned(pc) + 4);
            case control.kind is
              when INSTR_ILLEGAL =>
                trap_valid <= '1';
                trap_cause <= TRAP_ILLEGAL_INSTRUCTION;
                trap_pc <= pc;
                trap_tval <= instr;
                state <= HALT;
              when INSTR_ECALL | INSTR_EBREAK =>
                trap_valid <= '1';
                trap_pc <= pc;
                trap_tval <= (others => '0');
                if control.kind = INSTR_ECALL then
                  trap_cause <= TRAP_ENVIRONMENT_CALL;
                else
                  trap_cause <= TRAP_BREAKPOINT;
                end if;
                state <= HALT;
              when INSTR_ALU | INSTR_LUI | INSTR_AUIPC =>
                result <= alu_result;
                state <= WRITEBACK;
              when INSTR_JAL | INSTR_JALR | INSTR_BRANCH =>
                target := alu_result;
                taken := true;
                if control.kind = INSTR_JALR then
                  target(0) := '0';
                elsif control.kind = INSTR_BRANCH then
                  case control.branch is
                    when BR_EQ  => taken := rs1_value = rs2_value;
                    when BR_NE  => taken := rs1_value /= rs2_value;
                    when BR_LT  => taken := signed(rs1_value) < signed(rs2_value);
                    when BR_GE  => taken := signed(rs1_value) >= signed(rs2_value);
                    when BR_LTU => taken := unsigned(rs1_value) < unsigned(rs2_value);
                    when BR_GEU => taken := unsigned(rs1_value) >= unsigned(rs2_value);
                    when BR_NONE => taken := false;
                  end case;
                end if;
                if taken and target(1 downto 0) /= "00" then
                  trap_valid <= '1';
                  trap_cause <= TRAP_INSTR_ADDR_MISALIGNED;
                  trap_pc <= pc;
                  trap_tval <= target;
                  state <= HALT;
                else
                  if taken then next_pc <= target; end if;
                  result <= std_logic_vector(unsigned(pc) + 4);
                  state <= WRITEBACK;
                end if;
              when INSTR_LOAD | INSTR_STORE =>
                address := alu_result;
                offset := to_integer(unsigned(address(1 downto 0)));
                if (control.mem_size = MEM_WORD and offset /= 0) or
                   (control.mem_size = MEM_HALF and address(0) = '1') then
                  trap_valid <= '1';
                  trap_pc <= pc;
                  trap_tval <= address;
                  if control.kind = INSTR_LOAD then
                    trap_cause <= TRAP_LOAD_ADDR_MISALIGNED;
                  else
                    trap_cause <= TRAP_STORE_ADDR_MISALIGNED;
                  end if;
                  state <= HALT;
                else
                  mem_addr <= address;
                  mem_be <= lane_mask(control.mem_size, offset);
                  store_data <= std_logic_vector(shift_left(unsigned(rs2_value), offset * 8));
                  if control.kind = INSTR_LOAD then
                    state <= MEM_READ_REQ;
                  else
                    state <= MEM_WRITE_REQ;
                  end if;
                end if;
              when INSTR_FENCE => state <= WRITEBACK;
            end case;
          when MEM_READ_REQ => state <= MEM_READ_WAIT;
          when MEM_READ_WAIT =>
            if d_fault_i = '1' then
              trap_valid <= '1';
              trap_cause <= TRAP_LOAD_ACCESS_FAULT;
              trap_pc <= pc;
              trap_tval <= mem_addr;
              state <= HALT;
            else
              offset := to_integer(unsigned(mem_addr(1 downto 0)));
              loaded := std_logic_vector(shift_right(unsigned(d_rdata_i), offset * 8));
              case control.mem_size is
                when MEM_BYTE =>
                  if control.load_unsigned = '1' then
                    result <= x"000000" & loaded(7 downto 0);
                  else
                    result <= std_logic_vector(resize(signed(loaded(7 downto 0)), 32));
                  end if;
                when MEM_HALF =>
                  if control.load_unsigned = '1' then
                    result <= x"0000" & loaded(15 downto 0);
                  else
                    result <= std_logic_vector(resize(signed(loaded(15 downto 0)), 32));
                  end if;
                when MEM_WORD => result <= loaded;
              end case;
              state <= WRITEBACK;
            end if;
          when MEM_WRITE_REQ => state <= MEM_WRITE_WAIT;
          when MEM_WRITE_WAIT =>
            if d_fault_i = '1' then
              trap_valid <= '1';
              trap_cause <= TRAP_STORE_ACCESS_FAULT;
              trap_pc <= pc;
              trap_tval <= mem_addr;
              state <= HALT;
            else
              state <= WRITEBACK;
            end if;
          when WRITEBACK =>
            pc <= next_pc;
            state <= FETCH_REQ;
          when HALT => null;
        end case;
      end if;
    end if;
  end process;
end architecture;
