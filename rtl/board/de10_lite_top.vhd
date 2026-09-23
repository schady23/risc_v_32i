library ieee;
use ieee.std_logic_1164.all;
use work.rv32i_pkg.all;

-- CPU system on the DE10-Lite. GPIO synchronizes the switch inputs.
entity de10_lite_top is
  port (
    MAX10_CLK1_50 : in  std_logic;
    KEY          : in  std_logic_vector(1 downto 0);
    SW           : in  std_logic_vector(9 downto 0);
    LEDR         : out std_logic_vector(9 downto 0)
  );
end entity;

architecture rtl of de10_lite_top is
  signal reset : std_logic;
  signal i_req, i_fault : std_logic;
  signal i_addr, i_rdata : word_t;
  signal d_req, d_write, d_fault : std_logic;
  signal d_addr, d_wdata, d_rdata : word_t;
  signal d_be : byte_enable_t;
  signal leds : std_logic_vector(15 downto 0);
  signal switches : std_logic_vector(15 downto 0);
begin
  reset_sync : entity work.reset_synchronizer
    port map (
      clk_i         => MAX10_CLK1_50,
      async_reset_i => not KEY(0),
      reset_o       => reset
    );

  cpu : entity work.rv32i_core
    port map (
      clk_i => MAX10_CLK1_50, reset_i => reset,
      i_req_o => i_req, i_addr_o => i_addr, i_rdata_i => i_rdata, i_fault_i => i_fault,
      d_req_o => d_req, d_write_o => d_write, d_addr_o => d_addr,
      d_wdata_o => d_wdata, d_be_o => d_be, d_rdata_i => d_rdata, d_fault_i => d_fault,
      halted_o => open, trap_valid_o => open, trap_cause_o => open,
      trap_pc_o => open, trap_tval_o => open,
      retire_valid_o => open, retire_pc_o => open, retire_instr_o => open,
      retire_rd_we_o => open, retire_rd_o => open, retire_rd_data_o => open
    );

  switches <= "000000" & SW;
  bus_system : entity work.memory_bus
    port map (
      clk_i => MAX10_CLK1_50, reset_i => reset,
      i_req_i => i_req, i_addr_i => i_addr, i_rdata_o => i_rdata, i_fault_o => i_fault,
      d_req_i => d_req, d_write_i => d_write, d_addr_i => d_addr,
      d_wdata_i => d_wdata, d_be_i => d_be, d_rdata_o => d_rdata, d_fault_o => d_fault,
      switches_i => switches, status_i => (others => '0'), leds_o => leds
    );

  LEDR <= leds(9 downto 0);
end architecture;
