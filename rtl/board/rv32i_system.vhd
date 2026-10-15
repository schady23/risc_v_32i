library ieee;
use ieee.std_logic_1164.all;
use work.rv32i_pkg.all;

-- Vendor-independent system boundary. JTAG UART IP is attached by the board
-- wrapper; simulation attaches an Avalon/FIFO model to these same signals.
entity rv32i_system is
  port (
    clk_i, reset_i : in std_logic;
    av_address_o, av_read_o, av_write_o : out std_logic;
    av_writedata_o : out word_t;
    av_readdata_i : in word_t;
    av_waitrequest_i : in std_logic
  );
end entity;
architecture rtl of rv32i_system is
  signal i_req, i_fault, d_req, d_write, d_fault : std_logic;
  signal i_addr, i_rdata, d_addr, d_wdata, d_rdata : word_t;
  signal d_be : byte_enable_t;
begin
  cpu : entity work.rv32i_core port map (
    clk_i => clk_i, reset_i => reset_i,
    i_req_o => i_req, i_addr_o => i_addr, i_rdata_i => i_rdata, i_fault_i => i_fault,
    d_req_o => d_req, d_write_o => d_write, d_addr_o => d_addr,
    d_wdata_o => d_wdata, d_be_o => d_be, d_rdata_i => d_rdata, d_fault_i => d_fault,
    halted_o => open, trap_valid_o => open, trap_cause_o => open,
    trap_pc_o => open, trap_tval_o => open,
    retire_valid_o => open, retire_pc_o => open, retire_instr_o => open,
    retire_rd_we_o => open, retire_rd_o => open, retire_rd_data_o => open);
  bus_system : entity work.memory_bus port map (
    clk_i => clk_i, reset_i => reset_i,
    i_req_i => i_req, i_addr_i => i_addr, i_rdata_o => i_rdata, i_fault_o => i_fault,
    d_req_i => d_req, d_write_i => d_write, d_addr_i => d_addr,
    d_wdata_i => d_wdata, d_be_i => d_be, d_rdata_o => d_rdata, d_fault_o => d_fault,
    av_address_o => av_address_o, av_read_o => av_read_o, av_write_o => av_write_o,
    av_writedata_o => av_writedata_o, av_readdata_i => av_readdata_i,
    av_waitrequest_i => av_waitrequest_i);
end architecture;
