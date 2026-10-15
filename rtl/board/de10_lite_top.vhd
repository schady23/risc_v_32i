library ieee;
use ieee.std_logic_1164.all;
use work.rv32i_pkg.all;

-- JTAG pins are dedicated device pins managed by Intel IP, not user GPIO.
entity de10_lite_top is
  port (MAX10_CLK1_50 : in std_logic; KEY : in std_logic_vector(1 downto 0));
end entity;
architecture rtl of de10_lite_top is
  component jtag_uart_system is
    port (
      clk_clk, reset_reset_n : in std_logic;
      av_address, av_chipselect, av_read_n, av_write_n : in std_logic;
      av_writedata : in std_logic_vector(31 downto 0);
      av_readdata : out std_logic_vector(31 downto 0);
      av_waitrequest : out std_logic
    );
  end component;
  signal reset, address, rd, wr, waitrequest : std_logic;
  signal readdata, writedata : word_t;
begin
  reset_sync : entity work.reset_synchronizer port map (
    clk_i => MAX10_CLK1_50, async_reset_i => not KEY(0), reset_o => reset);
  system_core : entity work.rv32i_system port map (
    clk_i => MAX10_CLK1_50, reset_i => reset,
    av_address_o => address, av_read_o => rd, av_write_o => wr,
    av_writedata_o => writedata, av_readdata_i => readdata,
    av_waitrequest_i => waitrequest);
  jtag : jtag_uart_system port map (
    clk_clk => MAX10_CLK1_50, reset_reset_n => not reset,
    av_address => address, av_chipselect => rd or wr,
    av_read_n => not rd, av_write_n => not wr,
    av_writedata => writedata, av_readdata => readdata,
    av_waitrequest => waitrequest);
end architecture;
