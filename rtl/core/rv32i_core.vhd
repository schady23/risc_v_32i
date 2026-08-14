library ieee;
use ieee.std_logic_1164.all;

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

architecture scaffold of rv32i_core is
begin
  -- Safe inactive shell. The multi-cycle FSM will replace this architecture.
  i_req_o   <= '0';
  i_addr_o  <= (others => '0');
  d_req_o   <= '0';
  d_write_o <= '0';
  d_addr_o  <= (others => '0');
  d_wdata_o <= (others => '0');
  d_be_o    <= (others => '0');

  halted_o     <= '1';
  trap_valid_o <= '0';
  trap_cause_o <= (others => '0');
  trap_pc_o    <= (others => '0');
  trap_tval_o  <= (others => '0');

  retire_valid_o   <= '0';
  retire_pc_o      <= (others => '0');
  retire_instr_o   <= (others => '0');
  retire_rd_we_o   <= '0';
  retire_rd_o      <= (others => '0');
  retire_rd_data_o <= (others => '0');
end architecture;
